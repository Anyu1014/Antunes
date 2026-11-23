import {escapeHTML as e,imageURL,track,uniqueTracks,preserveTrackCovers,time,count,parseLyrics,parseVerbatim,currentLyric,categories,navigationTabs} from './core.mjs';
const $=s=>document.querySelector(s);
const icons={home:'<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z"/>',fm:'<circle cx="12" cy="12" r="2"/><path d="M7 7a7 7 0 0 0 0 10m10-10a7 7 0 0 1 0 10M4 4a11.3 11.3 0 0 0 0 16M20 4a11.3 11.3 0 0 1 0 16"/>',grid:'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',user:'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="9" r="3"/><path d="M5 18a7 7 0 0 1 14 0"/>',search:'<circle cx="10.7" cy="10.7" r="7.7"/><path d="m16.3 16.3 5 5"/>',gear:'<path d="m9 3-.5 2.1-1.5.9-2.1-.6-2 3.4 1.6 1.5v1.8L3 13.6 5 17l2.1-.6 1.5.9L9 20h4l.5-2.7 1.5-.9 2.1.6 2-3.4-1.6-1.5v-1.8l1.6-1.5-2-3.4-2.1.6-1.5-.9L13 3z"/><circle cx="11" cy="11.5" r="3"/>',music:'<path d="M9 18V5l11-2v13M9 8l11-2"/><ellipse cx="5.5" cy="18" rx="3.5" ry="3"/><ellipse cx="16.5" cy="16" rx="3.5" ry="3"/>',play:'<path d="m8 4 12 8-12 8z" fill="currentColor" stroke="none"/>',pause:'<path d="M7 4h4v16H7zM15 4h4v16h-4z" fill="currentColor" stroke="none"/>',next:'<path d="m4 5 11 7L4 19zM18 5v14" fill="currentColor"/>',previous:'<path d="m20 5-11 7 11 7zM6 5v14" fill="currentColor"/>',heart:'<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8z"/>',download:'<circle cx="12" cy="12" r="9"/><path d="M12 6v11m-4-4 4 4 4-4"/>',clock:'<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/>',star:'<path d="m12 2 3.1 6.3 6.9 1-5 4.9 1.2 6.8-6.2-3.2L5.8 21 7 14.2 2 9.3l6.9-1z"/>',cloud:'<path d="M6 19a5 5 0 0 1-1-9.9 7 7 0 0 1 13.6-1A5.5 5.5 0 0 1 18 19z"/>',calendar:'<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 2v6m10-6v6M3 11h18M8 15h3m2 0h3m-8 3h3"/>',back:'<path d="m15 4-8 8 8 8"/>',chevron:'<path d="m9 5 7 7-7 7"/>',down:'<path d="m5 9 7 7 7-7"/>',up:'<path d="m5 15 7-7 7 7"/>',upTo:'<path d="M12 20V7m-5 5 5-5 5 5M5 4h14"/>',downTo:'<path d="M12 4v13m-5-5 5 5 5-5M5 20h14"/>',close:'<path d="m6 6 12 12M18 6 6 18"/>',more:'<circle cx="5" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="19" cy="12" r="1" fill="currentColor"/>',plus:'<path d="M12 4v16M4 12h16"/>',shuffle:'<path d="m3 5 3 0 12 14h3m-4-4 4 4-4 4M3 19h3l5-6m3-5 4-3h3m-4-4 4 4-4 4"/>',repeat:'<path d="m17 2 4 4-4 4M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4 4-4m14-1v2a3 3 0 0 1-3 3H3"/>',queue:'<path d="M3 5h18M3 10h18M3 15h10M3 20h10m4-5 5 3-5 3z"/>',lyrics:'<rect x="3" y="3" width="18" height="16" rx="3"/><path d="m7 19-3 3v-5M7 8h10M7 13h7"/>',lyric:'<path d="M4 6a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v7a3 3 0 0 1-3 3h-5l-5 3.5V16H7a3 3 0 0 1-3-3V6Z"/><path d="M9.6 7.2c-.75.5-1.2 1.25-1.2 2.1 0 .72.5 1.2 1.18 1.2.68 0 1.16-.48 1.16-1.16 0-1-.56-1.73-1.14-2.14Zm4.6 0c-.75.5-1.2 1.25-1.2 2.1 0 .72.5 1.2 1.18 1.2.68 0 1.16-.48 1.16-1.16 0-1-.56-1.73-1.14-2.14Z" fill="currentColor" stroke="none"/>',check:'<path d="m5 12 4 4L19 6"/><circle cx="12" cy="12" r="10"/>',circle:'<circle cx="12" cy="12" r="9"/>',trash:'<path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7m4-7v7"/>',album:'<rect x="3" y="3" width="18" height="18" rx="4"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>',artist:'<path d="M8 14 3 21l7-5m0-3 4 4"/><ellipse cx="15.5" cy="8.5" rx="5" ry="6" transform="rotate(45 15.5 8.5)"/>',menu:'<path d="M4 7h16M4 12h16M4 17h16"/>',select:'<circle cx="12" cy="12" r="9"/><path d="m8 12.2 2.7 2.8L16 9.4"/>',plusList:'<path d="M4 6h9M4 12h9M4 18h6"/><path d="M18 10v9M13.5 14.5h9"/>',tick:'<path d="m5 12.6 4.2 4.2L19 6.8" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',starOutline:'<path d="m12 3.6 2.7 5.6 6.1.9-4.4 4.3 1 6-5.4-2.9-5.4 2.9 1-6L3.2 10.1l6.1-.9z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>',eq:'<path d="M5 3v7m0 4v7M12 3v13m0 4v1M19 3v2m0 4v12M2 10h6m1 6h6m1-11h6"/>',wifi:'<path d="M2 8a17 17 0 0 1 20 0M5 12a12 12 0 0 1 14 0M8.5 16a6 6 0 0 1 7 0"/><circle cx="12" cy="20" r="1" fill="currentColor"/>'};
icons.locate='<circle cx="12" cy="12" r="3.1" fill="currentColor" stroke="none"/><g fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M15.97 18.36A7.5 7.5 0 0 1 8.03 18.36"/><path d="M5.64 15.97A7.5 7.5 0 0 1 5.64 8.03"/><path d="M8.03 5.64A7.5 7.5 0 0 1 15.97 5.64"/><path d="M18.36 8.03A7.5 7.5 0 0 1 18.36 15.97"/></g>';
icons.link='<path d="M10.6 13.4a4 4 0 0 0 5.7 0l2.8-2.8a4 4 0 1 0-5.7-5.7L12 6.3M13.4 10.6a4 4 0 0 0-5.7 0l-2.8 2.8a4 4 0 1 0 5.7 5.7L12 17.7"/>';
icons.chat='<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3h11A2.5 2.5 0 0 1 20 5.5v8a2.5 2.5 0 0 1-2.5 2.5H10l-6 4z"/>';
icons.moreVert='<circle cx="12" cy="4.6" r="1.75" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.75" fill="currentColor" stroke="none"/><circle cx="12" cy="19.4" r="1.75" fill="currentColor" stroke="none"/>';
icons.downloadArrow='<path d="M12 3v15m-6-6 6 6 6-6M5 21h14"/>';
icons.thumb='<path d="M14.5 9.5V5a2.5 2.5 0 0 0-2.5-2.5L7.5 11v10.5h9.9a2 2 0 0 0 2-1.7l1.2-7.6a2 2 0 0 0-2-2.3zM7.5 21.5H4.9A1.9 1.9 0 0 1 3 19.6v-6.7a1.9 1.9 0 0 1 1.9-1.9h2.6"/>';
icons.downloadFill='<circle cx="12" cy="12" r="9.5" fill="currentColor" stroke="none"/><path d="M12 6.4v7.8m-3.4-3.2L12 16.4l3.4-5.4" stroke="var(--surface)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>';
icons.heartFill='<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8z" fill="currentColor" stroke="none"/>';
icons.calendarFill='<rect x="3" y="4" width="18" height="17" rx="4.5" fill="currentColor" stroke="none"/><path d="M7 2.2v3.8m10-3.8v3.8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><g fill="var(--surface)" stroke="none"><circle cx="8" cy="12.4" r="1.15"/><circle cx="12" cy="12.4" r="1.15"/><circle cx="16" cy="12.4" r="1.15"/><circle cx="8" cy="16.4" r="1.15"/><circle cx="12" cy="16.4" r="1.15"/></g>';
icons.clockFill='<circle cx="12" cy="12" r="9.5" fill="currentColor" stroke="none"/><path d="M12 6.4v6.4l4 2.2" stroke="var(--surface)" stroke-width="2" stroke-linecap="round" fill="none"/>';
icons.starFill='<path d="m12 2 3.1 6.3 6.9 1-5 4.9 1.2 6.8-6.2-3.2L5.8 21 7 14.2 2 9.3l6.9-1z" fill="currentColor" stroke="none"/>';
icons.cloudFill='<path d="M6 19a5 5 0 0 1-1-9.9 7 7 0 0 1 13.6-1A5.5 5.5 0 0 1 18 19z" fill="currentColor" stroke="none"/>';
icons.navUser='<circle cx="12" cy="8" r="3.5"/><path d="M4 20v-1.5c0-3 3.6-5 8-5s8 2 8 5V20z"/>';
icons.lyricFill='<path d="M4 6a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v7a3 3 0 0 1-3 3h-5l-5 3.5V16H7a3 3 0 0 1-3-3V6Z M9.6 7.2c-.75.5-1.2 1.25-1.2 2.1 0 .72.5 1.2 1.18 1.2.68 0 1.16-.48 1.16-1.16 0-1-.56-1.73-1.14-2.14Zm4.6 0c-.75.5-1.2 1.25-1.2 2.1 0 .72.5 1.2 1.18 1.2.68 0 1.16-.48 1.16-1.16 0-1-.56-1.73-1.14-2.14Z" fill="currentColor" fill-rule="evenodd" stroke="none"/>';
icons.skipBack='<path d="M3.1 11.1 10.4 6v12l-7.3-5.1a1.1 1.1 0 0 1 0-1.8Zm7.3 0L18 5.7a1 1 0 0 1 1.6.8v11a1 1 0 0 1-1.6.8l-7.6-5.4a1.1 1.1 0 0 1 0-1.8Z" fill="currentColor" stroke="none"/>';
icons.skipForward='<g transform="translate(24 0) scale(-1 1)">'+icons.skipBack+'</g>';
function icon(name,cls=''){return `<svg viewBox="0 0 24 24" aria-hidden="true" class="${cls}">${icons[name]||icons.music}</svg>`;}
let callbacks=new Map(), serial=0;
function bind(fn){const id=String(++serial);callbacks.set(id,fn);return `data-call="${id}"`;}
function button(label,fn,cls='',aria=''){return `<button class="${cls}" ${bind(fn)}${aria?` aria-label="${e(aria)}"`:''}>${label}</button>`;}
function round(name,fn,label,cls=''){return button(icon(name),fn,`round ${cls}`,label);}
// 预热封面：进详情页前先把这批图的 URL 塞进 WebView 缓存，避免几十上百个
// 缩略图各自冷加载、错落糊上来（用户看到的「歌曲封面闪烁」）。
function preloadCovers(items,limit=48){const seen=new Set();let n=0;
  for(const t of items||[]){const src=imageURL(t&&(t.cover||t.album?.picUrl));if(!src||seen.has(src))continue;
    seen.add(src);const img=new Image();img.decoding='async';img.src=src;if(++n>=limit)break;}}

// 每处封面按实际显示尺寸取图：以前一律 384y384，44px 的曲目缩略图也要下 30~60KB，
// 一页 400+ 行时解码排队，就是"封面一格格闪出来"的来源。
const COVER_SIZES={'track-cover':96,'playlist-track-cover':96,'mini-cover':96,'cc-thumb':96,
  'avatar-button-img':96,'playlist-thumb':128,'fm-cover':384,'playlist-cover':512,
  'detail-cover':512,'np-land-art':640};
function coverSize(cls){for(const token of String(cls||'').split(/\s+/)){if(COVER_SIZES[token])return COVER_SIZES[token];}return 384;}
// 进详情页「之前」把可见批次的封面解码进内存：<img> 挂上去时若图已在内存，
// 第一帧就能出图，不会先露底色再糊上来。预算用完就放行，不拖慢进页面。
function preloadCoversAsync(items,limit=18,budgetMs=300){return new Promise(res=>{
  const urls=[];const seen=new Set();
  for(const t of items||[]){const src=imageURL(t&&(t.cover||t.album?.picUrl),96);if(!src||seen.has(src))continue;
    seen.add(src);urls.push(src);if(urls.length>=limit)break;}
  if(!urls.length){res();return;}
  let left=urls.length;let done=false;
  const finish=()=>{if(!done){done=true;res();}};
  const timer=setTimeout(finish,budgetMs);
  for(const src of urls){const img=new Image();
    const tick=()=>{if(--left<=0){clearTimeout(timer);finish();}};
    img.onload=()=>typeof img.decode==='function'?img.decode().then(tick,tick):tick();img.onerror=tick;img.decoding='async';img.src=src;}
});}

function cover(url,cls=''){const src=imageURL(url,coverSize(cls));return src?`<img class="${cls}" src="${e(src)}" alt="" loading="lazy" referrerpolicy="no-referrer">`:`<span class="${cls} placeholder">${icon('music')}</span>`;}

// 主界面环境色：与 iOS 端 MainWindowAmbientBackground / ArtworkPalette 同一套算法。
// 10×10 采样封面 → HSB 加权循环均值取主色相 → 线性渐变 + 右上角径向辉光，
// 透明度按亮暗主题与「背景色强度」缩放；换歌时颜色淡变，不改动任何布局。
const AMBIENT_FALLBACK={primary:[41,41,51],secondary:[23,23,31]};
const ambientPalette=new Map();
let ambientToken=0;
function hsbToRGB(h,s,b){
  const c=b*s, x=c*(1-Math.abs((h*6)%2-1)), m=b-c, n=Math.floor(h*6)%6;
  const t=[[c,x,0],[x,c,0],[0,c,x],[0,x,c],[x,0,c],[c,0,x]][n];
  return t.map(v=>Math.round(Math.max(0,Math.min(1,v+m))*255));
}
function ambientArtworkURL(url){
  if(!url)return '';
  try{const u=new URL(url);if(!['https:','http:'].includes(u.protocol))return '';u.protocol='https:';u.searchParams.set('param','768y768');return u.href;}catch{return '';}
}
async function ambientPaletteFor(url){
  const hit=ambientPalette.get(url);
  if(hit)return hit;
  const image=new Image();
  image.crossOrigin='anonymous';
  image.decoding='async';
  await new Promise((resolve,reject)=>{image.onload=()=>resolve();image.onerror=()=>reject(new Error('封面无法采样'));image.src=url;});
  const size=10, canvas=document.createElement('canvas');
  canvas.width=canvas.height=size;
  const context=canvas.getContext('2d',{willReadFrequently:true});
  context.drawImage(image,0,0,size,size);
  const data=context.getImageData(0,0,size,size).data;
  let sinSum=0,cosSum=0,satSum=0,brightSum=0,weightSum=0;
  for(let i=0;i<data.length;i+=4){
    const a=data[i+3]/255;
    if(a<=0.1)continue;
    const r=data[i]/255,g=data[i+1]/255,bv=data[i+2]/255;
    const maxC=Math.max(r,g,bv),minC=Math.min(r,Math.min(g,bv)),delta=maxC-minC;
    const sat=maxC===0?0:delta/maxC;
    const bright=maxC;
    let hue=0;
    if(delta>0.00001){
      if(r===maxC)hue=(g-bv)/delta;
      else if(g===maxC)hue=2+(bv-r)/delta;
      else hue=4+(r-g)/delta;
      hue/=6;
      if(hue<0)hue+=1;
    }
    const weight=Math.max(sat*(1-Math.abs(bright-0.55)),0.01);
    const angle=hue*2*Math.PI;
    sinSum+=Math.sin(angle)*weight;
    cosSum+=Math.cos(angle)*weight;
    satSum+=sat*weight;
    brightSum+=bright*weight;
    weightSum+=weight;
  }
  if(!weightSum)return AMBIENT_FALLBACK;
  let hue=Math.atan2(sinSum,cosSum)/(2*Math.PI);
  if(hue<0)hue+=1;
  const saturation=Math.min(satSum/weightSum*1.15,0.72);
  const brightness=brightSum/weightSum;
  const primary=hsbToRGB(hue,saturation,Math.min(Math.max(brightness,0.32),0.5));
  const secondary=hsbToRGB((hue+0.06)%1,Math.min(saturation*1.1,0.8),Math.min(Math.max(brightness*0.5,0.12),0.26));
  const colors={primary,secondary};
  if(ambientPalette.size>200)ambientPalette.clear();
  ambientPalette.set(url,colors);
  return colors;
}
function paintAmbient(colors){
  const layer=document.getElementById('ambient');
  if(!layer)return;
  const dark=document.documentElement.dataset.theme==='dark';
  const intensity=Math.min(1.5,Math.max(0.5,Number(prefs.ambientIntensity)||1));
  const gradient=(dark?0.14:0.08)*intensity;
  const glow=(dark?0.18:0.12)*intensity;
  const p=colors.primary, s2=colors.secondary;
  layer.style.setProperty('--amb-gradient-alpha',gradient.toFixed(3));
  layer.style.setProperty('--amb-primary',`rgb(${p[0]} ${p[1]} ${p[2]})`);
  layer.style.setProperty('--amb-secondary',`rgb(${s2[0]} ${s2[1]} ${s2[2]})`);
  layer.style.setProperty('--amb-glow',`rgb(${p[0]} ${p[1]} ${p[2]} / ${glow.toFixed(3)})`);
}
async function refreshAmbient(){
  const layer=document.getElementById('ambient');
  if(!layer)return;
  const enabled=!!prefs.ambient;
  layer.classList.toggle('hidden',!enabled);
  if(!enabled){ambientToken++;paintAmbient(AMBIENT_FALLBACK);return;}
  const current=player.queue[player.index];
  const url=current?ambientArtworkURL(current.cover||current.album?.picUrl):'';
  const token=++ambientToken;
  if(!url){paintAmbient(AMBIENT_FALLBACK);return;}
  try{
    const colors=await ambientPaletteFor(url);
    if(token===ambientToken)paintAmbient(colors);
  }catch{paintAmbient(AMBIENT_FALLBACK);}
}
const pending=new Map();let requestID=0;
function native(operation,args={}){return new Promise((resolve,reject)=>{
  const id=String(++requestID);const timeout=setTimeout(()=>{pending.delete(id);reject(new Error(operation==='download'?'下载超时，请检查已下载列表':'操作超时，请重试'));},operation==='download'?300000:45000);
  pending.set(id,{resolve,reject,timeout});
  if(window.KumoneNative)window.KumoneNative.call(id,operation,JSON.stringify(args));else{clearTimeout(timeout);pending.delete(id);reject(new Error('请在 Antunes 安卓应用中打开'));}
});}
window.addEventListener('native-reply',({detail:r})=>{const p=pending.get(r.id);if(!p)return;clearTimeout(p.timeout);pending.delete(r.id);r.error?p.reject(new Error(r.error)):p.resolve(r.data);});
const api=(path,payload={})=>{
  // 数据里缺 id 时会拼出 /v1/album/undefined 这类路径，原生白名单会直接拒绝并弹「未识别的接口」。
  // 这里先拦掉，避免把错误当成接口问题暴露给用户。
  if(!path||/\/(?:undefined|null|NaN)(?:$|[/?])/.test(path))return Promise.reject(new Error('数据缺少 id，已跳过请求'));
  return native('request',{path,payload});
};
function read(key,fallback){try{return JSON.parse(localStorage.getItem(key))??fallback;}catch{return fallback;}}
function write(key,value){try{localStorage.setItem(key,JSON.stringify(value));}catch{toast('本地存储空间不足，设置尚未保存');}}
function readPreferences(){
  const saved=read('preferences',{});
  if(Object.hasOwn(saved,'playerMode')){delete saved.playerMode;write('preferences',saved);}
  return saved;
}
// 音质档位：level 值直接发给 /song/enhance/player/url/v1。
let prefs={glassStyle:'native',tabLabels:false,lyricBar:true,lyricAlignMode:'center',showLibrary:true,startTab:'library',tabOrder:['showHome','showExplore','showSearch','showLibrary'],showHome:true,showExplore:false,showSearch:false,showFM:true,librarySearch:true,libraryOrder:['liked','daily','recents','collections','downloads','cloud'],libLiked:true,libDaily:true,libRecents:true,libCollections:true,libDownloads:true,libCloud:true,appearance:'system',quality:'exhigh',downloadQuality:'exhigh',translation:true,karaoke:true,annotation:'none',ambient:false,ambientIntensity:1,libCreatedLists:true,libCollectedLists:true,showLikedInCreated:false,artworkLink:true,eqEnabled:false,eqBands:Array(10).fill(0),losslessDefault:true,...readPreferences()};
let account=null,loggedIn=false,liked=new Set(),downloaded=new Set(),playlists=[],tab=(function(){const list=navigationTabs(prefs);const want=prefs.startTab;return (want&&want!=='auto'&&list.some(([k])=>k===want))?want:list[0][0];})(),route={kind:tab},history=[],renderID=0,overlayKind='',overlayHistory=[],overlayTimer=null;
let player={queue:[],index:0,playing:false,loading:false,position:0,duration:0,mode:'list',error:''},lastTrackID=0,lyrics=[],translations=[],romaji=[],lyricID=0,activeLine=-1,showLyric=false,lyricsBar=prefs.lyricBar!==false,lyricRAF=0,lyricSync=0,tabsExpanded=false;
const cache=new Map();let listTracks=[],detail=null,searchQuery='',searchType=1,category='全部',exploreItems=[],exploreOffset=0,exploreMore=false,queryTimer=null;
function toast(message){const node=$('#toast');node.textContent=message;node.classList.add('visible');clearTimeout(toast.timer);toast.timer=setTimeout(()=>node.classList.remove('visible'),3500);}
function errorToast(error){toast(error?.message||'操作失败，请重试');}
function applyTheme(){if(!['off','clear','frost','native'].includes(prefs.glassStyle)){prefs.glassStyle='native';write('preferences',prefs);}document.documentElement.dataset.glass=prefs.glassStyle;const dark=prefs.appearance==='dark'||prefs.appearance==='system'&&matchMedia('(prefers-color-scheme:dark)').matches;document.documentElement.dataset.tabLabels=prefs.tabLabels?'on':'off';document.documentElement.dataset.theme=dark?'dark':'light';native('theme',{dark}).catch(()=>{});refreshAmbient();}
matchMedia('(prefers-color-scheme:dark)').addEventListener('change',applyTheme);
function savePrefs(){write('preferences',prefs);applyTheme();}
function header(title,tools=''){return `<div class="top-bar">${history.length?`<div class="back-head">${button(icon('back'),back,'back-button glass','返回上一页')}<strong>${e(title)}</strong></div>`:''}<header class="header"><h1>${e(title)}</h1>${tools?`<div class="header-tools">${tools}</div>`:''}</header></div>`;}
function loading(title,plain=false){if(plain){$('#page').innerHTML=(history.length?`<div class="top-bar"><div class="back-head">${button(icon('back'),back,'back-button glass','返回上一页')}</div></div>`:'')+'<div class="page-loading"><span class="spinner"></span></div>';return;}$('#page').innerHTML=header(title)+Array.from({length:2},()=>`<section class="section"><div class="skeleton title"></div><div class="grid">${[0,1].map(()=>'<div><div class="skeleton cover"></div><div class="skeleton text"></div></div>').join('')}</div></section>`).join('');}
function empty(title,description='',name='music',action=''){return `<div class="empty">${icon(name)}<strong>${e(title)}</strong>${description?`<p>${e(description)}</p>`:''}${action}</div>`;}
function loginPrompt(title='登录后开启你的音乐世界',description='同步我喜欢的音乐、歌单与每日推荐',name='user'){return empty(title,description,name,button('登录',()=>openLogin(),'primary pill'));}
let chromeKey='',nowPlayingLyricRAF=0;
function toggleLyricsBar(){lyricsBar=!lyricsBar;if(!lyricsBar)tabsExpanded=false;const t=player.queue[player.index];if(lyricsBar&&t&&lyricID!==t.id)loadLyrics(t.id);if(lyricsBar){lyricSync=Date.now();if(!lyricRAF)lyricRAF=requestAnimationFrame(lyricFrame);}else if(lyricRAF){cancelAnimationFrame(lyricRAF);lyricRAF=0;}renderChrome();}
function lyricPosition(){return player.position+(player.playing?Date.now()-lyricSync:0);}
const LYRIC_ROW_H=24;
let lyricRows=[],lyricRowsKey='',lyricCursor=-1,lyricMes=null,lyricMesFont='';
const lyricAdv=new Map();
function lyricFont(bar){return `600 15px ${getComputedStyle(bar).fontFamily||'system-ui'}`;}
// canvas 量中文会偏窄一成左右，于是长句按偏窄宽度切分、超出容器后被省略号截断。
// 改成拿真实 DOM 量：量到的就是真正渲染的那套字体，逐字缓存一次即可。
function lyricMeasure(bar,font){
  if(!lyricMes||lyricMes.parentNode!==bar){lyricMes=document.createElement('i');lyricMes.className='lyric-measure';bar.append(lyricMes);}
  if(font!==lyricMesFont){lyricMesFont=font;lyricAdv.clear();lyricMes.style.font=font;}
  return lyricMes;
}
function lyricWidth(bar,font,text){
  if(!text)return 0;
  const m=lyricMeasure(bar,font);let total=0;
  for(const ch of text){
    let w=lyricAdv.get(ch);
    if(w===undefined){m.textContent=ch;w=m.getBoundingClientRect().width;lyricAdv.set(ch,w);}
    total+=w;
  }
  return total;
}
// 整句按宽度折排：yrc 按词，lrc 按字；每排各自记一个开始时间，游标据此上滑。
// 与 iOS 同一套分工：换排检测 100ms 一次，逐字擦亮 30fps 一次，
// 且只在「正在播 + 页面可见 + 底栏没在形变」时画。
const LYRIC_TICK_MS=100,LYRIC_PAINT_MS=33;
let lyricLastTick=0,lyricLastPaint=0,lyricPaintKey='',lyricBarW=0,lyricWordNodes=[],chromeMorphUntil=0;

