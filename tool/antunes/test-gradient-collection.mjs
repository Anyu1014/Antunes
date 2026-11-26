import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import vm from 'node:vm';
const root=process.argv[2]||resolve(import.meta.dirname,'../..');
const r=f=>readFileSync(resolve(root,f),'utf8');
const app=r('android/app/src/main/assets/app.js');
assert(app.includes("selectRow('横屏歌单封面风格','collectionCoverStyleLandscape'"),'portrait and landscape need different setting keys');
assert.match(app,/selectRow\('竖屏歌单封面风格','collectionCoverStyle'/);
assert.match(app,/collectionCoverStyle:'classic'/);
assert(app.includes("['gradient','渐变封面柔和'],['gradientDimmed','渐变封面压暗']"),'settings must offer both gradient modes');
const settings=r('Sources/Kumone/Features/Pages/SettingsView.swift');
assert.match(settings,/Text\("渐变封面柔和"\).tag\("gradient"\)/);
assert.match(settings,/Text\("渐变封面压暗"\).tag\("gradientDimmed"\)/);
assert(app.includes("['gradientFlow','渐变封面流光']"),'settings must offer the edge-color flow gradient');
assert.match(settings,/Text\("渐变封面流光"\).tag\("gradientFlow"\)/);
const preference=vm.createContext({read:()=>({collectionCoverStyle:'gradientDimmed'}),write(){}});
vm.runInContext(app.slice(app.indexOf('function readPreferences('),app.indexOf('// 音质档位')),preference);
assert.equal(preference.readPreferences().collectionCoverStyleLandscape,'gradientDimmed');
preference.read=()=>({collectionCoverStyle:'classic',collectionCoverStyleLandscape:'gradientFlow'});
assert.equal(preference.readPreferences().collectionCoverStyleLandscape,'gradientFlow');
preference.read=()=>({collectionCoverStyle:'gradientFlow'});
assert.equal(preference.readPreferences().collectionCoverStyle,'gradient','removed portrait flow must fall back to soft');
assert.equal(preference.readPreferences().collectionCoverStyleLandscape,'gradientFlow','legacy shared flow must survive in landscape');
preference.read=()=>({collectionCoverStyle:'gradientFlow',collectionCoverStyleLandscape:'gradientDimmed'});
assert.equal(preference.readPreferences().collectionCoverStyle,'gradient');
assert.equal(preference.readPreferences().collectionCoverStyleLandscape,'gradientDimmed','an explicit landscape choice must be preserved');
assert.match(settings,/Picker\("竖屏歌单封面风格", selection: coverPreference.portraitSelection\)/);
assert.match(settings,/Picker\("横屏歌单封面风格", selection: coverPreference.landscapeSelection\)/);
const slice=(a,b)=>app.slice(app.indexOf(a),app.indexOf(b,app.indexOf(a)));
const selectedRows=[];
vm.runInNewContext(slice('function collectionCoverSettingsRows(', 'function settingsHTML(')
  +'collectionCoverSettingsRows()', {selectRow:(_label,key,choices)=>{selectedRows.push([key,choices.map(c=>c[0]).join(',')]); return '';}});
assert.deepEqual(selectedRows,[
  ['collectionCoverStyle','classic,gradient,gradientDimmed'],
  ['collectionCoverStyleLandscape','classic,gradient,gradientDimmed,gradientFlow']
]);
assert.match(settings,/Picker\("竖屏歌单封面风格", selection: coverPreference\.portraitSelection\) \{\s*collectionCoverOptions\s*\}/);
assert.match(settings,/Picker\("横屏歌单封面风格", selection: coverPreference\.landscapeSelection\) \{\s*collectionCoverOptions\s*Text\("渐变封面流光"\)/);
let landscape=false;
const ctx={
  matchMedia:()=>({matches:landscape}),
  route:{kind:'album',id:5},albumFavorites:new Map(),loggedIn:false,
  cached:async()=>({album:info,songs:tracks}),uniqueTracks:x=>x,header:()=>'',setTimeout(){},preloadCovers(){},
  detail:null,listTracks:[],
  account:null,ambientArtworkURL:()=>'',imageURL:()=>'',coverSize:()=>960,e:String,icon:()=>'<svg></svg>',cover:(_,$)=>`<img class="${$}">`,count:String,round:(icon,fn,aria,cls='')=>`<button class="round ${cls}" aria-label="${aria}"><svg></svg></button>`,empty:()=>'',liked:new Set(),downloaded:new Set(['1']),player:{queue:[],index:0},play(){},selecting:false,picked:new Set(),prefs:{collectionCoverStyle:'classic'},time:()=>'5:13',
  back(){},button:(label,action,cls,aria)=>`<button class="${cls}" aria-label="${aria}">${label}</button>`
};
vm.runInNewContext(slice('function trackRow(', 'function selectBar(')+slice('function playlistLocateButton(', 'function filterPlaylist(')+slice('function detailCols(', 'function listRow('),ctx);
const tracks=[{id:1,name:'第一首',artist:'作者 A',fee:1,duration:313000},{id:2,name:'第二首',artist:'作者 B'}];
const info={id:5,name:'测试集合',creator:{nickname:'作者'},artist:{name:'专辑作者'},description:'测试简介',playCount:60};
const classic=ctx.playlistDetails(info,tracks);
const classicAlbum=await ctx.detailPage();
ctx.prefs.collectionCoverStyle='gradient';
const playlist=ctx.playlistDetails(info,tracks),album=await ctx.detailPage();
ctx.prefs.collectionCoverStyleLandscape='classic';
landscape=true;
assert.equal(ctx.playlistDetails(info,tracks),classic);
assert.equal(await ctx.detailPage(),classicAlbum);
ctx.prefs.collectionCoverStyleLandscape='gradientFlow';
assert.equal(ctx.currentCollectionCoverStyle(),'gradientFlow');
assert.equal(ctx.playlistDetails(info,tracks),playlist);
landscape=false;
assert.equal(ctx.currentCollectionCoverStyle(),'gradient');
assert.equal(await ctx.detailPage(),album);
ctx.prefs.collectionCoverStyle='gradientDimmed';
assert.equal(ctx.playlistDetails(info,tracks),playlist);
assert.equal(await ctx.detailPage(),album);
for(const h of [playlist,album]){
  assert.match(h,/class="collection-gradient"/);
  assert.match(h,/class="collection-top"[\s\S]*?aria-label="(?:歌单|专辑)内搜索"/);
  assert(/class="collection-top-actions">[\s\S]*?aria-label="播放全部"[\s\S]*?aria-label="收藏"[\s\S]*?aria-label="(?:歌单|专辑)内搜索"/.test(h),
    'top-right action order must be play, favorite, search');
  assert.match(h,/aria-label="播放全部"><svg><\/svg><\/button>/);
  assert(!h.includes('分享')&&!h.includes('排序和更多')&&!h.includes('评论'));
}
for(const [html,wantGlass] of [[playlist,true],[album,false]]){
  const toolbar=html.slice(html.indexOf('class="collection-top"'),html.indexOf('class="collection-hero"'));
  const classes=[...toolbar.matchAll(/<button class="([^"]*)"/g)].map(m=>m[1].split(/\s+/));
  assert.equal(classes.length,4);
  assert(classes.every(tokens=>tokens.includes('glass')===wantGlass),'only the four playlist toolbar buttons must use glass');
}
assert(classic.includes(ctx.playlistRowsHTML(tracks)));
assert(playlist.includes(ctx.playlistRowsHTML(tracks)),'playlist rows must be the same HTML as classic');
assert(album.includes(ctx.tracksHTML(tracks,true)),'album rows must be the same HTML as classic');
assert.match(playlist,/playlist-track-cover[\s\S]*playlist-duration[\s\S]*5:13/);
assert.equal((playlist.match(/aria-label="选择歌曲"/g)||[]).length,1);
assert.equal((playlist.match(/aria-label="下载全部"/g)||[]).length,1);
assert.match(classic,/playlist-cols/);
assert.match(classicAlbum,/detail-cols/);
for(const h of [playlist,album]){
  assert.match(h,/class="collection-hero"\s*>\s*<div class="collection-art"/);
  assert.match(h,/class="collection-meta-viewport"\s*>[\s\S]*class="collection-pills"/);
  assert.match(h,/class="collection-list"\s*>[\s\S]*id="playlist-search"/);
}
for(const html of [classic,playlist,album]){
  assert(html.includes('class="collection-description-preview"'),'cover descriptions must clamp the text, not the button');
}
const css=r('android/app/src/main/assets/app.css');
const portraitCSS=css.match(/@media \(orientation:portrait\)\{\s*#page\[data-route=playlist\] \.collection-hero[\s\S]*?\n\}/)?.[0];
assert(portraitCSS,'portrait playlist must use a separate square cover layout');
assert.match(portraitCSS,/\.collection-art\{[^}]*aspect-ratio:1;grid-area:cover/);
assert.match(portraitCSS,/\.collection-copy\{\s*grid-area:cover;align-self:end/);
assert.match(portraitCSS,/\.collection-copy::before\{[^}]*inset:-10px 0 0;[^}]*transparent 0%,[^}]*72%,transparent\) 52%,var\(--collection-base\) 100%/,'portrait playlist gradient should start 10px above the title and end at the cover bottom');
assert.match(portraitCSS,/\.collection-pills\{grid-area:pills/);
assert.match(css,/\.collection-description-preview\{[^}]*-webkit-line-clamp:2/);
assert.match(css,/grid-template-columns:var\(--player-edge,46vw\) minmax\(0,1fr\)/);
assert.match(css,/\.collection-art,\.collection-art>\.placeholder\{inset:0;width:100%;height:100%\}/);
assert.match(css,/mask-image:linear-gradient\(to right,var\(--cover-fade\)\),linear-gradient\(to bottom,var\(--cover-fade\)\);\s*mask-composite:intersect/);
assert.match(css,/\.collection-meta-viewport\{[\s\S]*?var\(--player-top,/);
assert.match(css,/linear-gradient\(to bottom,[^\n]*var\(--collection-base\)/);
assert.match(css,/\.top-bar\{position:sticky;top:0/);
assert.match(css,/\.collection-top\{position:sticky;top:0/);
assert.match(app,/ambientPaletteFor\(url,aspect,style\)/);
assert.match(css,/\.collection-top-pills\{display:none\}/);
assert.match(css,/\.collection-top-pills\{display:flex;gap:6px\}/);
assert.match(css,/\.collection-meta \.collection-pills\{display:none\}/);
assert.match(css,/data-collection-tone=light\]\{--collection-ink:#000;color-scheme:light\}/);
assert.match(app,/page.dataset.collectionTone=isLight\?'light':'dark'/);
const palette=vm.createContext({});
vm.runInContext(slice('const COLLECTION_FALLBACK=', 'function paintAmbient('),palette);
assert.equal(typeof palette.collectionHeroAccent,'function','large play button keeps its independent cover tint');
const relativeLuminance=rgb=>rgb.map(v=>v/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4)
  .reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0);
for(const rgb of [[215,80,148],[51,158,233],[62,174,84]]){
  const sample=[255,255,255,255,...rgb,255,230,0,0,0];
  for(const base of [[17,20,34],[117,117,117],[123,123,123],[197,172,210],[246,241,225]]){
    const accent=Array.from(palette.collectionHeroAccent(sample,base.map(v=>v/255)));
    const sorted=[relativeLuminance(base),relativeLuminance(accent)].sort((a,b)=>a-b);
    assert.ok((sorted[1]+.05)/(sorted[0]+.05)>=3.6,{base,accent});
    assert.ok(Math.max(...accent)-Math.min(...accent)>=22,'colorful covers must not collapse to black/white');
    assert.equal(accent.indexOf(Math.max(...accent)),rgb.indexOf(Math.max(...rgb)));
  }
}
assert.equal(palette.collectionHeroAccent([140,140,140,255,255,0,0,0],[.8,.8,.8]),null);
assert.match(css,/#page\[data-route=playlist\] \.collection-meta h1\{color:var\(--collection-ink,#fff\)\}/,
  'playlist title should use only black/white, not the play tint');
assert.match(css,/#page\[data-route=playlist\] \.collection-pills \.collection-play:not\(\.glass\)\{background:var\(--collection-hero-accent,var\(--collection-accent,#f5e1fb\)\)\}/);
for(const [sample,tone] of [[[240,230,218],true],[[25,35,46],false]]){
  const colors=palette.collectionEdgeColors([...sample,255]);
  assert.deepEqual(Array.from(colors.primary),sample);
  assert.equal(colors.isLight,tone);
}
const dimmed=palette.collectionEdgeColors([240,230,218,255],true);
assert.deepEqual(Array.from(dimmed.primary),[102,98,93]);
assert.deepEqual(Array.from(dimmed.secondary),[250,247,243]);
assert.equal(dimmed.isLight,false);
assert.equal(vm.runInContext("new Set(['gradient','gradientDimmed','gradientFlow'].map(s=>collectionPaletteKey('fixture',100,s))).size",palette),3);
assert(typeof palette.collectionFlowEdges==='function','flow must sample all four edges and fill the page, not draw two faded ribbons');
const sample=Uint8ClampedArray.from(Array.from({length:32*32},(_,i)=>[(i%32)*7,Math.floor(i/32)*7,80,255]).flat());
const edges=palette.collectionFlowEdges(sample,32,[0,0,0]);
assert.deepEqual(Array.from(edges,e=>e.length),[8,8,8,8]);
assert.deepEqual(JSON.parse(JSON.stringify(edges.map(e=>e[0]))),
  [[10.5,3.5,80],[213.5,10.5,80],[10.5,213.5,80],[3.5,10.5,80]]);
const distinct=[[255,0,0],[0,255,0],[0,0,255],[255,180,0]];
const distinctEdges=distinct.map(rgb=>Array(8).fill(rgb));
const colorAt=(u,v,light)=>Array.from(palette.collectionFlowColor(distinctEdges,u,v,light));
for(const light of [false,true]){
  const outside=[[[.50,-.03],[.50,-2]],[[1.03,.50],[3,.50]],[[.50,1.03],[.50,3]],[[-.03,.50],[-2,.50]]];
  for(const [i,points] of outside.entries()){
    const expected=Array.from(palette.collectionFlowColor(Array(4).fill(distinctEdges[i]),.5,.5,light));
    for(const [u,v] of points)assert.deepEqual(colorAt(u,v,light),expected,'extension uses only its facing edge');
  }
  const corner=colorAt(1.2,-.2,light);
  assert(corner[0]>corner[2]&&corner[1]>corner[2],'top-right corner blends red and green, never the bottom blue');
}
const rainbow=[[255,0,0],[255,85,0],[255,210,0],[70,242,100],[0,212,190],[30,150,255],[75,80,255],[142,70,255]];
const rainbowEdges=Array.from({length:4},()=>rainbow);
const farBelow=[.08,.30,.52,.72,.93].map(x=>palette.collectionFlowColor(rainbowEdges,x,2.65,false).join(','));
assert(new Set(farBelow).size>=4,'rainbow hues persist far below the cover');
const farRight=[.10,.30,.52,.72,.91].map(y=>palette.collectionFlowColor(rainbowEdges,2.40,y,false).join(','));
assert(new Set(farRight).size>=4,'right-side field stays multicolor in landscape');
assert.notEqual(palette.collectionFlowColor(rainbowEdges,.45,1.65,false).join(','),palette.collectionFlowColor(rainbowEdges,.45,2.15,false).join(','));
assert.match(css,/animation:collection-flow-drift 8s ease-in-out infinite alternate/,
  'landscape Flow background must loop smoothly without moving the artwork');
assert.match(css,/\.collection-flow-backdrop\{[^}]*opacity:\.94\}/,'keep the existing 94% texture opacity after compositing');
assert.match(css,/@media \(orientation:landscape\) and \(min-width:540px\) and \(prefers-reduced-motion:no-preference\)\{[\s\S]*?\.collection-flow-drift canvas\{animation:/);
assert.match(css,/\.collection-flow-drift\{[^}]*display:none/);
assert.match(css,/mask-image:[\s\S]*?transparent var\(--flow-drift-x\)[\s\S]*?transparent var\(--flow-drift-y\)/);
assert.match(app,/if\(wide\)\{[\s\S]*?driftCanvas\.getContext\('2d'\)\.drawImage\(canvas,0,0\)/);
assert.match(app,/backdrop\.style\.background=tailGradient/);
assert.match(css,/\.has-collection-flow \.collection-art\{\s*inset:var\(--collection-flow-inset\);width:auto;height:auto(?:;|\})/);
assert.match(css,/78%,color-mix\(in srgb,var\(--collection-base\) 96%,transparent\) 89%/);
assert.match(css,/var\(--collection-base\) 70%,transparent\) 72%/);
assert.match(app,/collectionEdgeColors\(flowEdges\.flat\(\)\.flatMap/,'flow tone uses all four sampled edges');
assert.match(css,/\.has-collection-flow \.collection-art::after\{display:none\}/);
const ios=r('Sources/Kumone/Features/Detail/GradientCollectionPage.swift');
assert.match(ios,/private var heroAccent: Color \{ portraitSquareCover \? \(palette\.heroAccent \?\? palette\.secondary\) : palette\.secondary \}/);
assert.match(ios,/Text\(title\)[\s\S]*?\.foregroundStyle\(portraitSquareCover \? \(palette\.isLight \? Color\.black : Color\.white\) : palette\.secondary\)/);
assert.match(ios,/\.background\(heroAccent, in: Capsule\(\)\)/);
const iosFlowBackdrop=ios.slice(ios.indexOf('private struct CollectionFlowBackdrop:'));
assert.match(iosFlowBackdrop,/Image\(decorative: texture, scale: 1\)\s*\.resizable\(\)\s*\.interpolation\(\.high\)/);
assert.match(iosFlowBackdrop,/if !reduceMotion \{\s*TimelineView\(\.animation\(minimumInterval: 1 \/ 30, paused: scenePhase != \.active\)\)/);
assert.match(iosFlowBackdrop,/timeIntervalSinceReferenceDate\.truncatingRemainder\(dividingBy: 16\)/);
assert.match(iosFlowBackdrop,/\.mask \{ motionMask\(viewport: input\.viewport\) \}/);
assert.match(iosFlowBackdrop,/\.compositingGroup\(\)\s*\.opacity\(0\.94\)/);
assert.match(iosFlowBackdrop,/let x = min\(1, max\(0, cover\.maxX \/ max\(1, viewport\.width\)\)\)/);
assert.match(iosFlowBackdrop,/let y = min\(1, max\(0, cover\.maxY \/ max\(1, viewport\.height\)\)\)/);
assert.doesNotMatch(iosFlowBackdrop.slice(iosFlowBackdrop.indexOf('TimelineView('),iosFlowBackdrop.indexOf('.task(id: input)')),
  /flowTexture/,'animation should reuse the texture, not resample it on every frame');
assert.match(ios,/\.background\(palette\.primary\.ignoresSafeArea\(\)\)/);
assert.match(ios,/palette\.primary\.opacity\(0\.70\), location: 0\.58/);
assert.match(ios,/palette\.primary\.opacity\(0\.96\), location: 0\.93/);
const iosPlaylist=r('Sources/Kumone/Features/Detail/PlaylistDetailView.swift');
assert.match(iosPlaylist,/portraitSquareCover: true/);
assert.match(ios,/if portraitSquareCover \{\s*squarePlaylistHero/);
const iosSquare=ios.slice(ios.indexOf('private var squarePlaylistHero'),ios.indexOf('private var hero:'));
assert.match(iosSquare,/actionPills\s*\.padding\(\.bottom, 6\)/,'iOS portrait playlist must reduce the gap below the play/favorite controls');
const playlistGradient=iosPlaylist.slice(iosPlaylist.indexOf('private func gradientContent('),iosPlaylist.indexOf('private func leftColumnWidth('));
assert.match(playlistGradient,/downloadButton\(detail, compact: true\)[\s\S]*?\.padding\(\.top, 8\)\s*\.padding\(\.bottom, landscapeLeftWidth == nil \? 4 : 8\)/,'iOS portrait playlist must reduce the gap below the track toolbar only');
assert.match(iosSquare,/coverArt\(size: CGSize\(width: width, height: width\)\)\s*\.overlay\(alignment: \.bottom\) \{\s*collectionCopy[\s\S]*?\.background \{/);
assert.match(iosSquare,/\.clear, location: 0\)[\s\S]*?\.opacity\(0\.72\), location: 0\.52\)[\s\S]*?palette\.primary, location: 1\)[\s\S]*?\.padding\(\.top, -10\)\s*\}\s*\}\s*actionPills/);
for(const swift of [ios,iosPlaylist]){
  assert.match(swift,/Text\(description.replacingOccurrences[^\n]+\)[\s\S]{0,190}?\.lineLimit\(2\)/);
}
assert.match(ios,/ArtworkPalette\.collection\(/);
assert.match(ios,/@AppStorage\("collectionCoverStyleLandscape"\)/);
assert.match(ios,/if landscape.isEmpty \{ landscape = portrait \}\s*portrait = value/);
assert.match(ios,/get: \{ style\(landscape: false\) \}/);
assert.match(ios,/if landscape \{ return self\.landscape\.isEmpty \? portrait : self\.landscape \}[\s\S]*?\.flow\.rawValue \? CollectionGradientStyle\.soft\.rawValue : portrait/);
assert.match(ios,/\? CGRect\(x: flowLeft, y: 0, width: side, height: side\)/,
  'iOS landscape playlist flow must use the full player-bottom square');
assert.match(ios,/let flowOffset = portraitSquareCover && hasFlow \? max\(0, \(miniPlayerFrame\?\.minX \?\? contentLeft\) - contentLeft\) : 0/);
assert.match(ios,/let flowLeft = left \+ flowOffset/,'iOS cover and copy must share the same safe-area-adjusted flow origin');
assert.match(ios,/let copyOffset = portraitSquareCover \? \(side - copyWidth\) \/ 2 \+ flowOffset : 0/);
assert.match(ios,/landscapeHero\(copyWidth: copyWidth\)\.frame\(width: side\)\s*\.offset\(x: copyOffset\)/);
assert.match(ios,/Text\(description\.replacingOccurrences[^\n]+\)[\s\S]*?\.multilineTextAlignment\(portraitSquareCover \? \.center : \.leading\)/);
assert.match(ios,/if hasFlow \{\s*CollectionFlowBackdrop\(edges: palette\.flowEdges, isLight: palette\.isLight, cover: cover\)\s*flowLandscapeArtwork\(size: cover\.size\)\.offset\(x: cover\.minX, y: cover\.minY\)/);
assert.match(ios,/\.frame\(width: viewport\.size\.width, height: viewport\.size\.height, alignment: \.topLeading\)/);
assert.match(ios,/\.ignoresSafeArea\(\.container\)/);
assert.doesNotMatch(ios,/flowStart|flowWidth|stageHeight|ShareLink|GradientCollectionComments/);
assert.match(ios,/Color\.clear\s*\.overlay \{\s*if let texture[\s\S]*?\.task\(id: input\) \{\s*texture = ArtworkPalette\.flowTexture\(input\.edges/,
  'a persistent host must start texture generation even before the first texture exists');
assert.match(ios,/style == \.flow && !portraitSquareCover \? flowCoverAspect : 100/);
assert.match(ios,/cover\.width \/ cover\.height \* 100/);
const maskSource=ios.slice(ios.indexOf('private func flowLandscapeArtwork'),ios.indexOf('private func landscapeArtwork'));
const flowMaskRule=css.match(/\.has-collection-flow \.collection-art\{([^}]+)\}/)[1];
const maskStops=(text)=>[...text.matchAll(/(transparent|#000|rgba\(0,0,0,([\d.]+)\))(?: ([\d.]+)%)?/g)]
  .map((m,i,list)=>[m[3]?Number((Number(m[3])/100).toFixed(4)):(i===0?0:1),m[1]==='transparent'?0:Number(m[2]??1)]);
const androidLandscape=css.slice(css.lastIndexOf('@media (orientation:landscape) and (min-width:540px)'));
const landscapeRightFade=androidLandscape.match(/--collection-flow-right-fade:([^;]+);/)?.[1];
assert(landscapeRightFade,'landscape Flow needs a slightly wider and smoother right transition');
const horizontalMask=flowMaskRule.match(/--collection-flow-horizontal-mask:([^;]+);/)[1];
const leftStops=maskStops(horizontalMask);
const oldRightStops=maskStops(flowMaskRule.match(/--collection-flow-right-fade:([^;]+);/)[1]);
const rightStops=maskStops(landscapeRightFade);
assert.deepEqual(leftStops,[[0,0],[.02,.16],[.06,.84],[.08,1]],'left Flow edge is unchanged');
assert.deepEqual(oldRightStops,[[.92,1],[.94,.84],[.98,.16],[1,0]],'portrait retains its original fade');
assert.deepEqual(rightStops,[[.89,1],[.905,.95],[.92,.82],[.94,.57],[.96,.30],[.98,.09],[.99,.02],[1,0]]);
const steepest=stops=>Math.max(...stops.slice(1).map(([p,a],i)=>(stops[i][1]-a)/(p-stops[i][0])));
assert(steepest(rightStops)<steepest(oldRightStops),'peak falloff must decrease');
const legacyVerticalStops=maskStops(flowMaskRule.match(/mask-image:var\(--collection-flow-horizontal-mask\),\s*(linear-gradient[^;]+);/)[1]);
assert.deepEqual(legacyVerticalStops,[[0,0],[.14,1],[.57,1],[.69,.80],[.86,.24],[1,0]]);
const parseSwiftStops=text=>[...text.matchAll(/\.init\(color: \.(clear|black)(?:\.opacity\(([\d.]+)\))?, location: ([\d.]+)\)/g)]
  .map(m=>[Number(m[3]),m[1]==='clear'?0:Number(m[2]??1)]);
const [iosLegacyVertical,iosFlowEdges]=maskSource.split('private func flowEdgeFade');
assert.deepEqual(parseSwiftStops(iosLegacyVertical),legacyVerticalStops);
const trailingCases=iosFlowEdges.match(/let trailing: \[Gradient\.Stop\] = softenRight \? \[([\s\S]*?)\] : \[([\s\S]*?)\]/);
assert.deepEqual(parseSwiftStops(trailingCases[1]),rightStops,'right blend matches on Android and iOS');
assert.deepEqual(parseSwiftStops(trailingCases[2]),oldRightStops,'iOS vertical trailing edge stays unchanged');
assert.deepEqual(parseSwiftStops(iosFlowEdges.split('return LinearGradient(stops: [')[1]),leftStops);
assert.match(maskSource,/flowEdgeFade\(\.leading, \.trailing, softenRight: true\)[\s\S]*?if portraitSquareCover \{\s*flowEdgeFade\(\.top, \.bottom\)/,
  'only the right landscape Flow edge is softened');
const androidPlaylistCopy=androidLandscape.match(/#page\[data-route=playlist\] \.collection-gradient \.collection-meta-viewport\{([^}]+)\}/)?.[1];
assert.match(androidPlaylistCopy??'',/margin-inline:auto/,'Android landscape playlist copy must center in the cover, not the player midpoint');
assert.doesNotMatch(androidPlaylistCopy,/right:auto/);
assert.match(portraitCSS,/\.collection-copy\{[^}]*justify-items:center[^}]*text-align:center/);
const landscapePlaylistFlow=androidLandscape.match(/#page\[data-route=playlist\] \.has-collection-flow \.collection-art\{([^}]+)\}/)?.[1];
assert(landscapePlaylistFlow,'Android landscape playlist needs a separate square flow rule');
assert.match(landscapePlaylistFlow,/inset:0 auto auto 0;\s*width:var\(--collection-cover-side\);height:var\(--collection-cover-side\)/,
  'Android square must touch the screen left edge and end at the player');
assert.match(landscapePlaylistFlow,/mask-image:var\(--collection-flow-horizontal-mask\)/,'Android restores its left inner fade');
const playlistFlowVertical=landscapePlaylistFlow.match(/mask-image:var\(--collection-flow-horizontal-mask\),\s*(linear-gradient[^;]+);/)[1];
assert.deepEqual(maskStops(playlistFlowVertical),[[0,1],...oldRightStops],'bottom fade is 8%; Android keeps top clear of fade');
const landscapePlaylistSolid=androidLandscape.match(/#page\[data-route=playlist\] \.collection-gradient\{([^}]+)\}/)?.[1];
assert(landscapePlaylistSolid,'Android landscape playlist uses the shared player-bottom square');
assert.match(landscapePlaylistSolid,/--collection-cover-fallback:clamp\(260px,42vw,420px\)/);
assert.match(landscapePlaylistSolid,/--collection-cover-side:min\(var\(--player-bottom,var\(--collection-cover-fallback\)\),max\(120px,62vw\)\)/);
assert.match(landscapePlaylistSolid,/grid-template-columns:var\(--collection-cover-side\) minmax\(0,1fr\)/);
assert.match(androidLandscape,/\.collection-gradient:not\(\.has-collection-flow\) \.collection-art\{[\s\S]*?inset:0 auto auto 0;[\s\S]*?height:var\(--collection-cover-side\);[\s\S]*?mask-composite:intersect/);
assert.match(androidLandscape,/\.collection-gradient:not\(\.has-collection-flow\) \.collection-art::after\{[\s\S]*?height:68%;[\s\S]*?var\(--collection-base\) 70%,transparent\) 58%/);
assert.match(app,/root\.style\.setProperty\('--player-bottom',bottom\+'px'\)/);
assert.match(app,/if\(!mini\)\{[^\n]*removeProperty\('--player-bottom'\)/);
assert.match(ios,/let side = frame.maxY[\s\S]*?return min\(side, max\(120, available \* 0.62\)\)/);
assert.doesNotMatch(maskSource,/palette\.primary|\.overlay\(/,'no solid-colored cover overlay in flow mode');
const artworkPalette=r('Sources/Kumone/DesignSystem/ArtworkPalette.swift');
assert.match(app,/const sw=84,sh=96/);
assert.match(artworkPalette,/let width = 84, height = 96/);
assert.match(ios,/landscapeHero\(copyWidth: copyWidth\)\.frame\(width: side\)/);
const sharedArt=ios.slice(ios.indexOf('private func landscapeArtwork'),ios.indexOf('/// 横屏封面边长'));
assert.doesNotMatch(sharedArt,/hasFlow|style ==/,'landscape artwork must not change when switching to flow');
assert.doesNotMatch(sharedArt,/bleed|\.blur\(|\.offset\(x:/,'the cover must not extend into the right column');
assert.match(sharedArt,/coverArt\(size: CGSize\(width: side, height: side\)\)[\s\S]*?\.frame\(height: side \* 0\.68\)[\s\S]*?edgeFade\(\.leading, \.trailing\)\s*\.mask \{ edgeFade\(\.top, \.bottom\) \}/);
const iosEdgeFade=ios.slice(ios.indexOf('private func edgeFade('),ios.indexOf('private func coverArt('));
const trailingStops=[...iosEdgeFade.matchAll(/\.init\(color: \.(clear|black)(?:\.opacity\(([\d.]+)\))?, location: ([\d.]+)\)/g)]
  .map(m=>[Number(m[3]),m[1]==='clear'?0:Number(m[2]??1)]).filter(([pos])=>pos>=.5);
const solidStops=landscapePlaylistSolid.match(/--collection-trailing-fade:([^;]+);/)[1];
assert.deepEqual(maskStops(solidStops),[[0,1],...trailingStops],'match iOS right/bottom fade without restoring top/left fade');
assert.match(ios,/ToolbarItemGroup\(placement: \.topBarTrailing\)[\s\S]*?action: play[\s\S]*?favorite\?\(\)[\s\S]*?action: search/);
const landscapeHero=ios.slice(ios.indexOf('private func landscapeHero'),ios.indexOf('private func edgeFade'));
assert.doesNotMatch(landscapeHero,/actionPills/);
assert.match(landscapeHero,/collectionCopy[\s\S]*?height: copyHeight\(column: geo.size,[\s\S]*?alignment: \.bottom/);
for(const detail of ['PlaylistDetailView','AlbumDetailView']){
  const swift=r(`Sources/Kumone/Features/Detail/${detail}.swift`);
  assert.match(swift,/coverPreference.style\(landscape: geo.size.width > geo.size.height\)/);
  assert.match(swift,/landscapeLeftWidth: (?:isLandscape|HomeView\.splitsLandscape\(geo.size\)) \? leftColumnWidth\(geo.size.width\) : nil/);
}
assert.match(r('Sources/Kumone/Features/Detail/PlaylistDetailView.swift'),/playlistBody\.id\("playlistTop"\)/);
assert.match(r('Sources/Kumone/Features/Detail/AlbumDetailView.swift'),/albumTrackRows\(visible/);
assert.doesNotMatch(r('Sources/Kumone/Features/Shared/TrackList.swift'),/coverGradient|gradientRow/);
console.log('COVER_ORIENTATION: Android/iOS gradient playlist title uses black/white; play button retains cover tint; album and Flow checks PASS');
