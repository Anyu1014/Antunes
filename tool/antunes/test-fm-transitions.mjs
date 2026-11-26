import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import vm from 'node:vm';

const root=process.argv[2]||resolve(import.meta.dirname,'../..');
const read=path=>readFileSync(resolve(root,path),'utf8');
const app=read('android/app/src/main/assets/app.js');
const slice=(a,b)=>app.slice(app.indexOf(a),app.indexOf(b));
let paints=0,barTicks=0,now=0,callback=null;
const host={};
const ctx=vm.createContext({
  fmLyricHost:()=>host, renderFmLyrics(){}, paintFmLyrics:()=>paints++,
  updateLyricBar:()=>barTicks++, lyricPaint(){}, requestAnimationFrame:fn=>{callback=fn;return 1;},
  player:{playing:true,loading:false,queue:[{id:1}],index:0}, document:{hidden:false}, lyricsBar:true,
  lyricLastTick:0, lyricLastPaint:0, LYRIC_TICK_MS:100, LYRIC_PAINT_MS:33, chromeMorphUntil:0,
  lyricRAF:0, overlayKind:'', performance:{now:()=>now},
});
vm.runInContext(slice('function lyricFrame(', 'const NAV_EASE'),ctx);
vm.runInContext(slice('function scheduleFullLyricFrame(', 'function paintLyricWords(')+slice("let fmLyricKey=", 'function renderFmLyrics('),ctx);
ctx.updateFmPlaybackLyrics();
for(let i=1;i<=60;i++) { const tick=callback;ctx.lyricFrame(now=i*(1000/60));tick(); }
assert.equal(paints,61,'one FM draw per frame, plus the initial synchronous paint');
assert(barTicks>=9&&barTicks<=10,'bottom bar must keep its original 100ms tick');
ctx.player.loading=true;
const loadingFrame=callback;callback=null;
loadingFrame();
assert.equal(callback,null,'while loading, no further full-rate frame is scheduled');
ctx.document.hidden=true;
ctx.updateFmPlaybackLyrics();
assert.equal(paints,62,'hidden FM must not paint');
assert.match(app,/nowPlayingLyricRAF=scheduleFullLyricFrame\(advancing,/);
assert.match(app,/paintLyricWords\(row,pos,fmLyricWords\)/);
assert.match(app,/async function updateFmArtwork\([\s\S]*?await next\.decode\(\)[\s\S]*?if\(!host\.isConnected\|\|ticket!==fmArtworkTicket\)return;[\s\S]*?host\.append\(next\)/);
assert.match(app,/if\(\(trackChanged\|\|wasPlaying!==player\.playing\|\|wasFM!==player\.fm\)&&route\.kind==='fm'\)syncFmPage\(\);/);
assert.match(app,/if\(stage\.dataset\.fmTrack!==String\(t\.id\)\)/);
assert.match(read('android/app/src/main/assets/app.css'),/\.fm-cover>\*\{position:absolute;inset:0;/);
const theme=read('Sources/Kumone/DesignSystem/Theme.swift');
assert.match(theme,/if isLandscape \{\s*content\s*\.toolbarBackground\(\.hidden, for: \.navigationBar\)\s*\.compatSymmetricTopEdgeEffect\(\)/);
for(const name of ['ArtistDetailView','AlbumDetailView']){
  const detail=read(`Sources/Kumone/Features/Detail/${name}.swift`);
  assert(detail.includes('.frostedNavigationBar('));
}
const fm=read('Sources/Kumone/Features/Pages/FMView.swift');
assert.match(fm,/let image = await ImageCache\.shared\.image\(for: url\)\s*guard !Task\.isCancelled, artworkURL == url else \{ return \}/);
assert.match(fm,/previousArtwork = [^\n]*: artwork[\s\S]*?withAnimation[\s\S]*?artwork = image/);
assert.match(fm,/coverArt\(coverDimension\)[\s\S]*coverArt\(side\)[\s\S]*private func coverArt[\s\S]*?artworkLayers/);
console.log('FM_TRANSITIONS: 60/60 frame ticks; existing bottom-bar cadence; guarded crossfades on both platforms; both iOS detail bars use soft edge PASS');