function lyricPlan(maxWidth,bar,font){
  const rows=[];
  for(let n=0;n<lyrics.length;n++){
    const line=lyrics[n],next=lyrics[n+1],words=line.words;
    if(!words||words.length<2){
      const chunks=[];let cur='',used=0;
      for(const ch of (line.text||'')){const w=lyricWidth(bar,font,ch);if(cur&&used+w>maxWidth){chunks.push(cur);cur='';used=0;}cur+=ch;used+=w;}
      if(cur)chunks.push(cur);
      if(!chunks.length)chunks.push('');
      const span=Math.max(1,(next?next.at:line.at+4000)-line.at);
      const per=span/Math.max(1,chunks.length);
      chunks.forEach((chunk,i)=>{
        const start=line.at+per*i;
        // 没有逐字时间轴（普通 lrc）时按行时长均分合成逐字数据，和播放页
        // lyricWords() 同一套思路：每个字拿 85% 的行时长依次推进，留一点停顿。
        // 不合成的话这排渲染出来是纯文本、没有 .lyric-word，底栏就永远不擦亮。
        const chars=[...chunk], usable=Math.max(1,per*0.85), step=usable/Math.max(1,chars.length);
        rows.push({text:chunk,start,words:chars.map((ch,j)=>({text:ch,at:start+step*j,duration:step}))});
      });
    }else{
      let cur=[],used=0;
      for(const w of words){const adv=lyricWidth(bar,font,w.text);if(cur.length&&used+adv>maxWidth){rows.push({words:cur,start:cur[0].at});cur=[];used=0;}cur.push(w);used+=adv;}
      if(cur.length)rows.push({words:cur,start:cur[0].at});
    }
  }
  return rows;
}
function lyricRowHTML(row){
  if(!row.words)return `<div class="lyric-line-row">${e(row.text||'…')}</div>`;
  return `<div class="lyric-line-row">${row.words.map(w=>`<span class="lyric-word" data-at="${w.at}" data-duration="${Math.max(1,w.duration||0)}">${e(w.text)}</span>`).join('')}</div>`;
}
function lyricStatic(track,text,next){
  const key=text+'|'+(next||'');
  if(track.dataset.static===key)return;
  track.dataset.static=key;lyricRowsKey='';lyricRows=[];lyricCursor=-1;lyricPaintKey='';lyricWordNodes=[];
  track.style.transform='translate3d(0,0,0)';
  track.innerHTML=`<div class="lyric-line-row is-cur">${e(text)}</div><div class="lyric-line-row">${e(next||'')}</div>`;
}
function updateLyricBar(){
  const bar=$('#chrome .lyric-bar');if(!bar)return;
  const track=bar.querySelector('.lyric-track');if(!track)return;
  const t=player.queue[player.index];
  if(!t){lyricStatic(track,'未在播放','');return;}
  if(lyricID!==t.id&&!player.loading)loadLyrics(t.id);
  if(!lyrics.length){lyricStatic(track,player.loading?'歌词加载中…':'暂无歌词',t.name);return;}
  const align=['left','center','right'].includes(prefs.lyricAlignMode)?prefs.lyricAlignMode:'center';
  if(bar.dataset.align!==align){bar.dataset.align=align;bar.style.setProperty('--lyric-align',align);}
  // clientWidth 只在尺寸变化时才需要重排；量到就缓存，避免每次 tick 都强制同步布局。
  const rawW=Math.round(bar.clientWidth);
  if(rawW!==lyricBarW){lyricBarW=rawW;lyricRowsKey='';}
  const width=Math.max(40,rawW-44),key=`${lyricID}|${lyrics.length}|${width}`;
  // 私聊会拆掉底栏；同一首歌、同一宽度的新容器也需要填入歌词行。
  if(key!==lyricRowsKey||!track.firstElementChild){lyricRowsKey=key;lyricRows=lyricPlan(width,bar,lyricFont(bar));lyricCursor=-1;lyricPaintKey='';lyricWordNodes=[];track.dataset.static='';track.innerHTML=lyricRows.map(lyricRowHTML).join('');}
  const pos=lyricPosition();let k=0;
  for(let i=0;i<lyricRows.length;i++)if(lyricRows[i].start<=pos)k=i;
  if(k!==lyricCursor){
    lyricCursor=k;track.style.transform=`translate3d(0,${-k*LYRIC_ROW_H}px,0)`;
    // 当前这一排要加深，其余保持 32% 的淡色；换排时只动这两个类。
    const prev=track.querySelector('.lyric-line-row.is-cur');if(prev)prev.classList.remove('is-cur');
    const next=track.children[k];if(next)next.classList.add('is-cur');
    // 换排时才重新收集当前排的逐字节点，帧内不再查询 DOM。
    lyricPaintKey='';lyricWordNodes=[];
  }
}

// 逐字擦亮：只碰当前排那些缓存的 span，30fps 上限。
function lyricPaint(){
  const bar=$('#chrome .lyric-bar');if(!bar)return;
  const track=bar.querySelector('.lyric-track');if(!track)return;
  const key=`${lyricID}:${lyricCursor}`;
  if(key!==lyricPaintKey){
    // 只有真的收到逐字节点才记账：刚重建 innerHTML 时行里可能还没有 span，
    // 若此时把 key 记下来，就会一直复用空数组、再也不重试（逐字擦亮永久消失）。
    const row=track.children[lyricCursor];
    const nodes=row?[...row.querySelectorAll('.lyric-word')]:[];
    if(nodes.length){lyricPaintKey=key;lyricWordNodes=nodes;}
  }
  if(!lyricWordNodes.length)return;
  const pos=lyricPosition();
  for(const node of lyricWordNodes){
    const at=Number(node.dataset.at),dur=Number(node.dataset.duration)||1;
    node.style.setProperty('--progress',Math.max(0,Math.min(100,(pos-at)/dur*100)).toFixed(1)+'%');
  }
}

function lyricFrame(now){
  const fmHost=fmLyricHost();
  if(!lyricsBar&&!fmHost){lyricRAF=0;return;}
  now=now||performance.now();
  const morphing=Date.now()<chromeMorphUntil;
  // 换排检测：10Hz 足够（最短一排也有几百毫秒）。
  if(now-lyricLastTick>=LYRIC_TICK_MS){
    lyricLastTick=now;
    if(lyricsBar)updateLyricBar();
    if(fmHost){renderFmLyrics();paintFmLyrics();}
  }
  // 逐字擦亮：只在播、可见、底栏没在形变时跑，和 iOS 的停摆条件一致。
  if(now-lyricLastPaint>=LYRIC_PAINT_MS&&player.playing&&!document.hidden&&!morphing){
    lyricLastPaint=now;lyricPaint();
  }
  lyricRAF=requestAnimationFrame(lyricFrame);
}
const NAV_EASE='cubic-bezier(.32,.72,0,1)';
// 底栏「头像 ⇄ 板块」用 FLIP 式过渡：歌词侧宽度做形变，新出现的一侧淡入缩放
function toggleNav(next){
  // 形变持续 0.34s（见 .lyric-track 的 transition）：这段时间不画逐字，
  // 免得和「玻璃按新宽度重采样」抢同一帧。
  chromeMorphUntil=Date.now()+380;
  const bar=document.querySelector('.bar-row');
  if(!bar){tabsExpanded=next;renderChrome();return;}
  const pick=sel=>bar.querySelector(sel);
  const before=(pick('.lyric-row')||pick('.lyric-collapsed'))?.getBoundingClientRect().width||0;
  tabsExpanded=next;renderChrome();
  const bar2=document.querySelector('.bar-row');
  if(!bar2)return;
  const lyric=bar2.querySelector('.lyric-row')||bar2.querySelector('.lyric-collapsed');
  const nav=bar2.querySelector('.tab-row')||bar2.querySelector('.avatar-button');
  if(lyric&&before){
    const to=lyric.getBoundingClientRect().width;
    if(Math.abs(to-before)>1){
      lyric.style.flex=`0 0 ${to}px`;
      lyric.animate([{flexBasis:before+'px'},{flexBasis:to+'px'}],{duration:360,easing:NAV_EASE})
        .onfinish=()=>{lyric.style.flex='';};
    }
  }
  if(nav)nav.animate([{opacity:0,transform:'scale(.92)'},{opacity:1,transform:'none'}],{duration:280,delay:70,easing:'ease-out',fill:'backwards'});
}
// 歌单页横屏要把顶部信息收进「播放控制器右边缘」以内，边界只能取 .mini 的真实右边缘，
// 因为 detail 状态下 chrome 的 left/width 由别的规则决定，用 clamp() 反推会漂。
let playerEdge=0;
function syncPlayerEdge(){
  const mini=document.querySelector('#chrome .mini'),root=document.documentElement;
  if(!mini){root.style.removeProperty('--player-edge');root.style.removeProperty('--player-left');root.style.removeProperty('--player-top');playerEdge=0;return;}
  const r=mini.getBoundingClientRect();
  const left=Math.round(r.left),right=Math.round(r.right),top=Math.round(r.top);
  // 横屏漫游的封面方框：左右取播放控制器两缘，上缘取「漫游」二字的下沿。
  const h1=document.querySelector('#page .header h1');
  const fmTop=h1?Math.round(h1.getBoundingClientRect().bottom+8):0;
  const key=[right,left,top,fmTop].join(',');
  if(key===playerEdge)return;
  playerEdge=key;
  root.style.setProperty('--player-edge',right+'px');
  root.style.setProperty('--player-right',right+'px');
  root.style.setProperty('--player-left',left+'px');
  root.style.setProperty('--player-top',top+'px');
  if(fmTop)root.style.setProperty('--fm-top',fmTop+'px');
  const boxW=Math.max(0,right-left),boxH=Math.max(0,top-fmTop);
  if(boxW&&boxH)root.style.setProperty('--fm-cover',Math.max(48,Math.round(Math.min(boxW,boxH)*0.88))+'px');
}
addEventListener('resize',syncPlayerEdge);
// 横竖屏 / 窗口宽度一变就整页重排：分栏、卡片宽度都是渲染时按当时的视口算的，
// 光靠 CSS 媒体查询只能改样式、改不了 DOM 结构（例如听歌排行横屏的两列）。
let layoutSignature=layoutSignatureNow();
function layoutSignatureNow(){
  const landscape=window.matchMedia('(min-aspect-ratio: 1/1)').matches&&innerWidth>=540;
  return (landscape?'L':'P')+'|'+(innerWidth>=540?'wide':'narrow');
}
function relayoutOnSizeChange(){
  const next=layoutSignatureNow();
  if(next===layoutSignature)return;
  layoutSignature=next;
  if(route.kind!=='chat'||!$('#chat-form'))render();
}
addEventListener('resize',relayoutOnSizeChange);
addEventListener('orientationchange',()=>setTimeout(relayoutOnSizeChange,150));
function renderChrome(){
  const t=player.queue[player.index], tabs=navigationTabs(prefs), showNavigation=tabs.length>0, chrome=$('#chrome');
  // 私聊页独占整屏：底栏（迷你播放条 + 导航）一起收起来。
  const inChat=route.kind==='chat';
  document.body.classList.toggle('chrome-hidden',inChat);
  if(inChat){if(chrome.innerHTML){chrome.innerHTML='';chromeKey='';}return;}
  $('#page').classList.toggle('library-only',!showNavigation);
  const key=`${t?t.id:'-'}|${tabs.length}|${tabs.map(x=>x[0]).join('')}|${lyricsBar?1:0}${tabsExpanded?1:0}|${selecting?1:0}${picked.size}|${(account?.avatarUrl||prefs.avatarUrl)?'a':'u'}`;
  if(!t)tabsExpanded=false;
  if(key!==chromeKey){chromeKey=key;chrome.innerHTML=(t?`<div class="mini glass" ${bind(()=>openNowPlaying(true))}>${button(cover(t.cover,'mini-cover'),()=>openNowPlaying(true),'','打开正在播放')}${button(`<strong>${e(t.name)}</strong><small>${e(t.artist)}</small>`,()=>openNowPlaying(true),'mini-info','打开正在播放')}${round(player.fm?'trash':'previous',()=>player.fm?fmTrash():control('previous'),player.fm?'不喜欢，换一首':'上一首')}${round(player.playing?'pause':'play',()=>control('toggle'),'播放或暂停','mini-toggle')}${round('next',()=>control('next'),'下一首')}</div>`:'')+`<div class="bar-row${lyricsBar&&t?' has-lyric':''}${lyricsBar&&t&&tabsExpanded&&tabs.length>=4?' lyric-as-word':''}">`+(t&&lyricsBar?(tabsExpanded&&tabs.length>=4?button('<span class="lyric-glyph">词</span>',()=>toggleNav(false),'round lyric-collapsed glass','展开歌词'):`<div class="lyric-row"><div class="lyric-bar glass"><div class="lyric-viewport"><div class="lyric-track"></div></div></div></div>`):'')+(showNavigation?(lyricsBar&&t&&!tabsExpanded?button((tabs.length===1&&tabs[0][0]!=='library')?`<span class="avatar-button-icon">${icon(tabs[0][2])}</span>`:(account?.avatarUrl||prefs.avatarUrl?cover(account?.avatarUrl||prefs.avatarUrl,'avatar-button-img'):`<span class="avatar-button-icon">${icon('user')}</span>`),()=>toggleNav(true),'avatar-button glass','展开导航'):`<div class="tab-row"><nav class="tabs glass" aria-label="主导航" style="--tab-count:${tabs.length}">${tabs.map(([key,label,name])=>button(icon(key==='library'?'navUser':name,(key==='search'||key==='fm')?'nav-line':'')+`<span>${label}</span>`,()=>switchTab(key),`tab ${tab===key?'active':''}`,label)).join('')}</nav></div>`):'')+`</div>`+(selecting&&listTracks.length?selectBar(listTracks):'');}
  const toggle=chrome.querySelector('.mini-toggle');
  if(toggle)toggle.innerHTML=icon(player.playing?'pause':'play');
  chrome.querySelectorAll('.tab').forEach((b,i)=>b.classList.toggle('active',tabs[i][0]===tab));
  chrome.classList.toggle('detail',history.length>0);
  chrome.classList.toggle('lyrics-open',lyricsBar&&!!t);
  chrome.classList.toggle('nav-expanded',!!(lyricsBar&&t)&&tabsExpanded);
  const bar=chrome.querySelector('.lyric-bar');
  if(bar&&!bar.dataset.wired){bar.dataset.wired='1';bar.addEventListener('click',()=>{if(!lyricsBar||!tabsExpanded)return;toggleNav(false);});}
  if(lyricsBar)updateLyricBar();
  // 底栏歌词的逐字擦亮只在 lyricFrame 里跑；这个循环之前只有「手动切歌词」和「漫游」会启动，
  // 冷启动时 lyricsBar 默认为真却没人拉起循环，于是 --progress 永远不写、擦亮整段失效。
  if((lyricsBar||fmLyricHost())&&!lyricRAF)lyricRAF=requestAnimationFrame(lyricFrame);
  $('#page').classList.toggle('has-track',!!t);
  syncPlayerEdge();
}
async function control(action,args={}){
  if(['toggle','next','previous','pause','play'].includes(action))playbackIntent++;
  if(action==='toggle'&&!PlaybackLive&&player.queue.length){await native('control',{action:'queue',queue:player.queue,index:player.index,mode:player.mode});PlaybackLive=true;return;}
  await native('control',{action,...args});
}
let PlaybackLive=false,loginGeneration=0,sessionGeneration=0,playbackIntent=0;
const accountOwner=()=>loggedIn?Number(account?.userId)||null:null;
function resetAccountSession(signedIn){
  sessionGeneration++;playbackIntent++;renderID++;
  loggedIn=signedIn;account=null;liked.clear();playlists=[];cache.clear();
}
async function play(items,index=0,intent=++playbackIntent,{fm=false}={}){
  if(intent!==playbackIntent)return false;
  const q=uniqueTracks(items);if(!q.length){toast('暂无可播放歌曲');return false;}
  if(!!player.fm!==fm){player.fm=fm;prefs.fm=fm;savePrefs();}
  await native('control',{action:'queue',queue:q,index:Math.min(index,q.length-1),mode:player.mode});
  PlaybackLive=true;
  return intent===playbackIntent;
}
function navigate(next){if(selecting){selecting=false;picked.clear();}history.push({route,scroll:$('#page').scrollTop});route=next;render();}
function back(){if(overlayKind){closeOverlay();return;}if(selecting){selecting=false;picked.clear();}const previous=history.pop();if(previous){route=previous.route;render().then(()=>{if(route===previous.route)$('#page').scrollTop=previous.scroll;});}else switchTab('home');}
function switchTab(next){if(selecting){selecting=false;picked.clear();}closeOverlay(true);const list=navigationTabs(prefs);tab=list.some(([key])=>key===next)?next:list[0][0];if(tab!=='search')lastTab=tab;history=[];route={kind:tab};render();}
let lastTab=tab==='search'?null:tab;
// 关闭搜索时不能把用户丢在原地：上一个板块可能已经被关掉，
// 甚至只剩「搜索」一个板块，这时直接落到「我的」页。
function closeSearch(){
  clearTimeout(queryTimer);
  $('#query')?.blur();
  if(history.length){back();return;}
  const list=navigationTabs(prefs).map(([key])=>key);
  const fallback=(lastTab&&lastTab!=='search'&&list.includes(lastTab))?lastTab:list.find(key=>key!=='search');
  if(fallback){switchTab(fallback);return;}
  tab='library';lastTab='library';history=[];route={kind:'library'};render();
}
// 右上角搜索按钮只受「我的页搜索按钮」开关控制；搜索板块被关掉时改成栈内推一层。
function openSearchFromLibrary(){if(navigationTabs(prefs).some(([k])=>k==='search')){switchTab('search');return;}navigate({kind:'search'});}
async function render(){
  const ticket=++renderID,session=sessionGeneration;const page=$('#page');const samePlaylist=route.kind==='playlist'&&page.dataset.route==='playlist'&&detail?.id===route.id;page.dataset.route=route.kind;if(!samePlaylist)page.scrollTop=0;page.className=['library'].includes(route.kind)?'grouped':'';renderChrome();watchPlaylistNavMerged();
  const title={home:'推荐',explore:'精选',fm:'漫游',search:'搜索',library:'我的',playlist:'歌单',album:'专辑',artist:'歌手',daily:'每日推荐',downloads:'已下载',recents:'最近播放',cloud:'音乐云盘',collections:'我的收藏',rank:'听歌排行',messages:'私信',chat:'私信'}[route.kind]||'Antunes';
  try{
    if(route.kind==='playlist'){await playlistPage(ticket);return;}
    if(route.kind!=='search')loading(title,['album','artist'].includes(route.kind));
    let content='';
    switch(route.kind){
      case 'home':content=await homePage(ticket,session);break;
      case 'explore':content=await explorePage();break;
      case 'fm':content=fmPage();break;
      case 'search':content=searchPage();break;
      case 'library':content=await libraryPage();break;
      case 'album':case 'artist':content=await detailPage();break;
      case 'daily':if(!loggedIn)content=header(title)+loginPrompt();else{const r=await api('/v3/discovery/recommend/songs');listTracks=uniqueTracks(r.data?.dailySongs||r.recommend||[]);content=header(title)+songPageTools()+tracksHTML(listTracks);}break;
      case 'recents':listTracks=read('recents',[]);content=header(title)+(listTracks.length?songPageTools()+tracksHTML(listTracks):empty('还没有播放记录'));break;
      case 'downloads':listTracks=(await native('downloads')).map(x=>({...track(x),bytes:x.bytes}));content=header(title,round('gear',openStorage,'存储空间'))+(listTracks.length?songPageTools()+tracksHTML(listTracks):empty('还没有下载歌曲','在歌曲菜单中选择下载，离线时也能播放。','download'));break;
      case 'cloud':if(!loggedIn)content=header(title)+loginPrompt();else{const r=await api('/cloud/get',{limit:200,offset:0});listTracks=uniqueTracks((r.data||[]).map(x=>x.simpleSong||x));content=header(title)+(listTracks.length?songPageTools()+tracksHTML(listTracks):empty('音乐云盘为空'));}break;
      case 'collections':content=await collectionsPage();break;
      case 'rank':content=await rankPage();break;
      case 'messages':content=await messagesPage();break;
      case 'chat':content=await chatPage();break;
    }
    if(ticket!==renderID||session!==sessionGeneration)return;page.innerHTML=content;page.classList.toggle('has-track',!!player.queue[player.index]);
    if(route.kind==='search'){setupSearch();void updateSearch(ticket);}
    if(route.kind==='chat')scrollChatToLatest(page);
    if(fmLyricHost()&&player.queue[player.index]){fmLyricKey='';if(!lyricRAF)lyricRAF=requestAnimationFrame(lyricFrame);}
  }catch(err){if(ticket!==renderID||session!==sessionGeneration)return;page.innerHTML=header(title)+empty('加载失败',err.message,'wifi',button('重试',()=>render(),'muted-button'));}
}
function card(item,kind='playlist'){
  const pic=item.coverImgUrl||item.picUrl||item.img1v1Url||item.coverUrl||'';
  const subtitle=kind==='album'?item.artist?.name||(item.artists||[]).map(x=>x.name).join(' / '):item.copywriter||'';
  return button(`<div class="artwork">${cover(pic)}${item.playCount?`<span class="play-count">${icon('play')}${count(item.playCount)}</span>`:''}</div><div class="card-title">${e(item.name)}</div>${subtitle?`<div class="card-subtitle">${e(subtitle)}</div>`:''}`,()=>navigate({kind,id:item.id}),`card ${kind}`,item.name);
}
// 首页「推荐」的板块：与 /homepage/block/page 下发的 block 一一对应，顺序固定；
// 「根据你听过的热门节目推荐」（电台）不展示。
const HOME_SLOTS=['recommendedPlaylists','recentlyTrending','tailoredRecommendation','charts','personalPlaylists','radarPlaylists','regionalHits','likedSongRoaming','likedSongRecommendations'];
const HOME_SLOT_TITLES={recommendedPlaylists:'推荐歌单',recentlyTrending:'近期云村热播',tailoredRecommendation:'根据你的口味为你推荐',charts:'排行榜',personalPlaylists:'你的歌单',radarPlaylists:'雷达歌单',regionalHits:'最近的热门歌曲',likedSongRoaming:'从你喜欢的歌开始漫游',likedSongRecommendations:'根据你喜爱的歌曲推荐'};
function homeSlot(block){
  const code=String(block.blockCode||'').toUpperCase();
  const title=String(block.uiElement?.subTitle?.title||block.uiElement?.mainTitle?.title||'').trim();
  if(code.includes('VOICELIST')||title.includes('热门节目推荐'))return null;
  if(code==='HOMEPAGE_BLOCK_PLAYLIST_RCMD'||title==='推荐歌单')return 'recommendedPlaylists';
  if(title.includes('近期云村热播')||code==='HOMEPAGE_BLOCK_STYLE_RCMD')return 'recentlyTrending';
  if(title.startsWith('根据')&&title.endsWith('为你推荐'))return 'tailoredRecommendation';
  if(code.includes('TOPLIST')||code.includes('RANK')||title==='排行榜')return 'charts';
  if(code==='HOMEPAGE_BLOCK_MGC_PLAYLIST'||title.includes('雷达歌单'))return 'radarPlaylists';
  if(title.includes('最近的热门歌曲'))return 'regionalHits';
  if(title.includes('从你喜欢的歌开始漫游'))return 'likedSongRoaming';
  if(title.includes('根据你喜爱的歌曲推荐'))return 'likedSongRecommendations';
  if(title.endsWith('的歌单'))return 'personalPlaylists';
  return null;
}
function homeSections(data){
  const blocks=(data&&data.blocks)||[];const found=new Map();
  for(const block of blocks){
    const slot=homeSlot(block);if(!slot||found.has(slot))continue;
    const unique=new Map();for(const creative of block.creatives||[])for(const r of creative.resources||[])unique.set(String(r.resourceType||'')+'|'+String(r.resourceId),r);
    const resources=[...unique.values()];
    const title=String(block.uiElement?.subTitle?.title||block.uiElement?.mainTitle?.title||'').trim()||HOME_SLOT_TITLES[slot];
    const songs=uniqueTracks(resources.filter(r=>r.resourceExtInfo&&r.resourceExtInfo.song).map(r=>r.resourceExtInfo.song));
    const playlistIDs=new Set();
    const playlists=resources.filter(r=>['list','playlist'].includes(String(r.resourceType||'').toLowerCase())&&Number(r.resourceId)>0&&!playlistIDs.has(Number(r.resourceId))&&playlistIDs.add(Number(r.resourceId)))
      .map(r=>({id:Number(r.resourceId),name:r.uiElement?.mainTitle?.title||'歌单',coverImgUrl:r.uiElement?.image?.imageUrl,playCount:r.resourceExtInfo?.playCount||0,copywriter:r.uiElement?.subTitle?.title||''}));
    if(songs.length)found.set(slot,{slot,title,songs});else if(playlists.length)found.set(slot,{slot,title,playlists});
  }
  return HOME_SLOTS.filter(slot=>found.has(slot)).map(slot=>found.get(slot));
}
function songShelf(title,list){
  const queue=uniqueTracks(list).slice(0,12);if(!queue.length)return '';
  return `<section class="section"><div class="section-head"><h2>${e(title)}</h2></div><div class="shelf">${queue.map((t,i)=>button(`<div class="artwork">${cover(t.cover)}</div><div class="card-title">${e(t.name)}</div><div class="card-subtitle">${e(t.artist)}</div>`,()=>play(queue,i),'card song',t.name)).join('')}</div></section>`;
}
// 服务端没下发的板块，用本地拿得到的数据补齐九个（与 iOS 侧同一套规则）。
async function homeFallbacks(sections,values,signedIn,uid){
  const present=new Set(sections.map(s=>s.slot));
  const needs=slot=>!present.has(slot);
  const optional=(key,path,payload)=>cached(key,()=>api(path,payload)).catch(()=>null);
  const [hot,tailored,mine,radar,fm]=await Promise.all([
    needs('recentlyTrending')||needs('regionalHits')
      ?optional('home-hot','/v6/playlist/detail',{id:3778678,n:1000,s:0}):null,
    needs('tailoredRecommendation')?optional('home-tailored','/personalized/newsong',{type:'recommend',limit:12,areaId:0}):null,
    uid&&(needs('personalPlaylists')||needs('likedSongRecommendations'))
      ?optional('home-mine-'+uid,'/user/playlist',{uid,limit:200,offset:0}):null,
    needs('radarPlaylists')?Promise.all([3136952023,2829883282,2829816518,2829896389]
      .map(id=>optional('home-radar-'+id,'/v6/playlist/detail',{id,n:1,s:0}))):[],
    signedIn&&needs('likedSongRoaming')?optional('home-fm','/v1/radio/get',{}):null
  ]);
  const extra=[];
  const add=(slot,payload)=>{
    if(needs(slot)&&(payload.playlists||payload.songs).length)extra.push({slot,title:HOME_SLOT_TITLES[slot],...payload});
  };
  add('recommendedPlaylists',{playlists:(values[0]?.result||values[0]?.recommend||[]).slice(0,12)});
  const hotSongs=uniqueTracks(hot?.playlist?.tracks||[]);
  add('recentlyTrending',{songs:hotSongs.slice(0,12)});
  add('regionalHits',{songs:hotSongs.slice(12,24)});
  add('tailoredRecommendation',{songs:uniqueTracks((tailored?.result||[]).map(x=>x?.song).filter(Boolean))});
  add('charts',{playlists:(values[1]?.list||[]).filter(x=>[19723756,3779629,2884035,3778678,60198].includes(x.id)).slice(0,12)});
  add('personalPlaylists',{playlists:(mine?.playlist||[]).filter(p=>Number(p.creator?.userId)===uid&&!p.subscribed).slice(0,12)});
  add('radarPlaylists',{playlists:radar.map(x=>x?.playlist).filter(Boolean)});
  add('likedSongRoaming',{songs:uniqueTracks((fm?.data||[]).map(x=>x?.song||x).filter(Boolean)).slice(0,12)});
  const likedPlaylist=(mine?.playlist||[]).find(p=>p.specialType===5);
  if(uid&&likedPlaylist&&needs('likedSongRecommendations')){
    const liked=await optional('home-liked-'+uid,'/song/like/get',{uid});
    const seed=liked?.ids?.[0];
    if(seed){
      const sim=await optional('home-sim-'+uid+'-'+seed,'/playmode/intelligence/list',
        {songId:seed,playlistId:likedPlaylist.id,startMusicId:seed,count:12,type:'fromPlayOne',modifyStamp:0});
      add('likedSongRecommendations',{songs:uniqueTracks((sim?.data||[]).map(x=>x?.songInfo).filter(Boolean)).slice(0,12)});
    }
  }
  return extra;
}
function homeSectionHTML(section){
  if(section.songs)return songShelf(section.title,section.songs);
  return shelf(section.title,section.playlists.slice(0,12));
}
function shelf(title,items,kind='playlist',action=null){if(!items.length)return '';return `<section class="section"><div class="section-head"><h2>${e(title)}</h2>${action?button('查看全部 '+icon('chevron'),action):''}</div><div class="shelf">${items.map(x=>card(x,kind)).join('')}</div></section>`;}
async function cached(key,loader){
  if(cache.has(key))return cache.get(key);
  const session=sessionGeneration,value=await loader();
  if(session===sessionGeneration&&value!=null)cache.set(key,value);
  return value;
}
function fmPage(){return header('漫游')+(!loggedIn?`<div class="fm-empty">${loginPrompt('登录后开启私人漫游','根据你的口味，发现下一首好音乐','fm')}</div>`:`<div class="fm-content${player.fm?'':' fm-idle'}">${cover(player.fm?player.queue[player.index]?.cover:'','fm-cover')}<div class="stack"><h2>${e(player.fm?player.queue[player.index]?.name:'私人漫游')}</h2><p class="secondary">${e(player.fm?player.queue[player.index]?.artist:'根据你的口味漫游好音乐')}</p></div>${player.fm?`<div class="fm-controls">${round('trash',fmTrash,'不喜欢，换一首')}${button(icon(player.playing?'pause':'play'),()=>control('toggle'),'play-main','播放或暂停')}${round('next',async()=>{if(player.index>=player.queue.length-1)await startFM();else control('next');},'下一首')}${round('heart',()=>likeTrack(player.queue[player.index]),'喜欢','accent')}</div>`:button(icon('fm')+' 开始漫游',startFM,'primary pill')}${player.fm?'<div class="fm-lyrics" id="fm-lyrics"></div>':''}</div>`);}
async function startFM(){
  if(!accountOwner()){openLogin();return;}
  const intent=++playbackIntent,session=sessionGeneration;
  try{
    const r=await api('/v1/radio/get');
    if(intent!==playbackIntent||session!==sessionGeneration)return;
    if(!await play(r.data||[],0,intent,{fm:true}))return;
    if(route.kind==='fm')render();
    fmRefill();
  }catch(err){if(intent===playbackIntent&&session===sessionGeneration)errorToast(err);}
}
let fmRefillIntent=null;
async function fmRefill(){
  const intent=playbackIntent,session=sessionGeneration;
  if(!player.fm||!accountOwner()||fmRefillIntent===intent)return;
  fmRefillIntent=intent;
  try{
    const r=await api('/v1/radio/get');
    if(intent!==playbackIntent||session!==sessionGeneration||!player.fm)return;
    const have=new Set(player.queue.map(t=>t?.id));
    const extra=uniqueTracks(r?.data||[]).filter(t=>!have.has(t.id));
    if(!extra.length)return;
    const queue=[...player.queue,...extra];
    await native('control',{action:'replaceQueue',queue,index:player.index});
  }catch{}finally{if(fmRefillIntent===intent)fmRefillIntent=null;}
}
async function fmTrash(){
  const t=player.queue[player.index];if(!t)return;
  const intent=++playbackIntent,session=sessionGeneration;
  await api('/radio/trash/add',{alg:'RT',songId:String(t.id),time:'25'});
  if(intent!==playbackIntent||session!==sessionGeneration||!player.fm)return;
  if(player.index>=player.queue.length-1)await startFM();else control('next');
}

async function homePage(ticket,session){
  const signedIn=loggedIn,uid=accountOwner();
  const optional=(key,path,payload)=>cached(key,()=>api(path,payload)).catch(()=>null);
  const extras=Promise.all([
    optional('home-new-albums','/album/new',{area:'ALL',limit:20,offset:0,total:true}),
    optional('home-artists','/toplist/artist',{type:1,offset:0,limit:20})
  ]);
  const blocks=await optional('home-blocks','/homepage/block/page',{refresh:false,cursor:''});
  if(ticket!==renderID||session!==sessionGeneration)return '';
  const primary=homeSections(blocks?.data);
  if(primary.length){
    const page=$('#page');
    page.innerHTML=homeHTML(primary,[],signedIn);
    page.classList.toggle('has-track',!!player.queue[player.index]);
  }
  const missing=slot=>!primary.some(s=>s.slot===slot);
  const values=await Promise.all([
    missing('recommendedPlaylists')?optional('home-rec',signedIn?'/v1/discovery/recommend/resource':'/personalized/playlist',{limit:30}):null,
    missing('charts')?optional('home-charts','/toplist'):null
  ]);
  if(ticket!==renderID||session!==sessionGeneration)return '';
  const [extra,[albums,artists]]=await Promise.all([homeFallbacks(primary,values,signedIn,uid),extras]);
  const sections=[...primary,...extra].sort((a,b)=>HOME_SLOTS.indexOf(a.slot)-HOME_SLOTS.indexOf(b.slot));
  if(!sections.length&&!albums&&!artists)throw new Error('网络连接失败');
  return homeHTML(sections,[...values,albums,artists],signedIn);
}
function homeHTML(sections,values,signedIn){
  let html=header('推荐',round('search',()=>switchTab('search'),'搜索','search-button glass'));
  let left=signedIn?`<section class="section"><div class="shelf feature-shelf">${[['每日推荐','每天 30 首，发现好音乐','calendar',()=>navigate({kind:'daily'})],['私人漫游','根据你的口味漫游好音乐','fm',()=>switchTab('fm')],['心动模式','从喜欢的歌开始','heart',startHeart]].map(([title,sub,name,fn])=>button(`${icon(name)}<strong>${title}</strong><small>${sub}</small>`,fn,'feature')).join('')}</div></section>`:'';
  let right='';
  if(sections.length){
    // 竖屏单列：按板块顺序直接排（CSS 下 .home-cols/.home-col 是 display:contents，
    // DOM 顺序就是视觉顺序）；横屏两栏时才按序号分到左右，与 iOS 侧一致。
    const wide=window.matchMedia('(min-aspect-ratio: 1/1)').matches&&window.innerWidth>=540;
    if(wide){
      left+=sections.filter((_,i)=>i%2===0).map(homeSectionHTML).join('');
      right+=sections.filter((_,i)=>i%2===1).map(homeSectionHTML).join('');
    }else{
      left+=sections.map(homeSectionHTML).join('');
    }
  }
  // 新碟上架 / 推荐歌手：不在参考实现的九板块里，本项目保留，固定在九板块之后。
  right+=shelf('新碟上架',values[2]?.albums||[],'album');
  right+=shelf('推荐歌手',(values[3]?.list?.artists||values[3]?.artists||[]).slice(0,6),'artist');
  if(!signedIn)left+='<p class="home-login-hint">部分功能需登录后完全显示。</p>';
  html+=`<div class="home-cols"><div class="home-col">${left}</div><div class="home-col">${right}</div></div>`;
  return html;
}
async function explorePage(append=false){
  const selected=category;
  const key='explore-'+selected;
  let r=append?null:cache.get(key);
  if(!r){
    let path='/playlist/list',payload={cat:selected,order:'hot',limit:50,offset:append?exploreOffset:0,total:true};
    if(selected==='排行榜'){path='/toplist';payload={};}
    if(selected==='推荐歌单'){path='/personalized/playlist';payload={limit:100};}
    if(selected==='精品歌单'){path='/playlist/highquality/list';payload={cat:'全部',limit:50,lasttime:append?exploreOffset:0};}
    r=await api(path,payload);if(!append)cache.set(key,r);
  }
  if(selected!==category)return '';
  const incoming=r.playlists||r.result||r.list||[];
  exploreItems=append?[...exploreItems,...incoming.filter(x=>!exploreItems.some(p=>p.id===x.id))]:incoming;
  exploreOffset=selected==='精品歌单'?(r.lasttime||0):exploreItems.length;
  exploreMore=!!r.more&&selected!=='推荐歌单'&&selected!=='排行榜';
  return header('精选')+`<div class="chips" role="tablist">${categories.map(c=>button(e(c),()=>{category=c;render();},`chip ${selected===c?'active':''}`,c)).join('')}</div><div class="grid">${exploreItems.map(x=>card(x)).join('')}</div>`+(exploreMore?button('加载更多',async()=>{try{const html=await explorePage(true);if(route.kind==='explore'){const y=$('#page').scrollTop;$('#page').innerHTML=html;$('#page').scrollTop=y;}}catch(err){errorToast(err);}},'load-more'):'');
}
function trackRow(t,i,items,numbered=false,queue=false){
  const current=t.id===player.queue[player.index]?.id;
  return `<div class="track-row ${current?'current':''}" data-track-id="${t.id}">${button(`${numbered?`<span class="track-number">${current?icon('music'):i+1}</span>`:cover(t.cover,'track-cover')}<span class="track-info"><strong>${e(t.name)}</strong><small>${t.fee===1?'<span class="vip">VIP</span>':''}${e(t.artist)}${t.album?.name?' · '+e(t.album.name):''}${t.bytes?' · '+sizeText(t.bytes):''}</small></span>`,()=>queue?play(player.queue,i):play(items,i),'track-main',`播放 ${t.name}`)}${round('more',()=>trackMenu(t,i),'歌曲菜单')}</div>`;
}
function tracksHTML(items,numbered=false){if(!items.length)return empty('暂无歌曲');return `<div class="track-list">${items.map((t,i)=>trackRow(t,i,items,numbered)).join('')}</div>`;}
function playlistTrackRow(t,i,items){
  const current=t.id===player.queue[player.index]?.id;
  const main=`${cover(t.cover,'playlist-track-cover')}<span class="playlist-track-info"><span class="playlist-track-title">${e(t.name)}${t.fee===1?'<span class="playlist-vip">VIP</span>':''}</span><small>${downloaded.has(String(t.id))?`<span class="playlist-dl" aria-label="已下载">${icon('downloadFill')}</span>`:''}${e(t.artist)}</small></span>`;
  const on=picked.has(String(t.id));
  const pick=selecting?button(on?icon('tick'):'',()=>{const id=String(t.id);on?picked.delete(id):picked.add(id);render();},`pick${on?' on':''}`,on?'取消选择':'选择'):'';
  return `<div class="track-row playlist-track ${current?'current':''}${selecting?' selecting':''}${picked.has(String(t.id))?' picked':''}" data-track-id="${t.id}" data-search="${e((t.name+' '+t.artist+' '+(t.album?.name||'')).toLowerCase())}">${pick}${button(main,()=>{if(selecting){const id=String(t.id);picked.has(id)?picked.delete(id):picked.add(id);render();return;}play(items,i);},'playlist-track-main',`播放 ${t.name}`)}${liked.has(t.id)?button(icon('heart','fill-icon'),()=>likeTrack(t),'playlist-heart','取消喜欢'):'<span class="playlist-heart-space"></span>'}<span class="playlist-duration">${t.duration?time(t.duration):'···'}</span>${button(icon('moreVert'),()=>trackMenu(t,i),'playlist-more',`${t.name} 歌曲菜单`)}</div>`;
}
function selectBar(items){
  const pickedTracks=items.filter(t=>picked.has(String(t.id)));
  return `<div class="select-bar glass"><span class="select-count">已选 ${picked.size}</span>${button('全选',()=>{if(picked.size===items.length)picked.clear();else items.forEach(t=>picked.add(String(t.id)));render();},'select-act')}${button(icon('downloadArrow'),()=>{if(!pickedTracks.length){toast('先选几首');return;}downloadAll(pickedTracks);},'select-act','下载所选')}${button(icon('heart'),()=>{if(!loggedIn){openLogin();return;}if(!pickedTracks.length){toast('先选几首');return;}pickedTracks.reduce((p,t)=>p.then(()=>liked.has(t.id)?t:likeTrack(t)),Promise.resolve()).then(()=>render());},'select-act','收藏所选')}${button(icon('plus'),()=>newPlaylist(),'select-act','新建播放列表')}${button(icon('plusList'),()=>addPickedToPlaylist(pickedTracks),'select-act','添加到歌单')}${button('完成',()=>{selecting=false;picked.clear();render();},'select-act primary')}</div>`;
}
function playlistLocateButton(items){
  const t=player.queue[player.index];
  return t&&items.some(item=>item.id===t.id)?round('locate',locateCurrentTrack,'定位当前歌曲','playlist-action accent playlist-locate'):'';
}
function locateCurrentTrack(){
  const t=player.queue[player.index];if(!t||!listTracks.some(item=>item.id===t.id))return;
  const input=$('#playlist-search input');if(input){input.value='';input.blur();filterPlaylist('');$('#playlist-search').classList.add('hidden');}
  $(`.playlist-track[data-track-id="${t.id}"]`)?.scrollIntoView({block:'center',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
}
function updatePlaylistLocator(){
  const actions=$('.playlist-actions');if(!actions)return;
  const current=actions.querySelector('.playlist-locate'),t=player.queue[player.index];
  if(t&&listTracks.some(item=>item.id===t.id)){if(!current)actions.insertAdjacentHTML('beforeend',playlistLocateButton(listTracks));}
  else current?.remove();
}
function playlistDetails(info,items){
  const creator=info.creator?.nickname||'歌单';
  const avatar=info.creator?.avatarUrl?cover(info.creator.avatarUrl,'playlist-creator-avatar'):`<span class="playlist-creator-avatar placeholder">${icon('user')}</span>`;
  const description=info.description?.trim();
  return `<div class="playlist-nav">${round('back',back,'返回','playlist-nav-button glass')}<strong class="playlist-nav-title">${e(info.name)}</strong>${round('search',()=>{const box=$('#playlist-search');box.classList.toggle('hidden');if(!box.classList.contains('hidden'))box.querySelector('input').focus();else{box.querySelector('input').value='';filterPlaylist('');}},'歌单内搜索','playlist-nav-button glass accent')}</div><h1 class="sr-only">歌单</h1><div id="playlist-search" class="playlist-search hidden">${icon('search')}<input type="search" placeholder="搜索歌单内歌曲" aria-label="搜索歌单内歌曲"></div><div class="playlist-cols"><div class="playlist-col"><div class="playlist-summary">${cover(info.coverImgUrl,'playlist-cover')}<div class="playlist-summary-info"><h2>${e(info.name)}</h2><div class="playlist-creator">${avatar}<span>${e(creator)}</span></div><p>${info.trackCount||items.length} 首 · ${count(info.playCount)} 次播放</p></div></div>${description?button(`${e(description)} ${icon('chevron')}`,()=>showOverlay('playlistDescription',`<div class="pad playlist-description-full">${e(description).replaceAll('\n','<br>')}</div>`,{title:'歌单简介'}),'playlist-description','查看歌单简介'):''}<div class="playlist-actions">${button(icon('play')+`播放全部 (${items.length})`,()=>play(items),'playlist-play')}${round('select',()=>{selecting=!selecting;picked.clear();render();},'选择歌曲',`playlist-action${selecting?' on':''}`)}${round('downloadArrow',()=>downloadAll(items),'下载全部','playlist-action accent')}${round(info.subscribed?'starFill':'starOutline',async()=>{if(!loggedIn){openLogin();return;}await subscribe('playlist',info.id,!info.subscribed);cache.delete('playlist-'+info.id);render();},info.subscribed?'取消收藏歌单':'收藏歌单',`playlist-action star-action${info.subscribed?' on':''}`)}${playlistLocateButton(items)}</div></div><div class="playlist-col">${items.length?`<div class="playlist-tracks">${items.map((t,i)=>playlistTrackRow(t,i,items)).join('')}</div>`:empty('暂无歌曲')}</div></div>`;
}
function filterPlaylist(query){
  const term=query.trim().toLowerCase();
  document.querySelectorAll('.playlist-track').forEach(row=>{row.hidden=!!term&&!row.dataset.search.includes(term);});
}
function setupPlaylistSearch(){
  const input=$('#playlist-search input');if(input)input.addEventListener('input',()=>filterPlaylist(input.value));
}
function songPageTools(){return `<div class="detail-tools">${button(icon('play')+' 播放全部',()=>play(listTracks),'accent')}<span>${listTracks.length} 首</span></div>`;}
async function loadPlaylist(id,previous){
  const data=await api('/v6/playlist/detail',{id,n:100000,s:8});
  const info=data.playlist;if(!info)throw new Error('内容暂不可用');
  let songs=info.tracks||[];const preview=songs;const ids=(info.trackIds||[]).map(x=>x.id);
  if(ids.length>songs.length){songs=[];for(let i=0;i<ids.length;i+=400){const details=await api('/v3/song/detail',{c:JSON.stringify(ids.slice(i,i+400).map(id=>({id})))});songs.push(...details.songs);}}
  songs=preserveTrackCovers(preserveTrackCovers(songs,preview),previous?.playlist?.tracks||[]);
  return {...data,playlist:{...info,tracks:songs}};
}
async function playlistPage(ticket){
  const id=route.id,key='playlist-'+id,snapshot=cache.get(key);
  const session=sessionGeneration,current=()=>ticket===renderID&&session===sessionGeneration;
  const show=async data=>{
    const info=data.playlist,tracks=uniqueTracks(info.tracks||[]);
    if(tracks.some(t=>t.cover))await preloadCoversAsync(tracks,18);
    if(!current())return;
    detail={...info,kind:'playlist'};listTracks=tracks;updatePlaylistPage(info,tracks);
  };
  if(!snapshot)loading('歌单',true);
  const showing=snapshot?show(snapshot):null;
  try{
    const fresh=await loadPlaylist(id,snapshot);
    await showing;
    if(!current()||cache.get(key)!==snapshot)return;
    cache.set(key,fresh);
    if(!snapshot||JSON.stringify(snapshot)!==JSON.stringify(fresh))await show(fresh);
  }catch(err){if(!snapshot)throw err;}
}
function updatePlaylistPage(info,items){
  const page=$('#page'),scroll=page.scrollTop,input=$('#playlist-search input');
  const searchOpen=!!input&&!input.closest('#playlist-search').classList.contains('hidden'),query=input?.value||'',focused=document.activeElement===input;
  const next=document.createElement('template');next.innerHTML=playlistDetails(info,items);
  // Reuse decoded images so a silent refresh never blanks unchanged artwork.
  const images=new Map();for(const img of page.querySelectorAll('img')){const key=img.className+'|'+img.getAttribute('src');if(!images.has(key))images.set(key,[]);images.get(key).push(img);}
  for(const img of next.content.querySelectorAll('img')){const old=images.get(img.className+'|'+img.getAttribute('src'))?.shift();if(old)img.replaceWith(old);}
  page.replaceChildren(next.content);page.classList.toggle('has-track',!!player.queue[player.index]);setupPlaylistSearch();
  const search=$('#playlist-search input');if(search&&searchOpen){search.closest('#playlist-search').classList.remove('hidden');search.value=query;filterPlaylist(query);if(focused)search.focus({preventScroll:true});}
  page.scrollTop=scroll;
}
// 专辑/歌手页横屏：和歌单页同一套两栏（左信息 / 右列表），两栏各自滚动。
function detailCols(left,right){return `<div class="detail-cols"><div class="detail-col">${left}</div><div class="detail-col">${right}</div></div>`;}
async function detailPage(){
  const r={...route};
  if(!r.id)return empty('内容不存在','缺少 id，无法打开','music');
  const key=r.kind+'-'+r.id;
  let data=await cached(key,()=>api(r.kind==='album'?'/v1/album/'+r.id:'/v1/artist/'+r.id));
  let info,songs;
  if(r.kind==='album'){info=data.album;songs=data.songs||[];}
  else{info=data.artist;songs=data.hotSongs||[];}
  if(!info)throw new Error('内容暂不可用');
  detail={...info,kind:r.kind};listTracks=uniqueTracks(songs);
  const author=r.kind==='album'?info.artist?.name:(info.alias||[]).join(' / ');
  let html=header(r.kind==='album'?'专辑':'歌手',round('more',()=>detailMenu(),'更多选项'));
  setTimeout(()=>preloadCovers(listTracks),0);
  let left=`<div class="detail-hero">${cover(info.coverImgUrl||info.picUrl,'detail-cover')}<h2>${e(info.name)}</h2>${author?`<p class="secondary">${e(author)}</p>`:''}${info.description?`<p class="description">${e(info.description)}</p>`:''}<div class="detail-actions">${button(icon('play')+' 播放',()=>play(listTracks),'primary')}${button(icon('shuffle')+' 随机播放',()=>{player.mode='shuffle';play(listTracks,Math.floor(Math.random()*Math.max(listTracks.length,1)));},'muted-button')}</div></div>`;
  if(r.kind==='artist')left+=`<div class="chips">${button('热门歌曲',()=>{route.section='songs';render();},`chip ${r.section!=='albums'?'active':''}`)}${button('专辑',()=>{route.section='albums';render();},`chip ${r.section==='albums'?'active':''}`)}${button('关注歌手',()=>subscribe('artist',r.id,true),'chip')}</div>`;
  if(r.kind==='artist'&&r.section==='albums'&&r.id){const albums=await api('/artist/albums/'+r.id,{limit:100,offset:0,total:true});return html+detailCols(left,`<div class="grid">${(albums.hotAlbums||[]).map(x=>card(x,'album')).join('')}</div>`);}
  left+=`<div class="detail-tools"><span>${listTracks.length} 首歌曲</span>${button(icon('download')+' 下载全部',()=>downloadAll(listTracks),'accent')}</div>`;
  return html+detailCols(left,tracksHTML(listTracks,true));
}
function listRow(label,name,fn,extra='',rowClass=''){return button(`${icon(name)}<span>${e(label)}</span>${extra}${icon('chevron','chevron')}`,fn,('list-row '+rowClass).trim(),label);}
async function loadAccount(){
  if(!loggedIn){account=null;playlists=[];liked.clear();return;}
  const session=sessionGeneration;
  const data=await api('/nuser/account/get');
  if(session!==sessionGeneration)return;
  account=data.profile;
  if(!account){loggedIn=false;return;}
  if(account.avatarUrl&&account.avatarUrl!==prefs.avatarUrl){prefs.avatarUrl=account.avatarUrl;savePrefs();}
  const results=await Promise.allSettled([api('/user/playlist',{uid:account.userId,limit:2000,offset:0,includeVideo:true}),api('/song/like/get',{uid:account.userId})]);
  if(session!==sessionGeneration)return;
  if(results[0].status==='fulfilled')playlists=results[0].value.playlist||[];
  if(results[1].status==='fulfilled')liked=new Set(results[1].value.ids||[]);
}
// “我的音乐”那一组：顺序与开关与设置里的“我的音乐板块”共用同一批 prefs 键
const LIBRARY_ROWS=[['liked','我喜欢的音乐','heartFill','libLiked','accent-row'],['daily','每日推荐','calendarFill','libDaily',''],['recents','最近播放','clockFill','libRecents',''],['rank','听歌排行','eq','libRank',''],['collections','我的收藏','starFill','libCollections',''],['downloads','我的下载','downloadFill','libDownloads',''],['cloud','音乐云盘','cloudFill','libCloud','']];
function libraryOrderedRows(){
  const order=(Array.isArray(prefs.libraryOrder)&&prefs.libraryOrder.length)?prefs.libraryOrder:LIBRARY_ROWS.map(r=>r[0]);
  const rank=k=>{const i=order.indexOf(k);return i<0?order.length+1:i;};
  return [...LIBRARY_ROWS].sort((a,b)=>rank(a[0])-rank(b[0])).filter(r=>prefs[r[3]]!==false);
}
async function libraryPage(){
  if(loggedIn&&!account)await loadAccount();
  const searchButton=prefs.librarySearch!==false?round('search',openSearchFromLibrary,'搜索音乐'):'';
  // 私信入口排在搜索左边，和 iOS 端顶栏两个按钮的顺序一致。
  const messageButton=round('chat',()=>navigate({kind:'messages'}),'私信');
  let html=header('我的',messageButton+searchButton+round('gear',()=>openSettings(),'设置'));
  const profile=`<div class="group">${loggedIn&&account?`<div class="list-row profile-row">${account.avatarUrl?cover(account.avatarUrl,'avatar'):`<span class="avatar">${icon('user')}</span>`}<span><strong>${e(account.nickname)}</strong><small>${e(account.signature||'Antunes，随心而听')}</small></span></div>`:button(`<span class="avatar">${icon('user')}</span><span><strong>登录</strong><small>同步我喜欢的音乐、歌单与每日推荐</small></span>${icon('chevron','chevron')}`,()=>openLogin(),'list-row profile-row')}</div>`;
  if(!loggedIn)return html+profile;
  const likedPlaylist=playlists.find(x=>x.specialType===5)||playlists.find(x=>x.creator?.userId===account?.userId);
  const own=playlists.filter(x=>x.creator?.userId===account?.userId&&(prefs.showLikedInCreated===true||x.specialType!==5)),sub=playlists.filter(x=>x.creator?.userId!==account?.userId);
  setTimeout(()=>preloadCovers(own.concat(sub),32),0);
  const musicRows=libraryOrderedRows().map(([id,label,ic,,extra])=>listRow(label,ic,()=>{if(id==='liked'){if(likedPlaylist)navigate({kind:'playlist',id:likedPlaylist.id});else toast('暂无喜欢的音乐');}else navigate({kind:id});},'',extra)).join('');
  let left=profile,right='';
  if(musicRows)left+=`<div class="group-label">我的音乐</div><div class="group">${musicRows}</div>`;
  function playlistRows(items){return items.map(x=>button(`${cover(x.coverImgUrl,'playlist-thumb')}<span class="list-label"><strong>${e(x.name)}</strong><small>${x.trackCount||0} 首</small></span>${icon('chevron','chevron')}`,()=>navigate({kind:'playlist',id:x.id}),'list-row')).join('');}
  if(prefs.libCreatedLists!==false)right+=`<div class="group-label row spread"><span>创建的歌单</span>${button(icon('plus'),newPlaylist,'accent','新建歌单')}</div><div class="group">${playlistRows(own)}</div>`;
  if(sub.length&&prefs.libCollectedLists!==false)right+=`<div class="group-label">收藏的歌单</div><div class="group">${playlistRows(sub)}</div>`;
  // 横屏时这两栏各占一边并各自滚动；竖屏靠 CSS 的 display:contents 还原成一列。
  return html+`<div class="library-cols"><div class="library-col">${left}</div><div class="library-col">${right}</div></div>`;
}

// 听歌排行：/v1/play/record；type=1 最近一周，type=0 所有时间。
// 数据形状与备用源码一致：{weekData:[{song,playCount}],allData:[...]}。
async function rankPage(){
  if(!loggedIn)return header('听歌排行')+loginPrompt();
  const uid=accountOwner();
  if(!uid)return header('听歌排行')+empty('账号资料尚未就绪','请稍后重试','eq',button('重试',render,'pill'));
  const week=route.period!=='all';
  const landscape=window.matchMedia('(min-aspect-ratio: 1/1)').matches&&innerWidth>=540;
  const recordsFor=(rows0)=>{
    const rows=(rows0||[]).filter(x=>x&&x.song);
    if(!rows.length)return empty('还没有听歌记录','听过的歌会按播放次数排在这里。','eq');
    const items=uniqueTracks(rows.map(x=>x.song));
    return `<div class="track-list">${rows.map((x,i)=>{
      const t=track(x.song),current=t.id===player.queue[player.index]?.id;
      const times=x.playCount||0;
      return `<div class="track-row ${current?'current':''}" data-track-id="${t.id}">${button(`<span class="track-number">${i+1}</span><span class="track-info"><strong>${e(t.name)}</strong><small>${e(t.artist)} · 播放 ${times} 次</small></span>`,()=>play(items,i),'track-main',`播放 ${t.name}`)}</div>`;
    }).join('')}</div>`;
  };
  if(landscape){
    // 横屏：两档并排，两个按钮各占一列宽度，列的边界就是按钮的中缝。
    const [w,a]=await Promise.all([
      api('/v1/play/record',{uid,type:1}).catch(()=>null),
      api('/v1/play/record',{uid,type:0}).catch(()=>null)
    ]);
    const col=(title,result,rows0,active)=>`<div class="rank-col">${button(title,()=>{route.period=active?'week':'all';render();},`chip rank-head ${active?'active':''}`)}${result?recordsFor(rows0):empty('排行加载失败','请稍后重试','eq')}</div>`;
    return header('听歌排行')+`<div class="rank-cols">${col('最近一周',w,w?.weekData,true)}${col('所有时间',a,a?.allData,false)}</div>`;
  }
  const r=await api('/v1/play/record',{uid,type:week?1:0});
  const rows=((week?r.weekData:r.allData)||[]).filter(x=>x&&x.song);
  const chips=`<div class="chips">${button('最近一周',()=>{route.period='week';render();},`chip ${week?'active':''}`)}${button('所有时间',()=>{route.period='all';render();},`chip ${!week?'active':''}`)}</div>`;
  if(!rows.length)return header('听歌排行')+chips+empty('还没有听歌记录','听过的歌会按播放次数排在这里。','eq');
  const items=uniqueTracks(rows.map(x=>x.song));
  const list=rows.map((x,i)=>{
    const t=track(x.song),current=t.id===player.queue[player.index]?.id;
    const times=x.playCount||0;
    return `<div class="track-row ${current?'current':''}" data-track-id="${t.id}">${button(`<span class="track-number">${i+1}</span><span class="track-info"><strong>${e(t.name)}</strong><small>${e(t.artist)} · 播放 ${times} 次</small></span>`,()=>play(items,i),'track-main',`播放 ${t.name}`)}</div>`;
  }).join('');
  return header('听歌排行')+chips+`<div class="track-list">${list}</div>`;
}

// 私信内容：服务端把消息体存成 JSON 字符串（{msg,song,playlist,album}），
// 解析失败时按纯文本处理。
function decodeMsg(raw){
  if(!raw)return '';
  try{
    const wire=JSON.parse(raw);
    const text=(wire.msg||'').trim();
    if(text)return text;
    if(wire.song)return '[歌曲] '+wire.song.name;
    if(wire.playlist)return '[歌单] '+wire.playlist.name;
    if(wire.album)return '[专辑] '+wire.album.name;
    return '[消息]';
  }catch(err){return String(raw);}
}
function msgTime(ms){
  const d=new Date(Number(ms)||0),now=new Date();
  const sameDay=d.toDateString()===now.toDateString();
  const pad=n=>String(n).padStart(2,'0');
  return sameDay?`${pad(d.getHours())}:${pad(d.getMinutes())}`:`${d.getMonth()+1}/${d.getDate()}`;
}
function contactOf(c,me){
  const from=c.fromUser||{},to=c.toUser||{},mine=x=>Number(x.userId||x.id||0)===Number(me);
  if(from.userId||from.id)return mine(from)?(to.userId||to.id?to:from):from;
  return to;
}
async function messagesPage(){
  if(!loggedIn)return header('私信')+loginPrompt();
  const me=accountOwner(),session=sessionGeneration;
  if(!me)return header('私信')+empty('账号资料尚未就绪','请稍后重试','chat',button('重试',render,'pill'));
  const r=await api('/msg/private/users',{offset:0,limit:50,total:true});
  if(me!==accountOwner()||session!==sessionGeneration)return '';
  const list=(r.msgs||[]).filter(c=>c);
  if(!list.length)return header('私信')+empty('还没有私信','和好友在网易云里聊过天后，会话会出现在这里。','chat');
  const rows=list.map(c=>{
    const other=contactOf(c,me)||{};
    const name=other.remarkName||other.nickname||'网易云用户';
    const id=Number(other.userId||other.id||0);
    const unread=Number(c.newMsgCount||0);
    const avatar=other.avatarUrl?cover(other.avatarUrl,'avatar'):`<span class="avatar">${icon('user')}</span>`;
    if(!Number.isSafeInteger(id)||id<=0)return '';
    return button(`${avatar}<span class="list-label"><strong>${e(name)}</strong><small>${e(decodeMsg(c.lastMsg))}</small></span>${unread?`<span class="badge">${unread}</span>`:icon('chevron','chevron')}`,()=>{if(me===accountOwner()&&session===sessionGeneration)navigate({kind:'chat',userId:id,name,owner:me,session});},'list-row');
  }).join('');
  return header('私信')+`<div class="group">${rows}</div>`;
}
const validChat=chat=>chat.kind==='chat'&&chat.session===sessionGeneration&&
  chat.owner!=null&&chat.owner===accountOwner()&&Number.isSafeInteger(chat.userId)&&chat.userId>0;
const sendingChat=new WeakSet();
async function chatHistoryHTML(chat){
  const r=await api('/msg/private/history',{userId:chat.userId,limit:100,time:-1,total:true});
  const msgs=(r.msgs||[]).filter(Boolean).sort((a,b)=>Number(a.time||0)-Number(b.time||0));
  return msgs.map(m=>{
    const out=Number(m.fromUser?.userId||0)===chat.owner;
    return `<div class="bubble-row ${out?'out':'in'}"><div class="bubble">${e(decodeMsg(m.msg))}</div><span class="bubble-time">${msgTime(m.time)}</span></div>`;
  }).join('')||empty('还没有聊天记录','发第一条消息试试。','chat');
}
async function chatPage(){
  const chat=route;
  if(!validChat(chat))return header('私信')+empty('账号已变更，请返回私信列表','','chat');
  const body=await chatHistoryHTML(chat);
  if(route!==chat||!validChat(chat))return '';
  return header(chat.name||'私信')
    +`<div class="chat">${body}</div>`
    +`<form class="chat-composer" id="chat-form"><input id="chat-input" class="search-input" type="text" autocomplete="off" placeholder="发消息…" aria-label="消息内容"><button class="accent pill" type="button" ${bind(()=>sendChat(chat))}>发送</button></form>`;
}
function scrollChatToLatest(page){
  const messages=page.querySelector('.chat');
  if(messages)messages.scrollTop=messages.scrollHeight;
}
async function sendChat(chat){
  const input=$('#chat-input');
  if(!input||route!==chat||!validChat(chat)||sendingChat.has(input))return;
  const draft=input.value,text=draft.trim();
  if(!text)return;
  const visible=()=>route===chat&&validChat(chat)&&$('#chat-input')===input;
  sendingChat.add(input);
  try{
    await api('/msg/private/send',{type:'text',msg:text,userIds:`[${chat.userId}]`});
    if(!visible())return;
    if(input.value===draft)input.value='';
    try{
      const body=await chatHistoryHTML(chat);
      if(visible()){
        $('.chat').innerHTML=body;
        scrollChatToLatest($('#page'));
      }
    }catch{if(visible())toast('消息已发送，聊天记录刷新失败');}
  }catch(err){if(visible())errorToast(err);}
  finally{sendingChat.delete(input);}
}
async function startHeart(){
  const uid=accountOwner();if(!uid){openLogin();return;}
  const intent=++playbackIntent,session=sessionGeneration;
  const current=()=>intent===playbackIntent&&uid===accountOwner()&&session===sessionGeneration;
  const p=playlists.find(x=>x.specialType===5)||playlists.find(x=>x.creator?.userId===uid);
  if(!p){toast('请先收藏一些音乐');return;}
  try{
    const d=await api('/v6/playlist/detail',{id:p.id,n:1,s:0});
    if(!current())return;
    const id=d.playlist.trackIds?.[0]?.id;
    if(!id){toast('请先收藏一些音乐');return;}
    const r=await api('/playmode/intelligence/list',{songId:id,playlistId:p.id,startMusicId:id,count:50,type:'fromPlayOne',modifyStamp:0});
    if(!current())return;
    if(await play((r.data||[]).map(x=>x.songInfo),0,intent)&&current())openNowPlaying();
  }catch(err){if(current())errorToast(err);}
}
async function collectionsPage(){if(!loggedIn)return header('我的收藏')+loginPrompt();const type=route.section||'albums';const r=await api(type==='albums'?'/album/sublist':'/artist/sublist',{limit:500,offset:0,total:true});return header('我的收藏')+`<div class="chips">${button('专辑',()=>{route.section='albums';render();},`chip ${type==='albums'?'active':''}`)}${button('歌手',()=>{route.section='artists';render();},`chip ${type==='artists'?'active':''}`)}</div>`+((r.data||[]).length?`<div class="grid">${r.data.map(x=>card(x,type==='albums'?'album':'artist')).join('')}</div>`:empty(type==='albums'?'还没有收藏专辑':'还没有关注歌手'));}
function searchPage(){
  const q=searchQuery.trim();
  return header(q?'搜索：'+q:'搜索',round('close',closeSearch,'关闭搜索'))+
    `<form class="search-wrap" id="search-form">${icon('search')}<input id="query" class="search-input" type="search" autocomplete="off" placeholder="搜索歌曲、歌手、专辑、歌单" value="${e(searchQuery)}" aria-label="搜索歌曲、歌手、专辑、歌单"><span id="search-clear" ${q?'':'hidden'}>${button(icon('close'),()=>{searchQuery='';$('#query').value='';refreshSearch();},'','清空搜索')}</span></form><div id="search-filters"></div><div id="search-results"></div>`;
}
async function updateSearch(ticket){
  const q=searchQuery.trim(),type=searchType,session=sessionGeneration;
  const target=$('#search-results'),filters=$('#search-filters'),clear=$('#search-clear'),title=$('#page .header h1');
  if(!target||!filters||!clear)return;
  clear.hidden=!q;
  if(title)title.textContent=q?'搜索：'+q:'搜索';
  filters.innerHTML=q?`<div class="chips">${[[0,'综合'],[1,'单曲'],[100,'歌手'],[10,'专辑'],[1000,'歌单']]
    .map(([id,label])=>button(label,()=>{searchType=id;refreshSearch();},`chip ${type===id?'active':''}`)).join('')}</div>`:'';
  listTracks=[];
  if(!q){
    const recent=read('searches',[]);
    target.innerHTML=recent.length?`<section class="section"><div class="section-head"><h2>最近搜索</h2>${button('清除',()=>{write('searches',[]);refreshSearch();})}</div><div class="chips">${recent.map(text=>button(e(text),()=>{searchQuery=text;$('#query').value=text;refreshSearch();},'chip')).join('')}</div></section>`:empty('搜索音乐','找到你喜欢的歌曲、歌手、专辑与歌单','search');
    return;
  }
  target.innerHTML='<div class="page-loading" role="status" aria-label="正在搜索"><span class="spinner"></span></div>';
  write('searches',[q,...read('searches',[]).filter(text=>text!==q)].slice(0,12));
  const types=type===0?[1,100,10,1000]:[type],limit=type===0?10:100;
  const responses=await Promise.allSettled(types.map(kind=>cached(
    JSON.stringify(['search',q,kind,limit]),()=>api('/cloudsearch/pc',{s:q,type:kind,limit,offset:0,total:true}))));
  if(ticket!==renderID||session!==sessionGeneration||route.kind!=='search'||$('#search-results')!==target)return;
  let html='',failed=false;
  for(const [i,kind] of types.entries()){
    if(responses[i].status==='rejected'){failed=true;continue;}
    const r=responses[i].value.result||{};
    if(kind===1){
      listTracks=uniqueTracks(r.songs||[]);
      if(listTracks.length)html+=(type===0?'<div class="section-head"><h2>单曲</h2></div>':'')+tracksHTML(listTracks);
    }else{
      const [key,routeKind,label]=kind===100?['artists','artist','歌手']:kind===10?['albums','album','专辑']:['playlists','playlist','歌单'];
      const items=r[key]||[];
      if(items.length)html+=type===0?shelf(label,items,routeKind):`<div class="grid">${items.map(x=>card(x,routeKind)).join('')}</div>`;
    }
  }
  target.innerHTML=html+(failed?empty('搜索结果加载失败','','wifi',button('重试',refreshSearch,'pill')):html?'':empty('没有搜索结果'));
}
function refreshSearch(){
  clearTimeout(queryTimer);
  if(route.kind==='search')void updateSearch(++renderID);
}
function setupSearch(){
  const input=$('#query');if(!input)return;
  input.addEventListener('input',()=>{
    searchQuery=input.value;
    const ticket=++renderID;
    clearTimeout(queryTimer);
    queryTimer=setTimeout(()=>{if(ticket===renderID&&$('#query')===input)void updateSearch(ticket);},650);
  });
  $('#search-form').addEventListener('submit',ev=>{
    ev.preventDefault();searchQuery=input.value;input.blur();refreshSearch();
  });
}
function showOverlay(kind,body,{title='',compact=false,raw=false,replace=false}={}){
  if(overlayKind&&!replace)overlayHistory.push({kind:overlayKind,html:$('#overlay').innerHTML});
  clearTimeout(overlayTimer);overlayKind=kind;
  $('#overlay').innerHTML=raw?body:`<div class="scrim" ${bind(()=>closeOverlay())}></div><section class="sheet ${compact?'compact-sheet':''}${kind==='settings'?' settings-sheet':''}${kind==='comments'?' comments-sheet':''}${kind==='login'?' login-sheet':''}${kind==='storage'?' storage-sheet':''}" role="dialog" aria-modal="true" aria-label="${e(title)}"><div class="drag"></div><div class="sheet-header"><h2>${e(title)}</h2>${button('完成',()=>closeOverlay())}</div><div class="sheet-body">${body}</div></section>`;
}
function closeOverlay(all=false){closePopover();closeComments();const wasSettings=overlayKind==='settings';clearTimeout(overlayTimer);const prev=all?null:overlayHistory.pop();if(all)overlayHistory=[];if(prev){overlayKind=prev.kind;$('#overlay').innerHTML=prev.html;if(overlayKind==='nowPlaying')updateNowPlaying(true);}else{overlayKind='';$('#overlay').innerHTML='';overlayHistory=[];}
  fmLyricKey='';
  // 设置里的“我的音乐板块”改了顺序或开关后，“我的”页要跟着刷新
if(wasSettings&&route.kind==='library')render();}
// 二级菜单挂在被按下的控件旁边（iOS 那种小列表），不再铺满底部的面板
let menuAnchor=null;
document.addEventListener('pointerdown',ev=>{const t=ev.target.closest('button,.list-row');menuAnchor=t||null;},true);
// 长按判废：WebView 在长按之后抬手仍会补一个 click，底栏和播放条上就变成
// 「长按也跳转」。记下按下的时刻与位置，超过 400ms 或挪动超过 12px 的那次
// click 直接丢掉 —— 长按只算按住，不产生动作。程序化 click（没有 pointerdown）
// 和键盘/读屏激活不判废，保持原有行为。
let pressAt=0,pressX=0,pressY=0,pressMoved=false;
document.addEventListener('pointerdown',ev=>{pressAt=performance.now();pressX=ev.clientX;pressY=ev.clientY;pressMoved=false;},true);
document.addEventListener('pointermove',ev=>{if(!pressAt)return;if(Math.abs(ev.clientX-pressX)>12||Math.abs(ev.clientY-pressY)>12)pressMoved=true;},true);
function swallowLongPress(){const at=pressAt;pressAt=0;return !!at&&(pressMoved||performance.now()-at>400);}
function menu(title,items,anchor=menuAnchor){
  // 点菜单项先把小列表收掉，避免和随后弹出的确认框叠在一起
  const rows=items.map(([label,name,fn,danger])=>button((name?icon(name):'')+`<span>${e(label)}</span>`,()=>{closePopover();fn();},`menu-action ${danger?'danger':''}`)).join('');
  openPopover(title,rows,anchor);
}
function openPopover(title,rows,anchor){
  let host=document.getElementById('pop-layer');
  if(!host){host=document.createElement('div');host.id='pop-layer';document.body.append(host);}
  host.innerHTML=`<div class="scrim popover-scrim" ${bind(()=>closePopover())}></div><div class="popover" role="menu" aria-label="${e(title)}"><div class="popover-head">${e(title)}</div>${rows}</div>`;
  placePopover(anchor);
}
function closePopover(){const host=document.getElementById('pop-layer');if(host)host.innerHTML='';}
function placePopover(anchor){
  const card=document.querySelector('#pop-layer .popover');if(!card)return;
  const pad=12,box=card.getBoundingClientRect();
  const a=anchor&&anchor.isConnected?anchor.getBoundingClientRect():null;
  let left,targetRight=innerWidth-pad;
  if(a){targetRight=Math.min(innerWidth-pad,Math.max(a.right,pad+box.width));left=Math.max(pad,targetRight-box.width);}
  else left=Math.max(pad,(innerWidth-box.width)/2);
  let top=a?a.bottom+8:innerHeight/2-box.height/2;
  if(top+box.height>innerHeight-pad)top=Math.max(pad,(a?a.top-8-box.height:innerHeight-box.height-pad));
  card.style.left=`${left}px`;card.style.top=`${top}px`;
}
function formSheet(title,body,submitLabel,onSubmit){showOverlay('form',`<form id="sheet-form" class="login">${body}<p id="form-error" class="status-error"></p><button class="primary" type="submit">${e(submitLabel)}</button></form>`,{title});$('#sheet-form').addEventListener('submit',async ev=>{ev.preventDefault();const submit=$('#sheet-form button[type=submit]');submit.disabled=true;try{await onSubmit(new FormData(ev.currentTarget));}catch(err){if($('#form-error'))$('#form-error').textContent=err.message;else errorToast(err);}finally{if(submit?.isConnected)submit.disabled=false;}});}
function confirmAction(title,text,fn){showOverlay('confirm',`<div class="login"><p>${e(text)}</p>${button('确认',async()=>{await fn();closeOverlay();},'primary danger')}${button('取消',()=>closeOverlay(),'muted-button')}</div>`,{title,compact:true});}
function newPlaylist(){if(!loggedIn){openLogin();return;}formSheet('新建歌单','<label class="field"><span>名称</span><input name="name" maxlength="100" required placeholder="歌单名称"></label><label class="list-row"><span>私密歌单</span><input class="toggle" name="private" type="checkbox"></label>','创建',async values=>{const name=String(values.get('name')||'').trim();if(!name)throw new Error('请输入歌单名称');await api('/playlist/create',{name,privacy:values.has('private')?10:0,type:'NORMAL'});await loadAccount();closeOverlay();toast('歌单已创建');if(route.kind==='library')render();});}
function setupCommentsDrag(layer){
  const card=layer.querySelector('.comments-card');if(!card||card.dataset.drag)return;card.dataset.drag='1';
  const maxH=()=>innerHeight-Math.max(12,(parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--safe-top'))||0));
  let startY=0,startH=0,dy=0,dragging=false,lastY=0,lastT=0,vel=0;
  const contentOf=()=>card.querySelector('.cc-body')||card;
  card.addEventListener('pointerdown',e=>{
    if(e.target.closest('button,input,a,.cc-close'))return;
    const body=contentOf();
    // 只在「列表已在顶部」或拖动手柄时接管：这样向上滑才会把浮层顶上去
    const atTop=(body.scrollTop||0)<=0;
    const onGrab=!!e.target.closest('.np-grab');
    if(!atTop&&!onGrab)return;
    dragging=true;dy=0;startY=e.clientY;lastY=e.clientY;lastT=performance.now();vel=0;
    startH=card.getBoundingClientRect().height;card.style.transition='none';
  },{passive:true});
  card.addEventListener('pointermove',e=>{
    if(!dragging)return;
    const now=performance.now();const dt=Math.max(1,now-lastT);vel=(e.clientY-lastY)/dt;lastY=e.clientY;lastT=now;
    dy=e.clientY-startY;
    const h=Math.min(maxH(),Math.max(120,startH-dy));
    card.style.height=h+'px';
  },{passive:true});
  const end=()=>{
    if(!dragging)return;dragging=false;
    const full=card.classList.contains('full');
    card.style.transition='height .3s cubic-bezier(.22,1,.3,1)';
    card.style.height='';
    // 上滑 → 全屏（接近顶部）；下滑：全屏回半屏，半屏继续下滑 → 关闭
    if(-dy>60||(vel<-0.45&&dy<0)){card.classList.add('full');}
    else if(dy>60||(vel>0.45&&dy>0)){
      if(full){card.classList.remove('full');}
      else if(dy>110||vel>0.9){closeCommentsWithDrop(card);}
    }
  };
  card.addEventListener('pointerup',end,{passive:true});
  card.addEventListener('pointercancel',end,{passive:true});
}
function closeCommentsWithDrop(card){
  const layer=document.getElementById('cc-layer');if(!layer)return;
  card.style.transition='transform .28s cubic-bezier(.22,1,.3,1),opacity .28s ease';
  card.style.transform='translateY(100%)';card.style.opacity='0';
  setTimeout(()=>{layer.remove();document.querySelector('.now-playing')?.classList.remove('np-dimmed');},260);
}
function syncHeart(t){
  if(!t||overlayKind!=='nowPlaying')return;
  const on=liked.has(t.id);
  document.querySelectorAll('.np-head .round,.np-land-controls [data-transport=like]').forEach(b=>{
    b.classList.toggle('accent',on);
    b.setAttribute('aria-label',on?'取消喜欢':b.dataset.transport?'喜欢':'喜欢歌曲');
    b.innerHTML=icon(on?'heartFill':'heart');
  });
}
async function likeTrack(t){if(!t)return;if(!loggedIn){openLogin();return;}const like=!liked.has(t.id);await api('/radio/like',{alg:'itembased',trackId:String(t.id),like:String(like),time:'3'});if(like)liked.add(t.id);else liked.delete(t.id);toast(like?'已加入我喜欢的音乐':'已取消喜欢');syncHeart(t);updateNowPlaying(true);}
async function subscribe(kind,id,yes){if(!loggedIn){openLogin();return;}await api(`/${kind}/${kind==='playlist'?(yes?'subscribe':'unsubscribe'):(yes?'sub':'unsub')}`,kind==='artist'?{artistId:id,artistIds:JSON.stringify([id])}:{id});toast(yes?'收藏成功':'已取消收藏');cache.clear();await loadAccount();}
function detailMenu(){if(!detail)return;const d={...detail};const own=d.creator?.userId===account?.userId;const items=[['播放全部','play',()=>{closeOverlay();play(listTracks);}],['收藏','star',()=>subscribe(d.kind,d.id,true)],['取消收藏','star',()=>confirmAction('取消收藏','确认取消收藏此内容？',()=>subscribe(d.kind,d.id,false))],['下载全部','download',()=>downloadAll(listTracks)]];if(d.kind==='playlist'&&own)items.push(['删除歌单','trash',()=>confirmAction('删除歌单','此操作将删除服务端歌单，确认继续？',async()=>{await api('/playlist/remove',{ids:JSON.stringify([d.id])});cache.clear();await loadAccount();closeOverlay(true);back();}),true]);menu(d.name,items);}
function trackMenu(t,index){
  const items=[[(liked.has(t.id)?'取消喜欢':'喜欢'),'heart',()=>likeTrack(t)],['下一首播放','next',async()=>{let q=[...player.queue];if(!q.length){await play([t]);}else{q.splice(player.index+1,0,t);await native('control',{action:'replaceQueue',queue:q,index:player.index});}toast('已添加到下一首播放');closeOverlay();}],['添加到歌单','plus',()=>addToPlaylist(t)],['下载','download',()=>downloadTrack(t)],['随机播放',player.mode==='shuffle'?'tick':'shuffle',()=>setMode(player.mode==='shuffle'?'list':'shuffle')],['列表循环',player.mode==='list'?'tick':'repeat',()=>setMode('list')],['单曲循环',player.mode==='single'?'tick':'repeat',()=>setMode('single')],['音效','eq',()=>openEQ()],['睡眠定时','clock',()=>openSleep()],['专辑','album',()=>{closeOverlay(true);if(t.album?.id)navigate({kind:'album',id:t.album.id});}],['歌手','artist',()=>{const a=t.artists?.[0];if(a){closeOverlay(true);navigate({kind:'artist',id:a.id});}}]];
  if(route.kind==='downloads')items.push(['删除本地下载','trash',()=>confirmAction('删除下载','仅删除这首歌的本地下载文件。',async()=>{await native('deleteDownload',{id:t.id});downloaded.delete(String(t.id));closeOverlay(true);render();}),true]);
  if(route.kind==='playlist'&&detail?.creator?.userId===account?.userId)items.push(['从歌单移除','trash',()=>confirmAction('移除歌曲','确认将这首歌从此歌单中移除？',async()=>{await api('/playlist/manipulate/tracks',{op:'del',pid:detail.id,trackIds:JSON.stringify([t.id]),imme:'true'});cache.delete('playlist-'+detail.id);closeOverlay(true);render();}),true]);
  menu(t.name,items);
}
function addPickedToPlaylist(tracks){
  if(!loggedIn){openLogin();return;}
  if(!tracks.length){toast('先选几首');return;}
  const own=playlists.filter(x=>x.creator?.userId===account?.userId);
  if(!own.length){newPlaylist();return;}
  showOverlay('playlistPicker',own.map(p=>button(`${cover(p.coverImgUrl,'playlist-thumb')}<span class="list-label"><strong>${e(p.name)}</strong><small>${p.trackCount||0} 首</small></span>`,async()=>{
    try{await api('/playlist/manipulate/tracks',{op:'add',pid:p.id,trackIds:JSON.stringify(tracks.map(t=>t.id)),imme:'true'});toast(`已添加 ${tracks.length} 首到「${p.name}」`);selecting=false;picked.clear();closeOverlay(true);cache.clear();await loadAccount();render();}
    catch(err){errorToast(err);}
  },'list-row pick-playlist')),{title:`添加到歌单（${tracks.length} 首）`});
}
function addToPlaylist(t){if(!loggedIn){openLogin();return;}const own=playlists.filter(x=>x.creator?.userId===account?.userId);showOverlay('playlistPicker',own.length?own.map(p=>button(`${cover(p.coverImgUrl,'playlist-thumb')}<span class="list-label"><strong>${e(p.name)}</strong><small>${p.trackCount||0} 首</small></span>`,async()=>{try{await api('/playlist/manipulate/tracks',{op:'add',pid:p.id,trackIds:JSON.stringify([t.id]),imme:'true'});toast('已添加到歌单');closeOverlay();}catch(err){errorToast(err);}},'list-row')).join(''):empty('还没有歌单','先创建一个歌单','music',button('新建歌单',newPlaylist,'primary')),{title:'添加到歌单'});}
function sizeText(bytes){if(!bytes)return '0 KB';if(bytes>=1024*1024*1024)return (bytes/1024/1024/1024).toFixed(2)+' GB';if(bytes>=1024*1024)return (bytes/1024/1024).toFixed(1)+' MB';return Math.max(1,Math.round(bytes/1024))+' KB';}
async function fetchLyricPayload(id){
  try{return await api('/song/lyric/v1',{id,cp:false,lv:0,kv:0,tv:0,rv:0,yv:0,ytv:0,yrv:0});}
  catch{return await api('/song/lyric',{id,lv:-1,kv:-1,tv:-1,rv:-1});}
}
function cacheLyricPayload(id,r){try{native('saveLyric',{id:String(id),text:JSON.stringify(r)});}catch{}}

async function cacheLyricsFor(id){
  try{const cached=await native('lyric',{id:String(id)});if(cached)return;const r=await fetchLyricPayload(id);
    if(r)await native('saveLyric',{id:String(id),text:JSON.stringify(r)});}catch{}
}
async function downloadTrack(t){toast('开始下载：'+t.name);await native('download',{track:t});downloaded.add(String(t.id));await cacheLyricsFor(t.id);toast('已下载：'+t.name);render();}
async function downloadAll(items){if(!items.length)return;confirmAction('下载全部',`将下载 ${items.length} 首歌曲，仅保存账号具有完整播放权限的音源。`,async()=>{closeOverlay();let ok=0,failed=0;for(const t of items){try{await native('download',{track:t});downloaded.add(String(t.id));await cacheLyricsFor(t.id);ok++;}catch{failed++;}}toast(`下载完成：成功 ${ok}，失败 ${failed}`);render();});}
async function openLogin(mode='qr',replace=false){
  const generation=++loginGeneration;
  let html=`<div class="login"><div class="segmented">${[['qr','扫码登录'],['sms','手机登录'],['cookie','Cookie']].map(([id,name])=>button(name,()=>openLogin(id,true),id===mode?'active':'')).join('')}</div><h2>登录 Antunes</h2>`;
  if(mode==='qr')html+='<p>使用官方 App 扫描二维码登录</p><div id="qr-area" class="loading"><span class="spinner"></span></div><p id="qr-status">正在获取二维码…</p><p class="notice">可以截图后切换至官方 App，从相册识别二维码，再返回此处。</p>';
  if(mode==='sms')html+=`<p class="notice">短信登录可能受到网络风控限制，推荐使用扫码登录。</p><form id="sms-form"><label class="field"><span>+86</span><input id="phone" name="phone" inputmode="tel" autocomplete="tel-national" placeholder="手机号码" required pattern="[0-9]{6,15}" maxlength="15"></label><label class="field"><input name="captcha" inputmode="numeric" autocomplete="one-time-code" placeholder="验证码" required maxlength="8">${button('获取验证码',sendSMS,'','获取验证码')}</label><button class="primary" type="submit">登录</button></form><p id="login-error" class="status-error"></p>`;
  if(mode==='cookie')html+='<p class="notice">从你自己的已登录浏览器中获取 Cookie，至少包含 MUSIC_U。凭据仅保存在本机的加密存储中。</p><form id="cookie-form"><textarea name="cookie" class="cookie-input" aria-label="登录 Cookie" placeholder="MUSIC_U=…; __csrf=…" autocomplete="off" spellcheck="false" required></textarea><button class="primary" type="submit">验证并登录</button></form><p id="login-error" class="status-error"></p>';
  html+='</div>';showOverlay('login-'+mode,html,{title:'账号登录',replace});
  if(mode==='qr'){

    try{
      const key=(await api('/login/qrcode/unikey',{type:3})).unikey;if(overlayKind!=='login-qr'||generation!==loginGeneration)return;
      if(!key)throw new Error('二维码获取失败');$('#qr-area').innerHTML='<canvas id="qr" aria-label="登录二维码"></canvas>';
      await window.QRCode.toCanvas($('#qr'),'https://music.163.com/login?codekey='+key,{width:228,margin:2,errorCorrectionLevel:'M'});
      $('#qr-status').textContent='请扫码登录';
      const poll=async()=>{
        if(overlayKind!=='login-qr')return;
        try{const r=await api('/login/qrcode/client/login',{key,type:3});if(overlayKind!=='login-qr')return;
          if(r.code===803){await signedIn();return;}
          if(r.code===800){$('#qr-status').textContent='二维码已过期';$('#qr-area').innerHTML=button('刷新二维码',()=>openLogin('qr',true),'muted-button');return;}
          $('#qr-status').textContent=r.code===802?'已扫码，请在官方 App 确认':'请扫码登录';
        }catch{if(overlayKind==='login-qr'&&$('#qr-status'))$('#qr-status').textContent='连接中断，正在重试…';}
        if(overlayKind==='login-qr')overlayTimer=setTimeout(poll,2500);
      };overlayTimer=setTimeout(poll,2000);
    }catch(err){if(overlayKind==='login-qr'&&$('#qr-area')){$('#qr-area').innerHTML=button('重新获取二维码',()=>openLogin('qr',true),'muted-button');$('#qr-status').textContent=err.message;}}
  }
  if(mode==='sms')$('#sms-form').addEventListener('submit',async ev=>{ev.preventDefault();const values=new FormData(ev.currentTarget);try{await api('/w/login/cellphone',{type:'1',https:'true',phone:String(values.get('phone')),countrycode:'86',captcha:String(values.get('captcha')),remember:'true'});await signedIn();}catch(err){$('#login-error').textContent=err.message;}});
  if(mode==='cookie')$('#cookie-form').addEventListener('submit',async ev=>{ev.preventDefault();const values=new FormData(ev.currentTarget);try{await native('cookieLogin',{cookie:String(values.get('cookie'))});await signedIn();}catch(err){if($('#login-error'))$('#login-error').textContent=err.message;}});
}
async function sendSMS(){const phone=$('#phone')?.value||'';if(!/^[0-9]{6,15}$/.test(phone)){toast('请输入有效的手机号码');return;}await api('/sms/captcha/sent',{ctcode:'86',cellphone:phone,secrete:'music_middleuser_pclogin'});toast('验证码已发送');}
async function signedIn(){const status=await native('status');if(!status.loggedIn)throw new Error('登录尚未确认，请重试');resetAccountSession(true);const session=sessionGeneration;await loadAccount();if(session!==sessionGeneration)return;closeOverlay(true);toast('登录成功');render();}
function optionList(items,value){return items.map(([v,label])=>`<option value="${e(v)}" ${value===v?'selected':''}>${e(label)}</option>`).join('');}
// 选择器不再用系统下拉（无法套材质），改成和「三个点」同一套玻璃列表
function selectRow(label,key,items,onChange){
  const cur=String(prefs[key]??'');
  const shown=(items.find(([value])=>value===cur)||items[0]||['',''])[1];
  const open=()=>menu(label,items.map(([value,text])=>[text,prefs[key]===value?'tick':'',async()=>{prefs[key]=value;savePrefs();if(onChange)await onChange(value);refreshSettings();}]));
  return button(`<span>${e(label)}</span><span class="row-value">${e(shown)}</span>${icon('chevron')}`,open,'list-row select-row',e(label));
}
function bindChange(fn){return `data-change="${bind(fn).match(/"(\d+)"/)[1]}"`;}
function toggleRow(label,key,after){return `<label class="list-row"><span>${e(label)}</span><input class="toggle" type="checkbox" aria-label="${e(label)}" ${prefs[key]?'checked':''} ${bindChange(ev=>{prefs[key]=ev.target.checked;savePrefs();if(after)after();})}></label>`;}
// 设置里的顺序必须与底栏从左到右一致：直接复用 navigationTabs 的排序结果
const SECTION_DEFS=[['home','推荐','showHome'],['explore','精选','showExplore'],['fm','漫游','showFM'],['library','我的','showLibrary'],['search','搜索','showSearch']];
// 三个点：点开是「移到顶部 / 上移 / 下移 / 移到底部」，不再用手势拖动。
function renameButton(prop,key,label){return button(icon('more'),()=>openRowMoveMenu(prop,key,label),'row-menu',`排序：${e(label)}`);}
function currentOrder(prop){
  const defs=prop==='tabOrder'?SECTION_DEFS.map(d=>d[0]):LIBRARY_ROWS.map(r=>r[0]);
  const cur=prefs[prop];
  return Array.isArray(cur)&&cur.length?cur.slice():defs.slice();
}
function moveRow(prop,key,move){
  const order=currentOrder(prop);const i=order.indexOf(key);
  if(i<0)return;
  if(move==='top'){if(i===0)return;order.splice(i,1);order.unshift(key);}
  else if(move==='up'){if(i===0)return;[order[i-1],order[i]]=[order[i],order[i-1]];}
  else if(move==='down'){if(i===order.length-1)return;[order[i+1],order[i]]=[order[i],order[i+1]];}
  else{if(i===order.length-1)return;order.splice(i,1);order.push(key);}
  prefs[prop]=order;savePrefs();
  refreshSettings();
  if(prop==='tabOrder')renderChrome();
  if(route.kind==='library')render();
}
function openRowMoveMenu(prop,key,label){
  menu(`排序：${label}`,[['移到顶部','upTo',()=>moveRow(prop,key,'top')],['上移','up',()=>moveRow(prop,key,'up')],['下移','down',()=>moveRow(prop,key,'down')],['移到底部','downTo',()=>moveRow(prop,key,'bottom')]]);
}
function sectionRows(){
  const order=(Array.isArray(prefs.tabOrder)&&prefs.tabOrder.length)?prefs.tabOrder:SECTION_DEFS.map(d=>d[0]);
  // tabOrder 里可能存偏好键（showHome…）也可能存板块 id（home…），两种都认
  const rank=d=>{let i=order.indexOf(d[2]);if(i<0)i=order.indexOf(d[0]);return i<0?order.length+1:i;};
  return `<div class="group" data-order="tabOrder">${[...SECTION_DEFS].sort((a,b)=>rank(a)-rank(b)).map(([id,label,key])=>homeSectionToggle(label,key,id)).join('')}</div>`;
}
function librarySectionRows(){
  const order=(Array.isArray(prefs.libraryOrder)&&prefs.libraryOrder.length)?prefs.libraryOrder:LIBRARY_ROWS.map(r=>r[0]);
  const rank=k=>{const i=order.indexOf(k);return i<0?order.length+1:i;};
  return `<div class="group" data-order="libraryOrder">${[...LIBRARY_ROWS].sort((a,b)=>rank(a[0])-rank(b[0])).map(([id,label,,flag])=>`<div class="list-row section-row" data-key="${flag}" data-order-key="${id}"><label class="section-label"><span>${e(label)}</span><input class="toggle" type="checkbox" aria-label="${e(label)}" ${prefs[flag]!==false?'checked':''} ${bindChange(ev=>{prefs[flag]=ev.target.checked;savePrefs();})}></label>${renameButton('libraryOrder',id,label)}</div>`).join('')}</div>`;
}
// 「我的」是兜底板块：其它四个（推荐/精选/漫游/搜索）都关掉之后才允许关它，
// 否则底栏会出现「全部关闭 → 只剩兜底」的死循环，用户也没法再回到设置。
const OTHER_SECTIONS=['showHome','showExplore','showFM','showSearch'];
function othersAllOff(){return OTHER_SECTIONS.every(k=>prefs[k]===false);}
function homeSectionToggle(label,key,orderKey){
  const locked=key==='showLibrary'&&!othersAllOff();
  const note=locked?' title="其它四个板块全部关闭后才能关闭「我的」"':'';
  return `<div class="list-row section-row${locked?' is-locked':''}" data-key="${key}" data-order-key="${orderKey||key}"><label class="section-label"${note}><span>${e(label)}</span><input class="toggle" type="checkbox" aria-label="${e(label)}" ${prefs[key]?'checked':''} ${locked?'disabled':''} ${bindChange(async ev=>{
    if(key==='showLibrary'&&!ev.target.checked&&!othersAllOff()){ev.target.checked=true;toast('其它四个板块全部关闭后才能关闭「我的」');return;}
    prefs[key]=ev.target.checked;
    // 反向约束：只要还有别的板块开着，「我的」就必须是开的（否则会留下非法组合）。
    if(prefs.showLibrary===false&&!othersAllOff())prefs.showLibrary=true;
    savePrefs();
    if(overlayKind==='settings')refreshSettings();
    if(!navigationTabs(prefs).some(([k])=>k===tab)){tab=navigationTabs(prefs)[0][0];history=[];route={kind:tab};await render();}
    else renderChrome();
  })}></label>${renameButton('tabOrder',orderKey||key,label)}</div>`;
}
let selecting=false,picked=new Set();
function openSettingsReplace(){showOverlay('settings',settingsHTML(),{title:'设置',replace:true});}
// 设置页内容原地替换：重建整个 sheet 会重放入场动画，看起来就是闪一下
function refreshSettings(){
  const body=overlayKind==='settings'?document.querySelector('#overlay .sheet-body'):null;
  if(!body)return openSettingsReplace();
  body.innerHTML=settingsHTML();
}
function ambientIntensityRow(){
  const percent=Math.round(Math.min(1.5,Math.max(0.5,Number(prefs.ambientIntensity)||1))*100);
  return `<label class="list-row slider-row"><span>背景色强度</span><input type="range" aria-label="背景色强度" min="50" max="150" step="10" value="${percent}" ${bindChange(ev=>{prefs.ambientIntensity=Number(ev.target.value)/100;write('preferences',prefs);const out=document.getElementById('ambient-intensity');if(out)out.textContent=Math.round(prefs.ambientIntensity*100)+'%';refreshAmbient();})}><output id="ambient-intensity">${percent}%</output></label><div class="slider-scale"><span>50%</span><span>150%</span></div>`;
}
function settingsHTML(){
  // 音质七档（与备用源码 MeloX 一致）：选到的档位拿不到时自动往下降。
  let html=`<div class="group-label">播放</div><div class="group">${listRow('音质','eq',()=>toast('当前固定为极高音质'),'<span class="row-value">极高</span>')}${listRow('音效','eq',openEQ)}${listRow('睡眠定时','clock',openSleep)}</div>`;
  html+=`<div class="group-label">启动</div><div class="group">${selectRow('冷启动板块','startTab',[['auto','自动（第一个板块）'],['home','推荐'],['explore','精选'],['fm','漫游'],['library','我的'],['search','搜索']])}</div><div class="group-label">主页板块</div>${sectionRows()}<p class="group-note">只留一项时底栏直接显示该板块图标，两项及以上折叠为头像。「我的」只能在其它四个板块全部关闭后关闭；全部关闭时默认显示「我的」。</p><div class="group-label">我的音乐板块</div>${librarySectionRows()}<p class="group-note">长按右侧三横线可上下拖动排序（顺序即“我的”页里从上到下）；关掉的项不再出现在“我的”页。</p><div class="group-label">主页歌单展示</div><div class="group">${toggleRow('创建的歌单','libCreatedLists',()=>{if(route.kind==='library')render();})}${toggleRow('收藏的歌单','libCollectedLists',()=>{if(route.kind==='library')render();})}${toggleRow('我喜欢的音乐显示在创建的歌单','showLikedInCreated',()=>{if(route.kind==='library')render();})}</div>`;
  html+=`<div class="group-label">玻璃</div><div class="group">${selectRow('玻璃样式','glassStyle',[['native','原生磨砂'],['frost','高透磨砂'],['clear','清透玻璃'],['off','关闭']],applyTheme)}</div>`;
  html+=`<div class="group-label">外观</div><div class="group">${selectRow('主题','appearance',[['system','跟随系统'],['light','浅色'],['dark','深色']])}${toggleRow('底栏歌词','lyricBar',()=>{lyricsBar=prefs.lyricBar;if(!lyricsBar)tabsExpanded=false;renderChrome();})}${selectRow('歌词对齐','lyricAlignMode',[['left','居左'],['center','居中'],['right','居右']],()=>{chromeKey='';renderChrome();})}${toggleRow('底栏文字','tabLabels',applyTheme)}${toggleRow('我的页搜索按钮','librarySearch',()=>{if(route.kind==='library')render();})}${toggleRow('点击封面打开专辑','artworkLink')}${toggleRow('显示歌词翻译','translation')}${toggleRow('逐字歌词（卡拉OK）','karaoke',()=>{const t=player.queue[player.index];if(t)loadLyrics(t.id);})}${selectRow('日文歌词读音','annotation',[['none','无'],['romaji','罗马音']])}${toggleRow('主界面环境色','ambient',()=>{refreshSettings();refreshAmbient();})}${prefs.ambient?ambientIntensityRow():''}</div>`;
  html+=`<div class="group-label">存储</div><div class="group">${listRow('存储空间','download',openStorage)}${listRow('已下载','music',()=>{closeOverlay(true);navigate({kind:'downloads'});})}</div><div class="group-label">账号</div><div class="group">${loggedIn?`${listRow(account?.nickname||'已登录','user',()=>{})}${button('<span>退出登录</span>',()=>confirmAction('退出登录','将退出当前账号，本地下载与设置会保留。',async()=>{await native('logout');resetAccountSession(false);closeOverlay(true);render();}),'list-row danger')}`:listRow('登录','user',()=>openLogin())}</div>`;
  html+=`<div class="group-label">关于</div><div class="group">${listRow('Antunes','music',openAbout,'<small>1.7</small>')}${listRow('开源许可','album',openLicenses)}</div>`;
  return html;
}
function openSettings(){showOverlay('settings',settingsHTML(),{title:'设置'});}
function openAbout(){showOverlay('about',`<div class="about"><img src="icon.png" alt="Antunes 图标"><h2>Antunes</h2><p>随心而听的第三方网易云客户端</p><div class="group about-meta"><div class="list-row about-row"><span class="about-row-icon">${icon('user')}</span><strong>作者</strong><small>Anyu</small></div><div class="list-row about-row"><span class="about-row-icon">${icon('album')}</span><strong>当前版本</strong><small>1.7</small></div><div class="list-row about-row" role="button" tabindex="0" data-open-repo><span class="about-row-icon">${icon('link')}</span><strong>仓库</strong><small>Anyu1014/Antunes ›</small></div></div><p class="notice" style="margin-top:16px">许可证：LGPL-3.0-only</p></div>`,{title:'关于'});const repo=$('[data-open-repo]');if(repo)repo.onclick=()=>native('openUrl',{url:'https://github.com/Anyu1014/Antunes'}).catch(()=>{});}
function openLicenses(){showOverlay('licenses',`<div class="pad"><h3>Kumone</h3><p class="notice">Copyright © missuo / MOE AI LLC 与贡献者。源码与改动适用 LGPL-3.0-only；发行源码包含完整 LICENSE、COPYING。Anyu 磨砂样式由本机 Anyu 项目复用。</p><h3>QRCode</h3><p class="notice">node-qrcode · Copyright © 2012–2015 Ryan Day, 2015–2017 Soldair, 2016–2017 Enrico La Monica · MIT License。完整文本随应用 QRCODE-LICENSE.txt 附带。</p></div>`,{title:'开源许可'});}
async function openStorage(){
  const items=await native('downloads');const stats=(await native('lyricStats'))||{count:0,bytes:0};
  const total=items.reduce((sum,t)=>sum+(t.bytes||0),0);
  showOverlay('storage',`<div class="storage-total"><strong>${sizeText(total)}</strong><p class="secondary">${items.length} 首本地歌曲</p><div class="storage-bar"></div></div>
  <div class="group">${button(`<span><svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 6a2 2 0 0 1 2-2h8l6 6v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6Z"/></svg><span>图片缓存</span></span><span class="row-value">${items.length?'已缓存封面':'无'}</span>`,()=>{toast('封面随下载歌曲保留，可在此清理浏览缓存');},'list-row')}
  ${button('<span>清除图片缓存</span>',()=>{cache.clear();toast('图片缓存已清理');closeOverlay(true);openStorage();},'list-row accent')}
  </div>
  <p class="group-note">清除后保留已下载歌曲的封面。</p>
  <div class="group">${listRow('歌曲缓存','download',()=>{closeOverlay(true);navigate({kind:'downloads'});},`<span class="row-value">${sizeText(total)}</span>`)}
  ${listRow('歌词缓存','lyrics',()=>{toast(stats.count?'离线播放已下载歌曲即可看到缓存歌词':'还没有歌词缓存');},`<span class="row-value">${stats.count?stats.count+' 首 · '+sizeText(stats.bytes):'无'}</span>`)}
  ${button('<span>清除歌词缓存</span>',async()=>{const s2=await native('lyricStats');if(!(s2&&s2.count>0)){toast('还没有歌词缓存');return;}confirmAction('清除歌词缓存',`将删除 ${s2.count} 首歌的本地歌词，联网后会重新获取。`,async()=>{await native('clearLyrics');closeOverlay(true);openStorage();});},'list-row accent')}
  </div>
  <p class="group-note">歌词随下载一起保存，清除后需要联网重新获取。</p>
  <div class="group">${listRow('已下载','music',()=>{closeOverlay(true);navigate({kind:'downloads'});},`<span class="row-value">${sizeText(total)}</span>`)}
  ${listRow('应用数据','cloud',()=>{toast('账号与设置保存在应用私有目录');},`<span class="row-value">设置与账号</span>`)}
  </div>`,{title:'存储空间'});
}
const eqPresets={关闭:[0,0,0,0,0,0,0,0,0,0],流行:[-1,1,3,4,3,1,-1,-1,1,2],摇滚:[4,3,1,-1,-2,-1,2,4,5,4],古典:[3,2,0,-1,-1,0,1,3,4,3],爵士:[3,2,1,2,-2,-2,0,2,3,4],电子:[5,4,1,0,-2,2,1,3,4,5],人声:[-3,-2,-1,2,4,4,3,1,-1,-2],低音增强:[6,5,4,2,0,0,0,0,0,0],高音增强:[0,0,0,0,0,1,2,4,5,6]};
let playPanelKind='';
function closePlayPanel(){const l=document.getElementById('np-float');if(l)l.remove();playPanelKind='';}
function openPlayPanel(kind,title,html,after){
  closePopover();
  closePlayPanel();
  let l=document.getElementById('np-float');
  if(!l){l=document.createElement('div');l.id='np-float';l.className='np-float';document.body.appendChild(l);}
  l.innerHTML=`<div class="np-float-scrim"></div><section class="play-panel" role="dialog" aria-label="${e(title)}"><div class="np-grab"><i></i></div><header class="pp-head"><strong>${e(title)}</strong><button class="pp-done" aria-label="完成">完成</button></header><div class="pp-body">${html}</div></section>`;
  playPanelKind=kind;
  l.querySelector('.np-float-scrim').addEventListener('click',closePlayPanel);
  l.querySelector('.pp-done').addEventListener('click',closePlayPanel);
  if(after)after(l);
  return l;
}
function openEQ(){openPlayPanel('eq','音效',`<div class="chips">${Object.entries(eqPresets).map(([name,bands])=>button(name,async()=>{prefs.eqBands=[...bands];prefs.eqEnabled=name!=='关闭';savePrefs();await native('eq',{bands,enabled:prefs.eqEnabled});openEQReplace();},'chip')).join('')}</div><div class="group">${toggleRow('启用音效','eqEnabled')}</div><div class="eq-grid">${[31,62,125,250,500,'1k','2k','4k','8k','16k'].map((f,n)=>`<label class="eq-band"><span id="db-${n}">${prefs.eqBands[n]}dB</span><input type="range" min="-12" max="12" value="${prefs.eqBands[n]}" aria-label="${f} Hz" ${bindChange(async ev=>{prefs.eqBands[n]=Number(ev.target.value);prefs.eqEnabled=true;savePrefs();$('#db-'+n).textContent=prefs.eqBands[n]+'dB';await native('eq',{bands:prefs.eqBands,enabled:true});})}><span>${f}</span></label>`).join('')}</div><p class="group-note">均衡器通过 Android 原生音频会话生效。频点会映射到设备支持的硬件频段。</p>`);const toggle=document.querySelector('#np-float input[aria-label="启用音效"]');toggle.addEventListener('change',()=>native('eq',{bands:prefs.eqBands,enabled:toggle.checked}).catch(errorToast));}
function openEQReplace(){openEQ();}
function ago(ms){const d=Date.now()-Number(ms||0);if(!isFinite(d)||d<0)return '';const m=Math.floor(d/60000);if(m<1)return '刚刚';if(m<60)return m+'分钟前';const h=Math.floor(m/60);if(h<24)return h+'小时前';const day=Math.floor(h/24);if(day<30)return day+'天前';const mo=Math.floor(day/30);if(mo<12)return mo+'个月前';return Math.floor(mo/12)+'年前';}
function closeComments(){const l=document.getElementById('cc-layer');if(l)l.remove();const np=document.querySelector('.now-playing');if(np){np.classList.remove('np-dimmed');np.classList.remove('np-shrunk');}}
async function openComments(t=player.queue[player.index]){if(!t||!t.id)return;
  // 评论浮在播放页之上（iOS 行为）：独立图层，不动 #overlay，播放页保持可见。
  let layer=document.getElementById('cc-layer');
  if(!layer){layer=document.createElement('div');layer.id='cc-layer';document.body.append(layer);}
  const shell=(body)=>`<div class="scrim" ${bind(()=>closeComments())}></div><section class="comments-card comments-sheet" role="dialog" aria-modal="true" aria-label="歌曲评论"><div class="np-grab"><i></i></div>${body}</section>`;
  layer.innerHTML=shell(`<div class="loading"><span class="spinner"></span></div>`);setupCommentsDrag(layer);
  const npEl=document.querySelector('.now-playing');if(npEl)npEl.classList.add('np-dimmed');
  try{
    const r=await api('/v1/resource/comments/R_SO_4_'+t.id,{limit:50,offset:0,beforeTime:0});
    if(!document.getElementById('cc-layer'))return;
    const hot=r.hotComments||[];const rest=(r.comments||[]).filter(c=>!hot.some(h=>h.commentId===c.commentId));
    const total=r.total||0;
    const row=(c)=>`<article class="cc-item"><div class="cc-item-head">${cover(c.user?.avatarUrl,'cc-avatar')}<div class="cc-item-meta"><strong>${e(c.user?.nickname)}</strong><small>${e(ago(c.time))}</small></div>${button(icon('thumb')+`<span>${count(c.likedCount)}</span>`,async()=>{if(!loggedIn){openLogin();return;}await api(c.liked?'/v1/comment/unlike':'/v1/comment/like',{threadId:'R_SO_4_'+t.id,commentId:c.commentId});toast(c.liked?'已取消点赞':'已点赞');},`cc-like${c.liked?' on':''}`,`点赞 ${count(c.likedCount)}`)}</div><p class="cc-text">${e(c.content)}</p>${c.beReplied?.[0]?`<p class="cc-reply">回复 @${e(c.beReplied[0].user?.nickname)}：${e(c.beReplied[0].content)}</p>`:''}</article>`;
    const head=`<header class="cc-head">${cover(t.cover,'cc-thumb')}<div class="cc-head-meta"><strong>${e(t.name)}</strong><small>${e(t.artist)} · ${count(total)} 条评论</small></div>${round('close',()=>closeComments(),'关闭评论','cc-close')}</header>`;
    const body=hot.length||rest.length?`${hot.length?`<p class="cc-label">热门评论</p>${hot.map(row).join('')}`:''}${rest.length?`<p class="cc-label">最新评论</p>${rest.map(row).join('')}`:''}`:empty('还没有评论');
    if(document.getElementById('cc-layer')){layer.innerHTML=shell(head+`<div class="cc-body">${body}</div>`);setupCommentsDrag(layer);}
  }catch(err){if(document.getElementById('cc-layer'))layer.innerHTML=shell(`<header class="cc-head"><div class="cc-head-meta"><strong>${e(t.name)}</strong><small>评论加载失败</small></div>${round('close',()=>closeComments(),'关闭评论','cc-close')}</header><div class="cc-body">${empty('评论加载失败',err.message,'wifi')}</div>`);}
}

const landscapePlayer=matchMedia('(orientation:landscape)');
landscapePlayer.addEventListener('change',({matches})=>{
  if(overlayKind!=='nowPlaying')return;
  if(matches){if(!showLyric)toggleLyrics();refreshLandscapePalette();}
  else $('.now-playing')?.classList.remove('np-land-palette');
  $('#np-pager')?.scrollTo({left:0,behavior:'instant'});
});
function openNowPlaying(withLyrics=false){
  const t=player.queue[player.index];if(!t)return;
  closeOverlay(true);showLyric=withLyrics||landscapePlayer.matches;activeLine=-1;
  showOverlay('nowPlaying',nowPlayingHTML(t),{raw:true});
  if(lyricID!==t.id)loadLyrics(t.id);if(showLyric)renderLyrics();else updateNowPlaying(true);setupSeek();setupPager();setupCommentsSwipe();loadNowComments(t);setupDismissDrag();wireNowPlaying();
}
function nowPlayingLandscape(t){
  const on=liked.has(t.id),meta=[t.artist,t.album?.name].filter(Boolean).join(' — ');
  const controlButton=(action,glyph,label,fn,cls='')=>`<button type="button" class="${cls}" data-transport="${action}" ${bind(fn)} aria-label="${label}">${icon(glyph)}</button>`;
  const artwork=prefs.artworkLink&&t.album?.id
    ?button(cover(t.cover,'np-land-art'),()=>{closeOverlay(true);navigate({kind:'album',id:t.album.id});},'np-land-art-link','打开专辑')
    :cover(t.cover,'np-land-art');
  return `<button class="np-land-close" ${bind(()=>closeOverlay(true))} aria-label="关闭播放页">${icon('down')}</button>
    <div class="np-land-track">${artwork}<strong>${e(t.name)}</strong><small>${e(meta)}</small></div>
    <div class="np-land-controls" aria-label="播放控制">
    ${controlButton('like',on?'heartFill':'heart',on?'取消喜欢':'喜欢',()=>likeTrack(player.queue[player.index]),on?'accent':'')}
    ${controlButton(player.fm?'trash':'previous',player.fm?'trash':'skipBack',player.fm?'不喜欢，换一首':'上一首',()=>player.fm?fmTrash():control('previous'))}
    ${controlButton('toggle',player.playing?'pause':'play',player.playing?'暂停':'播放',()=>control('toggle'),'play-main')}
    ${controlButton('next','skipForward','下一首',()=>control('next'))}
    <button type="button" data-transport="comments" ${bind(toggleLandscapeComments)} aria-label="显示评论" aria-pressed="false">${icon('lyrics')}</button>
    </div>`;
}
function toggleLandscapeComments(){
  const pager=$('#np-pager');
  if(pager)pager.scrollTo({left:pager.scrollLeft<pager.clientWidth/2?pager.clientWidth:0,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
}
async function refreshLandscapePalette(){
  if(!landscapePlayer.matches)return;
  const root=$('.now-playing'),t=player.queue[player.index],url=ambientArtworkURL(t?.cover||t?.album?.picUrl);
  if(!root||!url)return;
  try{
    const {primary,secondary}=await ambientPaletteFor(url);
    if(!root.isConnected||!landscapePlayer.matches)return;
    root.style.setProperty('--np-land-primary',`rgb(${primary.join(' ')})`);
    root.style.setProperty('--np-land-secondary',`rgb(${secondary.join(' ')})`);
    root.classList.add('np-land-palette');
  }catch{}
}
function nowPlayingHTML(t){return `<section class="now-playing np-immersive" role="dialog" aria-modal="true" aria-label="正在播放">${nowPlayingLandscape(t)}<div class="np-grab" id="np-grab" aria-label="下拉关闭播放页"><i></i></div><div class="np-backdrop" style="background-image:url('${e(imageURL(t.cover)).replaceAll("'",'%27')}')"></div><header class="np-head${showLyric?'':' no-thumb'}"><span class="np-thumb-slot">${cover(t.cover,'np-thumb')}</span><div class="np-head-meta"><strong id="np-title">${e(t.name)}</strong><small id="np-artist">${e(t.artist)}</small></div>${round(liked.has(t.id)?'heartFill':'heart',()=>likeTrack(player.queue[player.index]),liked.has(t.id)?'取消喜欢':'喜欢歌曲',liked.has(t.id)?'accent':'')}${button(icon('more'),()=>trackMenu(player.queue[player.index],player.index),'','歌曲菜单')}</header><div class="np-pager" id="np-pager"><div class="np-page"><div class="np-cover-wrap" id="np-visual">${button(cover(t.cover,`np-cover ${player.playing?'':'paused'}`),()=>{if(prefs.artworkLink&&t.album?.id){closeOverlay(true);navigate({kind:'album',id:t.album.id});}else toggleLyrics();},'','打开专辑')}</div><div class="np-strip" id="np-strip" role="button" aria-label="查看歌词" ${bind(()=>{if(!showLyric)toggleLyrics();})}></div></div><div class="np-page np-comments" id="np-comments"><div class="loading"><span class="spinner"></span></div></div></div><div class="np-dots" id="np-dots"><i class="on"></i><i></i></div><div class="np-seek"><div class="np-seek-track"><input id="seek" type="range" min="0" max="${player.duration||t.duration||1}" value="${player.position||0}" aria-label="播放进度"></div><div class="np-time"><span id="elapsed">${time(player.position)}</span><span id="remaining">${time(player.duration||t.duration)}</span></div></div><div class="np-controls">${button(icon(player.fm?'trash':'previous'),()=>player.fm?fmTrash():control('previous'),'',player.fm?'不喜欢，换一首':'上一首')}${button(icon(player.playing?'pause':'play'),()=>control('toggle'),'play-main','播放或暂停')}${button(icon('next'),()=>control('next'),'','下一首')}</div><p class="np-error" id="np-error">${e(player.error||'')}</p><div class="np-bottom"><button class="glass np-lyrics-toggle" ${bind(toggleLyrics)} aria-label="歌词" aria-pressed="${showLyric}">${icon(showLyric?'lyricFill':'lyric')}</button>${button(icon('lyrics'),()=>openComments(player.queue[player.index]),'glass','评论区')}${button(icon('queue'),openQueue,'glass','播放列表')}</div></section>`;}
function setupSeek(){const seek=$('#seek');if(!seek)return;updateSeekFill(seek);seek.addEventListener('input',()=>{seek.dataset.dragging='true';updateSeekFill(seek);$('#elapsed').textContent=time(seek.value);});seek.addEventListener('change',()=>{control('seek',{value:Number(seek.value)});seek.dataset.dragging='false';});}
function setMode(mode){player.mode=mode;control('mode',{mode});toast({list:'列表循环',shuffle:'随机播放',single:'单曲循环'}[mode]);if(playPanelKind==='queue')openQueue();}
function cycleMode(){const modes=['list','shuffle','single'];setMode(modes[(modes.indexOf(player.mode)+1)%3]);}
async function loadLyrics(id){if(lyricID!==id){lyrics=[];translations=[];romaji=[];}lyricID=id;activeLine=-2;
  try{let r=null;try{const cached=await native('lyric',{id:String(id)});if(cached)r=JSON.parse(cached);}catch{}
    if(!r){r=await fetchLyricPayload(id);if(r)cacheLyricPayload(id,r);}if(lyricID!==id)return;
    const verbatim=parseVerbatim(r.yrc?.lyric);lyrics=prefs.karaoke&&verbatim.length?verbatim:parseLyrics(r.lrc?.lyric);translations=parseLyrics(r.ytlrc?.lyric||r.tlyric?.lyric);romaji=parseLyrics(r.yromalrc?.lyric||r.romalrc?.lyric);if(overlayKind==='nowPlaying'){if(showLyric)renderLyrics();else updateNowPlayingLyrics(true);}
  }catch(err){if(lyricID===id&&showLyric&&$('#np-visual'))$('#np-visual').innerHTML=`<p class="secondary">歌词加载失败：${e(err.message)}</p>`;}
}
function toggleLyrics(){
  showLyric=!showLyric;activeLine=-1;
  const lyricButton=$('.np-lyrics-toggle');
  if(lyricButton){lyricButton.setAttribute('aria-pressed',String(showLyric));lyricButton.innerHTML=icon(showLyric?'lyricFill':'lyric');}
  const t=player.queue[player.index];
  const head=document.querySelector('.np-head');
  const pad=parseFloat(getComputedStyle(document.querySelector('.now-playing')).paddingLeft)||32;
  const hr=head?head.getBoundingClientRect():null;
  const slot=hr?{left:pad,top:hr.top+(hr.height-14-62)/2,width:62,height:62}:null;
  const src=t?imageURL(t.cover):'';
  if(showLyric){
    const coverEl=document.querySelector('.np-cover');
    const cr=coverEl?coverEl.getBoundingClientRect():null;
    if(!isNaN(parseFloat(cr&&cr.width))&&cr&&cr.width>40&&slot)flyArtwork(cr,slot,src,18,10);
    if(head){head.classList.add('thumb-hidden-until-end');head.classList.remove('no-thumb');}
    renderLyrics();
    setTimeout(()=>{if(head){head.classList.remove('thumb-hidden-until-end');}},380);
  }else{
    const thumb=document.querySelector('.np-thumb');
    const tr=thumb?thumb.getBoundingClientRect():null;
    if(head){head.classList.add('no-thumb');head.classList.remove('thumb-hidden-until-end');}
    const strip=$('#np-strip');if(strip)strip.style.display='';
    const visual=$('#np-visual');visual.className='np-cover-wrap';const pg0=visual.closest('.np-page');if(pg0)pg0.classList.remove('lyrics-mode');
    visual.innerHTML=button(cover(t.cover,`np-cover ${player.playing?'':'paused'}`),()=>{if(prefs.artworkLink&&t.album?.id){closeOverlay(true);navigate({kind:'album',id:t.album.id});}else toggleLyrics();},'','打开专辑');
    const big=$('.np-cover');
    if(big&&tr){const br=big.getBoundingClientRect();big.style.opacity='0';flyArtwork(tr,br,src,10,18);setTimeout(()=>{if(big.isConnected)big.style.opacity='1';},380);}
    updateNowPlayingLyrics(true);
  }
}

function flyArtwork(from,to,src,radiusFrom,radiusTo){
  if(!from||!to)return;
  const ghost=document.createElement('img');
  ghost.className='np-fly';ghost.src=src;ghost.alt='';
  ghost.style.cssText=`position:fixed;left:${from.left}px;top:${from.top}px;width:${from.width}px;height:${from.height}px;border-radius:${radiusFrom}px;object-fit:cover;z-index:60;pointer-events:none;transition:none;box-shadow:0 14px 44px #00000055`;
  document.body.append(ghost);
  requestAnimationFrame(()=>{
    ghost.style.transition='left .38s cubic-bezier(.22,1,.3,1),top .38s cubic-bezier(.22,1,.3,1),width .38s cubic-bezier(.22,1,.3,1),height .38s cubic-bezier(.22,1,.3,1),border-radius .38s ease';
    ghost.style.left=to.left+'px';ghost.style.top=to.top+'px';ghost.style.width=to.width+'px';ghost.style.height=to.height+'px';ghost.style.borderRadius=radiusTo+'px';
  });
  setTimeout(()=>ghost.remove(),420);
}
function wireNowPlaying(){
  // 播放页内的按钮全部走全局 data-call 委托；这里只兜底歌词条与封面点击。
  const strip=$('#np-strip');if(strip&&!strip.dataset.wired){strip.dataset.wired='1';}
  refreshLandscapePalette();
}
function setupDismissDrag(){
  const sheet=document.querySelector('.now-playing');const grab=$('#np-grab');
  if(!sheet||sheet.dataset.drag)return;sheet.dataset.drag='1';
  let startY=0,dy=0,dragging=false,lastY=0,lastT=0,vel=0;
  const begin=y=>{dragging=true;dy=0;startY=y;lastY=y;lastT=performance.now();vel=0;sheet.style.transition='none';sheet.classList.add('dragging');};
  const move=y=>{if(!dragging)return;const now=performance.now();const dt=Math.max(1,now-lastT);vel=(y-lastY)/dt;lastY=y;lastT=now;
    dy=Math.max(0,y-startY);sheet.style.transform=`translateY(${dy}px)`;sheet.style.opacity=String(Math.max(.45,1-dy/520));};
  const end=()=>{if(!dragging)return;dragging=false;sheet.style.transition='transform .32s cubic-bezier(.18,.9,.3,1),opacity .32s ease';
    if(dy>110||dy+vel*160>190){closeWithDrop(sheet);}else{sheet.style.transform='';sheet.style.opacity='';sheet.classList.remove('dragging');}};
  sheet.addEventListener('pointerdown',e=>{const hit=e.target.closest('button,input');if(landscapePlayer.matches||hit&&!e.target.closest('#np-grab'))return;begin(e.clientY);},{passive:true});
  sheet.addEventListener('pointermove',e=>move(e.clientY),{passive:true});
  sheet.addEventListener('pointerup',end,{passive:true});
  sheet.addEventListener('pointercancel',end,{passive:true});
  if(grab){grab.addEventListener('pointerdown',e=>{e.stopPropagation();begin(e.clientY);},{passive:true});}
}
function closeWithDrop(sheet){
  sheet.classList.add('dragging');
  const ov=document.querySelector('#overlay');if(ov)ov.classList.add('dismissing');
  sheet.style.transition='transform .36s cubic-bezier(.32,.72,0,1),opacity .3s ease';
  requestAnimationFrame(()=>{sheet.style.transform='translateY(100%)';sheet.style.opacity='0';});
  setTimeout(()=>{if(sheet.isConnected)closeOverlay(true);},340);
}
function setupCommentsSwipe(){
  const page=document.querySelector('.np-page');if(!page||page.dataset.sw)return;page.dataset.sw='1';
  let x0=0,y0=0,t0=0,armed=false;
  page.addEventListener('pointerdown',e=>{if(e.target.closest('button,input'))return;x0=e.clientX;y0=e.clientY;t0=performance.now();armed=true;},{passive:true});
  page.addEventListener('pointerup',e=>{if(!armed)return;armed=false;
    const dx=e.clientX-x0,dy=e.clientY-y0,dt=performance.now()-t0;
    if(dx>60&&Math.abs(dy)<Math.abs(dx)&&dt<600){
      // 右滑 → 显示内嵌评论页（第二页），不弹浮层
      const pager=$('#np-pager');if(pager)pager.scrollTo({left:pager.clientWidth,behavior:'smooth'});
    }
  },{passive:true});
  page.addEventListener('pointercancel',()=>{armed=false;},{passive:true});
}
function setupPager(){
  const pager=$('#np-pager'),dots=$('#np-dots'),toggle=$('.np-land-controls [data-transport=comments]');
  if(!pager||!dots)return;
  pager.addEventListener('scroll',()=>{
    const i=Math.round(pager.scrollLeft/Math.max(1,pager.clientWidth));
    [...dots.children].forEach((d,n)=>d.classList.toggle('on',n===i));
    $('.now-playing')?.classList.toggle('np-comments-mode',i===1);
    if(toggle&&toggle.getAttribute('aria-pressed')!==String(i===1)){
      toggle.setAttribute('aria-pressed',String(i===1));
      toggle.setAttribute('aria-label',i===1?'显示歌词':'显示评论');
      toggle.innerHTML=icon(i===1?'lyric':'lyrics');
    }
  },{passive:true});
}
async function loadNowComments(t){const host=$('#np-comments');if(!host||!t||!t.id)return;
  try{const r=await api('/v1/resource/comments/R_SO_4_'+t.id,{limit:50,offset:0,beforeTime:0});
    if(!host.isConnected)return;
    const hot=r.hotComments||[],all=(r.comments||[]).filter(c=>!hot.some(h=>h.commentId===c.commentId));
    const list=[...hot,...all];
    host.innerHTML=list.length?('<div class="np-comments-top"><span class="cc-label">热门评论</span><span class="np-comments-count">'+count(r.total||0)+' 条评论</span></div>'+list.map(c=>'<article class="comment"><div class="row cc-item-head">'+cover(c.user?.avatarUrl,'avatar')+'<div class="stack cc-item-meta"><strong>'+e(c.user?.nickname)+'</strong><small>'+e(new Date(c.time).toLocaleDateString('zh-CN'))+'</small></div><span class="cc-like">'+icon('thumb')+(c.likedCount?count(c.likedCount):'')+'</span></div><p class="cc-text">'+e(c.content)+'</p>'+(c.beReplied&&c.beReplied[0]?('<p class="cc-reply secondary">回复 @'+e(c.beReplied[0].user?.nickname)+'：'+e(c.beReplied[0].content)+'</p>'):'')+'</article>').join('')):'<p class="np-comments-note">还没有评论</p>';
    host.scrollTop=0;
  }catch(err){if(host.isConnected)host.innerHTML='<p class="np-comments-note">评论加载失败</p>';}}
function lyricWords(line,index){
  if(!prefs.karaoke)return e(line.text);
  let words=line.words;
  if(!words?.length){
    // Like iOS, use 85% of the line (capped at six seconds) when only LRC timing exists.
    const units=(line.text.match(/[^\p{L}\p{N}]*[\p{L}\p{N}][^\p{L}\p{N}]*/gu)||[]);
    const span=Math.min(6000,(lyrics[index+1]?.at??line.at+6000)-line.at);
    if(!units.length||span<=0)return e(line.text);
    const duration=Math.max(1,span*.85/units.length);
    words=units.map((text,i)=>({text,at:line.at+i*duration,duration}));
  }
  return words.map(w=>`<span class="lyric-word" data-start="${w.at}" data-duration="${w.duration}">${e(w.text)}</span>`).join('');
}
function renderStrip(idx){const host=$('#np-strip');if(!host)return;if(!lyrics.length){host.innerHTML='<p class="sec">暂无歌词</p>';return;}
  host.innerHTML=[idx-1,idx,idx+1].filter(i=>i>=0&&i<lyrics.length).map(i=>`<p class="${i===idx?'on':''}">${i===idx?lyricWords(lyrics[i],i):e(lyrics[i].text)}</p>`).join('');}
// 歌词只有一个渲染入口：播放器页面渲染进 #np-visual，漫游横屏渲染进 #fm-lyrics（同一份 DOM 结构）。
// 只有横屏时 #fm-lyrics 才可见；竖屏它 display:none，投影目标要回落到播放器页面。
// 只有真正在漫游模式里才投影歌词；未开启时不拿别的队列的歌充数（和 iOS 一致）。
function fmLyricHost(){if(!player.fm)return null;const fm=document.querySelector('#fm-lyrics');return fm&&fm.getClientRects().length?fm:null;}
// 播放器页面与漫游横屏共用同一份行标记：同一段 map，不复制歌词逻辑。
function lyricLinesHTML(){return lyrics.length?lyrics.map((l,n)=>{const translated=translations.find(x=>Math.abs(x.at-l.at)<600);const reading=romaji.find(x=>Math.abs(x.at-l.at)<600);return button(`${prefs.annotation==='romaji'&&reading?`<small>${e(reading.text)}</small>`:''}${lyricWords(l,n)}${prefs.translation&&translated?`<small>${e(translated.text)}</small>`:''}`,()=>control('seek',{value:l.at}),`lyric-line`,'跳转至 '+l.text).replace('<button ',`<button data-line="${n}" `);}).join(''):'<p class="secondary">暂无歌词</p>';}
function renderLyrics(){const visual=$('#np-visual');if(!visual)return;visual.className='lyrics';const pg=visual.closest('.np-page');if(pg)pg.classList.add('lyrics-mode');const strip=$('#np-strip');if(strip)strip.style.display='none';
  visual.innerHTML=lyricLinesHTML();
  activeLine=-1;updateNowPlaying(true);
}
function updateNowPlaying(force=false){
  if(overlayKind!=='nowPlaying')return;const t=player.queue[player.index];if(!t)return;
  const seek=$('#seek');if(seek&&seek.dataset.dragging!=='true'){seek.max=String(player.duration||t.duration||1);seek.value=String(player.position||0);updateSeekFill(seek);$('#elapsed').textContent=time(player.position);$('#remaining').textContent=time(player.duration||t.duration);}
  if($('#np-error'))$('#np-error').textContent=player.error||player.loading?'正在加载音频…':'';
  if(player.error&&$('#np-error'))$('#np-error').textContent=player.error;
  updateNowPlayingLyrics(force);
}
function updateSeekFill(seek){seek.parentElement.style.setProperty("--seek-progress",100*Number(seek.value)/Math.max(1,Number(seek.max))+"%");}
function updateNowPlayingLyrics(force=false){
  if(overlayKind!=='nowPlaying'||!player.queue[player.index])return;
  const advancing=player.playing&&!player.loading;
  if(advancing&&!nowPlayingLyricRAF)nowPlayingLyricRAF=requestAnimationFrame(()=>{nowPlayingLyricRAF=0;updateNowPlayingLyrics();});
  const pos=advancing&&lyricSync?lyricPosition():player.position;
  const raw=currentLyric(lyrics,pos),next=Math.max(0,raw);
  if(force||next!==activeLine){
    activeLine=next;
    if(!showLyric)renderStrip(next);
    else{
      const visual=$('#np-visual');
      visual?.querySelectorAll('.lyric-line.active').forEach(n=>n.classList.remove('active'));
      const node=visual?.querySelector(`[data-line="${next}"]`);node?.classList.add('active');
      const page=node?.closest('.np-page.lyrics-mode');
      // 歌词时间戳重复/倒挂时 currentLyric 会在两行之间抖动；每帧一次 smooth 滚动
      // 会把 layout 拖死，这里限速到 180ms 一次。
      const now=Date.now();
      if(raw>=0&&page&&now-(window.__lyricScrollAt||0)>180){
        window.__lyricScrollAt=now;
        // scrollIntoView also scrolls the outer player at the end of the list.
        const row=node.getBoundingClientRect(),list=page.getBoundingClientRect();
        page.scrollTo({top:page.scrollTop+row.top-list.top+(row.height-page.clientHeight)/2,behavior:force?'instant':'smooth'});
      }
    }
  }
  const row=showLyric?$('#np-visual .lyric-line.active'):$('#np-strip p.on');
  row?.querySelectorAll('.lyric-word').forEach(w=>{
    const progress=Math.max(0,Math.min(100,(pos-Number(w.dataset.start))/Math.max(1,Number(w.dataset.duration))*100))+'%';
    if(w.style.getPropertyValue('--progress')!==progress)w.style.setProperty('--progress',progress);
  });
}
let fmLyricKey='',fmActive=-1;
function renderFmLyrics(){const host=fmLyricHost();if(!host)return;const key=`${lyricID}|${lyrics.length}`;if(key===fmLyricKey&&host.children.length)return;fmLyricKey=key;host.innerHTML=lyricLinesHTML();fmActive=-1;}
// 当前行居中 = 滚到容器竖直中点；逐字进度沿用播放器那套 --progress。
function paintFmLyrics(){const host=fmLyricHost();if(!host||!lyrics.length)return;const pos=lyricPosition();const raw=currentLyric(lyrics,pos),next=Math.max(0,raw);
  if(next!==fmActive){fmActive=next;host.querySelectorAll('.lyric-line.active').forEach(n=>n.classList.remove('active'));
    const node=host.querySelector(`[data-line="${next}"]`);if(node){node.classList.add('active');
      const hr=host.getBoundingClientRect(),ar=node.getBoundingClientRect();
      // 把这一行的中心对齐到容器中心（= 屏幕竖直中点）。
      host.scrollTo({top:host.scrollTop+(ar.top+ar.height/2)-(hr.top+hr.height/2),behavior:'smooth'});}}
  const act=host.querySelector('.lyric-line.active');
  act?.querySelectorAll('.lyric-word').forEach(w=>{const pr=Math.max(0,Math.min(100,(pos-Number(w.dataset.start))/Math.max(1,Number(w.dataset.duration))*100)).toFixed(1)+'%';if(w.style.getPropertyValue('--progress')!==pr)w.style.setProperty('--progress',pr);});
}
function openSleep(){
  const opts=[[0,'关闭定时'],[15,'15 分钟后暂停'],[30,'30 分钟后暂停'],[45,'45 分钟后暂停'],[60,'60 分钟后暂停'],[90,'90 分钟后暂停']];
  const current=Math.max(0,Math.ceil(((player.sleepAt||0)-Date.now())/60000));
  const rows=opts.map(([mins,label])=>button(`<span>${label}</span>${mins===0&&!(player.sleepAt>0)?icon('tick'):''}`,async()=>{await control('sleep',{value:mins});player.sleepAt=mins?Date.now()+mins*60000:0;closePlayPanel();toast(mins?`${mins} 分钟后暂停`:'已关闭定时');},`list-row${mins===0&&!(player.sleepAt>0)?' accent':''}`)).join('');
  openPlayPanel('sleep','睡眠定时',`<div class="group">${rows}</div><p class="group-note">到点后自动暂停播放，不会退出应用。</p>`);
}
function openQueue(){openPlayPanel('queue','播放队列',`<div class="detail-tools"><span>${player.queue.length} 首歌曲</span>${button({list:'列表循环',shuffle:'随机播放',single:'单曲循环'}[player.mode],cycleMode,'accent')}</div><div class="track-list">${player.queue.map((t,i)=>`<div class="track-row ${i===player.index?'current':''}">${button(`${cover(t.cover,'track-cover')}<span class="track-info"><strong>${e(t.name)}</strong><small>${e(t.artist)}</small></span>`,()=>{play(player.queue,i);closeOverlay();},'track-main',`播放 ${t.name}`)}${i!==player.index?round('close',async()=>{await control('remove',{value:i});player.queue.splice(i,1);if(i<player.index)player.index--;openQueue();},'从队列移除'):icon('music')}</div>`).join('')}</div>`);}
window.addEventListener('playback',({detail:s})=>{
  PlaybackLive=true;const previous=player.queue[player.index],wasPlaying=player.playing;player={...player,...s};lyricSync=Date.now();const t=player.queue[player.index];
  const trackChanged=t?.id!==previous?.id;const chromeChanged=trackChanged||wasPlaying!==player.playing;
  if(trackChanged&&t){lastTrackID=t.id;const recent=[t,...read('recents',[]).filter(x=>x.id!==t.id)].slice(0,200);write('recents',recent);if(lyricID!==t.id)loadLyrics(t.id);if(overlayKind==='nowPlaying'){$('#overlay').innerHTML=nowPlayingHTML(t);setupSeek();setupPager();setupCommentsSwipe();setupDismissDrag();loadNowComments(t);wireNowPlaying();if(showLyric)renderLyrics();}document.querySelectorAll('[data-track-id]').forEach(n=>n.classList.toggle('current',Number(n.dataset.trackId)===t.id));}
  if(trackChanged&&player.fm&&player.index>=player.queue.length-2)fmRefill();
  if(trackChanged)updatePlaylistLocator();
  // 漫游页的歌名/作者/封面都取自 player.queue[player.index]，换歌后必须整页重绘，
  // 否则歌名和作者会停在上一次渲染的那首（只补封面不够）。
  if(trackChanged&&route.kind==='fm'&&player.fm){fmLyricKey='';render();}
  if(trackChanged)refreshAmbient();
  if(chromeChanged){renderChrome();if(overlayKind==='nowPlaying'){document.querySelectorAll('.np-controls .play-main,.np-land-controls .play-main').forEach(b=>{b.innerHTML=icon(player.playing?'pause':'play');if(b.dataset.transport)b.setAttribute('aria-label',player.playing?'暂停':'播放');});$('.np-cover')?.classList.toggle('paused',!player.playing);}}
  if(player.error&&player.error!==window.lastPlaybackError){toast(player.error);window.lastPlaybackError=player.error;}if(!player.error)window.lastPlaybackError='';
  updateNowPlaying(trackChanged&&!showLyric);
  if(lyricsBar)updateLyricBar();
});
window.addEventListener('native-error',ev=>toast(ev.detail));
document.addEventListener('submit',ev=>{if(ev.target&&ev.target.id==='chat-form'){ev.preventDefault();sendChat();}},true);
document.addEventListener('click',ev=>{if(swallowLongPress())return;const button=ev.target.closest('[data-call]');if(!button||button.disabled)return;const fn=callbacks.get(button.dataset.call);if(fn)Promise.resolve().then(()=>fn(ev)).catch(errorToast);});
document.addEventListener('contextmenu',ev=>{const row=ev.target.closest('.playlist-track');if(!row)return;ev.preventDefault();const index=listTracks.findIndex(t=>t.id===Number(row.dataset.trackId));if(index>=0)trackMenu(listTracks[index],index);});
document.addEventListener('change',ev=>{const el=ev.target.closest('[data-change]');if(!el)return;const fn=callbacks.get(el.dataset.change);if(fn)Promise.resolve().then(()=>fn(ev)).catch(errorToast);});
window.addEventListener('android-back',()=>{if(route.kind===tab&&!history.length&&!overlayKind){toast('Antunes 已在前台，音乐可在后台继续播放');return;}back();});
async function boot(){applyTheme();if(!prefs.ambientOffMigrated){prefs.ambient=false;prefs.ambientOffMigrated=true;write('preferences',prefs);}
  // 搜索板块改为默认关闭：只在从没迁移过时改一次，之后用户自己开的不会被覆盖。
  // 「我的」只有在其它四个板块都关闭时才允许关闭；老数据里若出现非法组合，启动时纠正。
  if(prefs.showLibrary===false&&!othersAllOff()){prefs.showLibrary=true;write('preferences',prefs);}
  if(!prefs.searchOffMigrated){prefs.showSearch=false;prefs.searchOffMigrated=true;write('preferences',prefs);}if(!prefs.losslessDefault){prefs.losslessDefault=true;if(prefs.quality==='exhigh')prefs.quality='lossless';savePrefs();}if(!prefs.downloadQuality)prefs.downloadQuality='lossless';try{native('quality',{value:prefs.quality}).catch(()=>{});const status=await native('status');loggedIn=status.loggedIn;const restored=await native('state');player={...player,...restored};player.fm=!!prefs.fm&&!!(player.queue&&player.queue[player.index]);const cur0=player.queue&&player.queue[player.index];if(cur0){loadLyrics(cur0.id);if(player.position>0)control('seek',{value:player.position});}await native('quality',{value:prefs.quality});await native('downloadQuality',{value:prefs.downloadQuality});await native('eq',{bands:prefs.eqBands,enabled:prefs.eqEnabled});try{(await native('downloads')).forEach(t=>downloaded.add(String(t.id)));}catch{}if(loggedIn)loadAccount().then(()=>{if(['library','home','rank','messages','chat'].includes(route.kind))render();}).catch(errorToast);await render();}catch(err){$('#page').innerHTML=header('Antunes')+empty('启动失败',err.message,'wifi',button('重试',boot,'primary'));}}
boot();

// 顶栏歌单名：等导航条和「播放全部」那行吸附成一块之后才显示，
// 和 iOS 端「两部分合并才显示歌单名」是同一个判定。
let navMergeFrame=0;
function watchPlaylistNavMerged(){
  const page=$('#page');
  if(page.dataset.navMergeWatch==='1')return;
  page.dataset.navMergeWatch='1';
  const sync=()=>{
    navMergeFrame=0;
    const nav=page.querySelector('.playlist-nav'),actions=page.querySelector('.playlist-actions');
    if(!nav||!actions)return;
    const merged=actions.getBoundingClientRect().top<=nav.getBoundingClientRect().bottom+0.5;
    nav.classList.toggle('merged',merged);
  };
  // 横屏页级不滚，滚动发生在两栏里；scroll 不冒泡但能捕获，所以用捕获阶段监听整页。
  page.addEventListener('scroll',()=>{if(!navMergeFrame)navMergeFrame=requestAnimationFrame(sync);},{passive:true,capture:true});
}
