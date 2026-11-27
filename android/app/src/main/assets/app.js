import {escapeHTML as e,imageURL,applyPlaylistOrder,movePlaylistTrack,track,uniqueTracks,preserveTrackCovers,time,count,parseLyrics,parseVerbatim,currentLyric,categories,navigationTabs} from './core.mjs';
const $=s=>document.querySelector(s);
const icons={reorder:'<path d="M5 6h14M5 12h14M5 18h14"/>',home:'<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z"/>',fm:'<circle cx="12" cy="12" r="2"/><path d="M7 7a7 7 0 0 0 0 10m10-10a7 7 0 0 1 0 10M4 4a11.3 11.3 0 0 0 0 16M20 4a11.3 11.3 0 0 1 0 16"/>',grid:'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',user:'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="9" r="3"/><path d="M5 18a7 7 0 0 1 14 0"/>',search:'<circle cx="10.7" cy="10.7" r="7.7"/><path d="m16.3 16.3 5 5"/>',gear:'<path d="m9 3-.5 2.1-1.5.9-2.1-.6-2 3.4 1.6 1.5v1.8L3 13.6 5 17l2.1-.6 1.5.9L9 20h4l.5-2.7 1.5-.9 2.1.6 2-3.4-1.6-1.5v-1.8l1.6-1.5-2-3.4-2.1.6-1.5-.9L13 3z"/><circle cx="11" cy="11.5" r="3"/>',music:'<path d="M9 18V5l11-2v13M9 8l11-2"/><ellipse cx="5.5" cy="18" rx="3.5" ry="3"/><ellipse cx="16.5" cy="16" rx="3.5" ry="3"/>',play:'<path d="m8 4 12 8-12 8z" fill="currentColor" stroke="none"/>',pause:'<path d="M7 4h4v16H7zM15 4h4v16h-4z" fill="currentColor" stroke="none"/>',next:'<path d="m4 5 11 7L4 19zM18 5v14" fill="currentColor"/>',previous:'<path d="m20 5-11 7 11 7zM6 5v14" fill="currentColor"/>',heart:'<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8z"/>',download:'<circle cx="12" cy="12" r="9"/><path d="M12 6v11m-4-4 4 4 4-4"/>',clock:'<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/>',star:'<path d="m12 2 3.1 6.3 6.9 1-5 4.9 1.2 6.8-6.2-3.2L5.8 21 7 14.2 2 9.3l6.9-1z"/>',cloud:'<path d="M6 19a5 5 0 0 1-1-9.9 7 7 0 0 1 13.6-1A5.5 5.5 0 0 1 18 19z"/>',calendar:'<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 2v6m10-6v6M3 11h18M8 15h3m2 0h3m-8 3h3"/>',back:'<path d="m15 4-8 8 8 8"/>',chevron:'<path d="m9 5 7 7-7 7"/>',down:'<path d="m5 9 7 7 7-7"/>',up:'<path d="m5 15 7-7 7 7"/>',upTo:'<path d="M12 20V7m-5 5 5-5 5 5M5 4h14"/>',downTo:'<path d="M12 4v13m-5-5 5 5 5-5M5 20h14"/>',close:'<path d="m6 6 12 12M18 6 6 18"/>',more:'<circle cx="5" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="19" cy="12" r="1" fill="currentColor"/>',plus:'<path d="M12 4v16M4 12h16"/>',shuffle:'<path d="m3 5 3 0 12 14h3m-4-4 4 4-4 4M3 19h3l5-6m3-5 4-3h3m-4-4 4 4-4 4"/>',repeat:'<path d="m17 2 4 4-4 4M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4 4-4m14-1v2a3 3 0 0 1-3 3H3"/>',queue:'<path d="M3 5h18M3 10h18M3 15h10M3 20h10m4-5 5 3-5 3z"/>',lyrics:'<rect x="3" y="3" width="18" height="16" rx="3"/><path d="m7 19-3 3v-5M7 8h10M7 13h7"/>',lyric:'<path d="M4 6a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v7a3 3 0 0 1-3 3h-5l-5 3.5V16H7a3 3 0 0 1-3-3V6Z"/><path d="M9.6 7.2c-.75.5-1.2 1.25-1.2 2.1 0 .72.5 1.2 1.18 1.2.68 0 1.16-.48 1.16-1.16 0-1-.56-1.73-1.14-2.14Zm4.6 0c-.75.5-1.2 1.25-1.2 2.1 0 .72.5 1.2 1.18 1.2.68 0 1.16-.48 1.16-1.16 0-1-.56-1.73-1.14-2.14Z" fill="currentColor" stroke="none"/>',check:'<path d="m5 12 4 4L19 6"/><circle cx="12" cy="12" r="10"/>',circle:'<circle cx="12" cy="12" r="9"/>',trash:'<path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7m4-7v7"/>',album:'<rect x="3" y="3" width="18" height="18" rx="4"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>',artist:'<path d="M8 14 3 21l7-5m0-3 4 4"/><ellipse cx="15.5" cy="8.5" rx="5" ry="6" transform="rotate(45 15.5 8.5)"/>',menu:'<path d="M4 7h16M4 12h16M4 17h16"/>',select:'<circle cx="12" cy="12" r="9"/><path d="m8 12.2 2.7 2.8L16 9.4"/>',plusList:'<path d="M4 6h9M4 12h9M4 18h6"/><path d="M18 10v9M13.5 14.5h9"/>',tick:'<path d="m5 12.6 4.2 4.2L19 6.8" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',starOutline:'<path d="m12 3.6 2.7 5.6 6.1.9-4.4 4.3 1 6-5.4-2.9-5.4 2.9 1-6L3.2 10.1l6.1-.9z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>',eq:'<path d="M5 3v7m0 4v7M12 3v13m0 4v1M19 3v2m0 4v12M2 10h6m1 6h6m1-11h6"/>',wifi:'<path d="M2 8a17 17 0 0 1 20 0M5 12a12 12 0 0 1 14 0M8.5 16a6 6 0 0 1 7 0"/><circle cx="12" cy="20" r="1" fill="currentColor"/>'};
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
  'avatar-button-img':96,'playlist-thumb':128,'fm-cover':384,'fm-art':384,'playlist-cover':512,
  'detail-cover':512,'explore-cover':576,'collection-hero-image':960,'np-land-art':640};
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
const COLLECTION_FALLBACK={primary:[43,39,47],secondary:[245,225,251],isLight:false};
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
const collectionPaletteKey=(url,aspect,style)=>`collection|${aspect}|${style}|${url}`;
async function ambientPaletteFor(url,collectionAspect=0,style='gradient'){
  const key=collectionAspect?collectionPaletteKey(url,collectionAspect,style):url;
  const hit=ambientPalette.get(key);
  if(hit)return hit;
  const image=new Image();
  image.crossOrigin='anonymous';
  image.decoding='async';
  await new Promise((resolve,reject)=>{image.onload=()=>resolve();image.onerror=()=>reject(new Error('封面无法采样'));image.src=url;});
  const size=10, canvas=document.createElement('canvas');
  canvas.width=canvas.height=size;
  const context=canvas.getContext('2d',{willReadFrequently:true});
  let collectionCrop;
  if(collectionAspect){
    const w=image.naturalWidth,h=image.naturalHeight,aspect=collectionAspect/100;
    const visibleWidth=Math.min(w,h*aspect),visibleHeight=Math.min(h,w/aspect);
    const x=(w-visibleWidth)/2,y=(h-visibleHeight)/2;
    context.drawImage(image,x,y+visibleHeight*.78,visibleWidth,visibleHeight*.22,0,0,size,size);
    collectionCrop=[x,y,visibleWidth,visibleHeight];
  }else context.drawImage(image,0,0,size,size);
  const data=context.getImageData(0,0,size,size).data;
  if(collectionAspect){
    context.clearRect(0,0,size,size);
    context.drawImage(image,...collectionCrop,0,0,size,size);
    const heroSamples=context.getImageData(0,0,size,size).data;
    let colors=collectionEdgeColors(data,style==='gradientDimmed');
    if(style==='gradientFlow'){
      const edgeSize=32;
      canvas.width=canvas.height=edgeSize;
      context.drawImage(image,...collectionCrop,0,0,edgeSize,edgeSize);
      const flowEdges=collectionFlowEdges(context.getImageData(0,0,edgeSize,edgeSize).data,edgeSize,COLLECTION_FALLBACK.primary);
      colors={...collectionEdgeColors(flowEdges.flat().flatMap(rgb=>[...rgb,255])),flowEdges};
    }
    colors={...colors,heroAccent:collectionHeroAccent(heroSamples,colors.primary.map(v=>v/255))};
    if(ambientPalette.size>200)ambientPalette.clear();
    ambientPalette.set(key,colors);
    return colors;
  }
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
  ambientPalette.set(key,colors);
  return colors;
}
function collectionFlowEdges(data,size,fallback){
  // Top/right/bottom/left, each in screen order so the field stays anchored to the crop.
  return Array.from({length:4},(_,edge)=>Array.from({length:8},(_,part)=>{
    const sums=[0,0,0];let alpha=0;
    for(let i=part*size/8;i<(part+1)*size/8;i++)for(let j=0;j<Math.max(1,size/16);j++){
      const x=edge===1?size-1-j:edge===3?j:i,y=edge===0?j:edge===2?size-1-j:i;
      const k=(y*size+x)*4,a=data[k+3];
      if(a<=25)continue;
      for(let c=0;c<3;c++)sums[c]+=data[k+c]*a;
      alpha+=a;
    }
    return alpha?sums.map(sum=>sum/alpha):fallback;
  }));
}
function collectionFlowColor(edges,u,v,isLight){
  const clamp=x=>Math.max(0,Math.min(1,x));
  const outward=[-v,u-1,v-1,-u],outside=outward.some(d=>d>0);
  const rgb=[0,0,0];let total=0;
  for(let edge=0;edge<4;edge++){
    // Outside the cover, only the facing edge(s) contribute; two edges meet at a corner.
    const d=outward[edge],weight=outside?Math.max(0,d):1/(.035-d)**3;
    if(!weight)continue;
    const along=edge%2?v:u,drift=along>0&&along<1?1-Math.exp(-Math.max(0,d)*.85):0;
    const t=clamp(along+drift*(.21*Math.sin(7.5*drift+along*2.4)+(edge%2?.08:-.08)));
    const index=Math.max(0,Math.min(edges[edge].length-1,t*edges[edge].length-.5)),lo=Math.floor(index),hi=Math.min(lo+1,edges[edge].length-1);
    const fraction=index-lo,blend=fraction*fraction*(3-2*fraction);
    for(let c=0;c<3;c++)rgb[c]+=(edges[edge][lo][c]*(1-blend)+edges[edge][hi][c]*blend)*weight;
    total+=weight;
  }
  const linear=rgb.map(value=>{const s=value/(total*255);return s<=.04045?s/12.92:((s+.055)/1.055)**2.4;});
  const light=.2126*linear[0]+.7152*linear[1]+.0722*linear[2];
  const lift=isLight&&light<.37?(.37-light)/(1-light):0,scale=!isLight&&light>.14?.14/light:1;
  return linear.map(value=>{const x=value*scale*(1-lift)+lift;return Math.round(255*(x<=.0031308?12.92*x:1.055*x**(1/2.4)-.055));});
}
function collectionEdgeColors(data,dimmed=false){
  const sums=[0,0,0];let weight=0;
  for(let i=0;i<data.length;i+=4){
    const a=data[i+3]/255;if(a<=.1)continue;
    for(let channel=0;channel<3;channel++)sums[channel]+=data[i+channel]*a;
    weight+=255*a;
  }
  if(!weight)return COLLECTION_FALLBACK;
  const edge=sums.map(v=>v/weight);
  if(dimmed){
    const peak=Math.max(...edge),scale=peak>.40?.40/peak:1,lift=Math.max(0,.12-peak);
    return {primary:edge.map(v=>Math.round((v*scale+lift)*255)),
            secondary:edge.map(v=>Math.round((.68+v*.32)*255)),isLight:false};
  }
  const base=collectionLuminance(edge),isLight=base>.179,ink=isLight?0:1;
  const tint=edge.map(v=>v*.18+ink*.82),light=collectionLuminance(tint);
  const contrast=(Math.max(base,light)+.05)/(Math.min(base,light)+.05);
  return {primary:edge.map(v=>Math.round(v*255)),
          secondary:(contrast>=4.55?tint:[ink,ink,ink]).map(v=>Math.round(v*255)),isLight};
}
function collectionLuminance(rgb){
  return rgb.map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4)
    .reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0);
}
function collectionHeroAccent(data,background){
  // Ignore near-neutral pixels; keep as much cover color as the large-title/icon contrast allows.
  const sums=[0,0,0];let weight=0;
  for(let i=0;i<data.length;i+=4){
    const alpha=data[i+3]/255;
    if(alpha<=.1)continue;
    const rgb=[data[i]/255,data[i+1]/255,data[i+2]/255];
    const chroma=Math.max(...rgb)-Math.min(...rgb);
    if(chroma<.08)continue;
    const w=alpha*chroma*chroma;
    for(let c=0;c<3;c++)sums[c]+=rgb[c]*w;
    weight+=w;
  }
  if(!weight)return null;
  const seed=sums.map(v=>v/weight),base=collectionLuminance(background),ink=base>.179?0:1;
  const tint=t=>seed.map(v=>Math.round((ink*(1-t)+v*t)*255));
  let low=0,high=.85;
  for(let i=0;i<10;i++){
    const mid=(low+high)/2,light=collectionLuminance(tint(mid).map(v=>v/255));
    if((Math.max(base,light)+.05)/(Math.min(base,light)+.05)>=3.65)low=mid;
    else high=mid;
  }
  return tint(low);
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
  const id=String(++requestID);const timeout=setTimeout(()=>{pending.delete(id);reject(new Error(operation==='download'?'下载超时，请检查已下载列表':'操作超时，请重试'));},['download','pickPlaylistCover'].includes(operation)?300000:operation==='updatePlaylistCover'?90000:45000);
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
  if(!Object.hasOwn(saved,'collectionCoverStyleLandscape')){
    saved.collectionCoverStyleLandscape=saved.collectionCoverStyle??'classic';
  }
  // Preserve the old shared flow choice in landscape before normalizing portrait.
  if(saved.collectionCoverStyle==='gradientFlow')saved.collectionCoverStyle='gradient';
  if(Object.hasOwn(saved,'playerMode')){delete saved.playerMode;write('preferences',saved);}
  return saved;
}
// 音质档位：level 值直接发给 /song/enhance/player/url/v1。
let prefs={collectionCoverStyle:'classic',glassStyle:'native',tabLabels:false,lyricBar:true,lyricAlignMode:'center',showLibrary:true,startTab:'library',tabOrder:['showHome','showExplore','showFM','showSearch','showLibrary'],showHome:true,showExplore:true,showSearch:false,showFM:true,librarySearch:true,libraryOrder:['liked','daily','recents','collections','downloads','cloud'],libLiked:true,libDaily:true,libRecents:true,libCollections:true,libDownloads:true,libCloud:true,appearance:'system',quality:'exhigh',downloadQuality:'exhigh',downloadSort:'name',translation:true,karaoke:true,annotation:'none',ambient:false,ambientIntensity:1,libCreatedLists:true,libCollectedLists:true,showLikedInCreated:false,artworkLink:true,eqEnabled:false,eqBands:Array(10).fill(0),losslessDefault:true,...readPreferences()};
let account=null,loggedIn=false,liked=new Set(),downloaded=new Set(),playlists=[],tab=(function(){const list=navigationTabs(prefs);const want=prefs.startTab;return (want&&want!=='auto'&&list.some(([k])=>k===want))?want:list[0][0];})(),route={kind:tab},history=[],renderID=0,overlayKind='',overlayHistory=[],overlayTimer=null;
let player={queue:[],index:0,playing:false,loading:false,position:0,duration:0,mode:'list',error:''},lastTrackID=0,lyrics=[],translations=[],romaji=[],lyricID=0,activeLine=-1,showLyric=false,lyricsBar=prefs.lyricBar!==false,lyricRAF=0,lyricSync=0,tabsExpanded=false;
const cache=new Map();let listTracks=[],detail=null,searchQuery='',searchType=1,category='全部',exploreItems=[],exploreOffset=0,exploreMore=false,queryTimer=null;
function toast(message){const node=$('#toast');node.textContent=message;node.classList.add('visible');clearTimeout(toast.timer);toast.timer=setTimeout(()=>node.classList.remove('visible'),3500);}
function errorToast(error){toast(error?.message||'操作失败，请重试');}
function applyTheme(){if(!['off','clear','frost','native'].includes(prefs.glassStyle)){prefs.glassStyle='native';write('preferences',prefs);}document.documentElement.dataset.glass=prefs.glassStyle;const dark=prefs.appearance==='dark'||prefs.appearance==='system'&&matchMedia('(prefers-color-scheme:dark)').matches;document.documentElement.dataset.tabLabels=prefs.tabLabels?'on':'off';document.documentElement.dataset.theme=dark?'dark':'light';native('theme',{dark:$('#page')?.classList.contains('gradient-collection-page')?$('#page').dataset.collectionTone!=='light':dark}).catch(()=>{});refreshAmbient();}
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
  if(!lyricsBar){lyricRAF=0;return;}
  now=now||performance.now();
  const morphing=Date.now()<chromeMorphUntil;
  // 换排检测：10Hz 足够（最短一排也有几百毫秒）。
  const tick=now-lyricLastTick>=LYRIC_TICK_MS;
  if(tick){
    lyricLastTick=now;
    if(lyricsBar)updateLyricBar();
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
  if(!mini){root.style.removeProperty('--player-edge');root.style.removeProperty('--player-left');root.style.removeProperty('--player-top');root.style.removeProperty('--player-bottom');playerEdge=0;return;}
  const r=mini.getBoundingClientRect();
  const left=Math.round(r.left),right=Math.round(r.right),top=Math.round(r.top),bottom=Math.round(r.bottom);
  // 横屏漫游的封面方框：左右取播放控制器两缘，上缘取「漫游」二字的下沿。
  const h1=document.querySelector('#page .header h1');
  const fmTop=h1?Math.round(h1.getBoundingClientRect().bottom+8):0;
  const key=[right,left,top,bottom,fmTop].join(',');
  if(key===playerEdge)return;
  playerEdge=key;
  root.style.setProperty('--player-edge',right+'px');
  root.style.setProperty('--player-right',right+'px');
  root.style.setProperty('--player-left',left+'px');
  root.style.setProperty('--player-top',top+'px');
  root.style.setProperty('--player-bottom',bottom+'px');
  if(fmTop)root.style.setProperty('--fm-top',fmTop+'px');
  const boxW=Math.max(0,right-left),boxH=Math.max(0,top-fmTop);
  if(boxW&&boxH)root.style.setProperty('--fm-cover',Math.max(48,Math.round(Math.min(boxW,boxH)*0.88))+'px');
}
addEventListener('resize',syncPlayerEdge);
$('#chrome').addEventListener('transitionend',ev=>{
  if(ev.propertyName==='transform'&&ev.target.matches('.mini'))syncPlayerEdge();
});
// 横竖屏 / 窗口宽度一变就整页重排：分栏、卡片宽度都是渲染时按当时的视口算的，
// 光靠 CSS 媒体查询只能改样式、改不了 DOM 结构（例如听歌排行横屏的两列）。
let layoutSignature=layoutSignatureNow();
function layoutSignatureNow(){
  const landscape=isCollectionLandscape();
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
  if(key!==chromeKey){chromeKey=key;chrome.innerHTML=(t?`<div class="mini glass" ${bind(()=>openNowPlaying(true))}>${button(cover(t.cover,'mini-cover'),()=>openNowPlaying(true),'','打开正在播放')}${button(`<strong>${e(t.name)}</strong><small>${e(t.artist)}</small>`,()=>openNowPlaying(true),'mini-info','打开正在播放')}${round(player.fm?'trash':'previous',()=>player.fm?fmTrash():control('previous'),player.fm?'不喜欢，换一首':'上一首')}${round(player.playing?'pause':'play',()=>control('toggle'),'播放或暂停','mini-toggle')}${round('next',()=>control('next'),'下一首')}${round('queue',openQueue,'播放列表','mini-queue')}</div>`:'')+`<div class="bar-row${lyricsBar&&t?' has-lyric':''}${lyricsBar&&t&&tabsExpanded&&tabs.length>=4?' lyric-as-word':''}">`+(t&&lyricsBar?(tabsExpanded&&tabs.length>=4?button('<span class="lyric-glyph">词</span>',()=>toggleNav(false),'round lyric-collapsed glass','展开歌词'):`<div class="lyric-row"><div class="lyric-bar glass"><div class="lyric-viewport"><div class="lyric-track"></div></div></div></div>`):'')+(showNavigation?(lyricsBar&&t&&!tabsExpanded?button((tabs.length===1&&tabs[0][0]!=='library')?`<span class="avatar-button-icon">${icon(tabs[0][2])}</span>`:(account?.avatarUrl||prefs.avatarUrl?cover(account?.avatarUrl||prefs.avatarUrl,'avatar-button-img'):`<span class="avatar-button-icon">${icon('user')}</span>`),()=>toggleNav(true),'avatar-button glass','展开导航'):`<div class="tab-row"><nav class="tabs glass" aria-label="主导航" style="--tab-count:${tabs.length}">${tabs.map(([key,label,name])=>button(icon(key==='library'?'navUser':name,(key==='search'||key==='fm')?'nav-line':'')+`<span>${label}</span>`,()=>switchTab(key),`tab ${tab===key?'active':''}`,label)).join('')}</nav></div>`):'')+`</div>`+(selecting&&listTracks.length?selectBar(listTracks):'');}
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
  if(lyricsBar&&!lyricRAF)lyricRAF=requestAnimationFrame(lyricFrame);
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
  loggedIn=signedIn;account=null;liked.clear();playlists=[];cache.clear();albumFavorites.clear();
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
  const ticket=++renderID,session=sessionGeneration;const page=$('#page');if(!usesGradientCover()||!['playlist','album'].includes(route.kind))syncCollectionSystemBars();const samePlaylist=route.kind==='playlist'&&page.dataset.route==='playlist'&&detail?.id===route.id;page.dataset.route=route.kind;if(!samePlaylist)page.scrollTop=0;page.className=['library'].includes(route.kind)?'grouped':'';renderChrome();watchPlaylistNavMerged();
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
      case 'downloads':content=await downloadsPage();break;
      case 'cloud':if(!loggedIn)content=header(title)+loginPrompt();else{const r=await api('/cloud/get',{limit:200,offset:0});listTracks=uniqueTracks((r.data||[]).map(x=>x.simpleSong||x));content=header(title)+(listTracks.length?songPageTools()+tracksHTML(listTracks):empty('音乐云盘为空'));}break;
      case 'collections':content=await collectionsPage();break;
      case 'rank':content=await rankPage();break;
      case 'messages':content=await messagesPage();break;
      case 'chat':content=await chatPage();break;
    }
    if(ticket!==renderID||session!==sessionGeneration)return;page.innerHTML=content;page.classList.toggle('has-track',!!player.queue[player.index]);
    if(route.kind==='album'&&usesGradientCover()){setupPlaylistSearch();applyCollectionPalette(page);}
    if(route.kind==='search'){setupSearch();void updateSearch(ticket);}
    if(route.kind==='chat')scrollChatToLatest(page);
    if(route.kind==='fm'){fmLyricKey='';updateFmPlaybackLyrics();}
  }catch(err){if(ticket!==renderID||session!==sessionGeneration)return;page.innerHTML=header(title)+empty('加载失败',err.message,'wifi',button('重试',()=>render(),'muted-button'));}
}
function card(item,kind='playlist',coverClass=''){
  const pic=item.coverImgUrl||item.picUrl||item.img1v1Url||item.coverUrl||'';
  const subtitle=kind==='album'?item.artist?.name||(item.artists||[]).map(x=>x.name).join(' / '):item.copywriter||'';
  return button(`<div class="artwork">${cover(pic,coverClass)}${item.playCount?`<span class="play-count">${icon('play')}${count(item.playCount)}</span>`:''}</div><div class="card-title">${e(item.name)}</div>${subtitle?`<div class="card-subtitle">${e(subtitle)}</div>`:''}`,()=>navigate({kind,id:item.id}),`card ${kind}`,item.name);
}
// 首页「推荐」的板块：与 /homepage/block/page 下发的 block 一一对应，顺序固定；
// 「根据你听过的热门节目推荐」（电台）不展示。
const HOME_SLOTS=['recommendedPlaylists','recentlyTrending','tailoredRecommendation','charts','personalPlaylists','radarPlaylists','regionalHits','likedSongRoaming','likedSongRecommendations'];
const HOME_SLOT_TITLES={recommendedPlaylists:'推荐歌单',recentlyTrending:'近期云村热播',tailoredRecommendation:'根据你的口味为你推荐',charts:'排行榜',personalPlaylists:'你的歌单',radarPlaylists:'雷达歌单',regionalHits:'最近的热门歌曲',likedSongRoaming:'从你喜欢的歌开始漫游',likedSongRecommendations:'根据你喜爱的歌曲推荐'};
const HOME_CARD_TITLES={daily:'每日推荐',privateFM:'私人漫游',heartbeat:'心动模式'};
const HOME_EXTRA_TITLES={newAlbums:'新碟上架',topArtists:'推荐歌手'};
const homeSectionKey=slot=>'home.section.'+slot;
const homeSectionEnabled=slot=>prefs[homeSectionKey(slot)]!==false;
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
function fmPage(){
  const head=header('漫游');
  if(!loggedIn)return head+`<div class="fm-empty">${loginPrompt('登录后开启私人漫游','根据你的口味，发现下一首好音乐','fm')}</div>`;
  const t=player.fm?player.queue[player.index]:null;
  const src=imageURL(t?.cover,coverSize('fm-cover'));
  return head+`<div class="fm-content${player.fm?'':' fm-idle'}" data-fm-track="${e(t?.id??'')}">
    <div class="fm-cover" data-artwork="${e(src)}">${cover(t?.cover,'fm-art')}</div>
    <div class="stack fm-meta"><h2>${e(t?.name??'私人漫游')}</h2><p class="secondary">${e(t?.artist??'根据你的口味漫游好音乐')}</p></div>
    ${player.fm?`<div class="fm-controls">${round('trash',fmTrash,'不喜欢，换一首')}${button(icon(player.playing?'pause':'play'),()=>control('toggle'),'play-main',player.playing?'暂停':'播放')}${round('next',async()=>{if(player.index>=player.queue.length-1)await startFM();else control('next');},'下一首')}${round('heart',()=>likeTrack(player.queue[player.index]),'喜欢','accent')}</div><div class="fm-lyrics" id="fm-lyrics"></div>`:button(icon('fm')+' 开始漫游',startFM,'primary pill')}
    </div>`;
}
const fmMotion=()=>!matchMedia('(prefers-reduced-motion: reduce)').matches;
let fmArtworkTicket=0;
async function updateFmArtwork(host,url){
  const src=imageURL(url,coverSize('fm-cover'));
  if(host.dataset.artwork===src)return;
  host.dataset.artwork=src;
  const ticket=++fmArtworkTicket;
  const old=host.lastElementChild;
  if(src&&old?.getAttribute('src')===src)return;
  let next;
  if(src){
    next=new Image();
    next.alt='';next.referrerPolicy='no-referrer';next.src=src;
    try{await next.decode();}catch{next=null;}
  }
  if(!host.isConnected||ticket!==fmArtworkTicket)return;
  if(!next){next=document.createElement('span');next.className='placeholder';next.innerHTML=icon('music');}
  // 新图解码前不碰旧封面；淡入时旧封面保持不透明，避免露出底色。
  host.replaceChildren(...(old?[old]:[]));
  host.append(next);
  if(old&&fmMotion()){
    next.animate([{opacity:0},{opacity:1}],{duration:240,easing:'ease-out'}).finished.then(()=>old.remove(),()=>{});
  }else old?.remove();
}
function syncFmPage(){
  if(route.kind!=='fm'||!loggedIn)return;
  const stage=$('#page .fm-content');
  if(!stage||stage.classList.contains('fm-idle')===!!player.fm){render();return;}
  const t=player.queue[player.index];
  if(!player.fm||!t)return;
  if(stage.dataset.fmTrack!==String(t.id)){
    stage.dataset.fmTrack=String(t.id);
    const meta=stage.querySelector('.fm-meta');
    meta.querySelector('h2').textContent=t.name;
    meta.querySelector('p').textContent=t.artist;
    if(fmMotion())meta.animate([{opacity:.65},{opacity:1}],{duration:240,easing:'ease-out'});
    void updateFmArtwork(stage.querySelector('.fm-cover'),t.cover);
  }
  const toggle=stage.querySelector('.play-main'),label=player.playing?'暂停':'播放';
  if(toggle.getAttribute('aria-label')!==label){
    toggle.setAttribute('aria-label',label);
    toggle.innerHTML=icon(player.playing?'pause':'play');
  }
}
async function startFM(){
  if(!accountOwner()){openLogin();return;}
  const intent=++playbackIntent,session=sessionGeneration;
  try{
    const r=await api('/v1/radio/get');
    if(intent!==playbackIntent||session!==sessionGeneration)return;
    if(!await play(r.data||[],0,intent,{fm:true}))return;
    syncFmPage();
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
  const cards=signedIn?[
    ['daily','每天 30 首，发现好音乐','calendar',()=>navigate({kind:'daily'})],
    ['privateFM','根据你的口味漫游好音乐','fm',()=>switchTab('fm')],
    ['heartbeat','从喜欢的歌开始','heart',startHeart],
  ].filter(([slot])=>homeSectionEnabled(slot)):[];
  let left=cards.length?`<section class="section"><div class="shelf feature-shelf">${cards.map(([slot,sub,name,fn])=>button(`${icon(name)}<strong>${HOME_CARD_TITLES[slot]}</strong><small>${sub}</small>`,fn,'feature')).join('')}</div></section>`:'';
  sections=sections.filter(({slot})=>homeSectionEnabled(slot));
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
  if(homeSectionEnabled('newAlbums'))right+=shelf(HOME_EXTRA_TITLES.newAlbums,values[2]?.albums||[],'album');
  if(homeSectionEnabled('topArtists'))right+=shelf(HOME_EXTRA_TITLES.topArtists,(values[3]?.list?.artists||values[3]?.artists||[]).slice(0,6),'artist');
  if(!signedIn)left+='<p class="home-login-hint">部分功能需登录后完全显示。</p>';
  html+=`<div class="home-cols"><div class="home-col">${left}</div><div class="home-col">${right}</div></div>`;
  return html;
}
async function explorePage(append=false){
  const selected=category,ticket=renderID;
  const key='explore-'+selected;
  let r=append?null:cache.get(key);
  if(!r){
    let path='/playlist/list',payload={cat:selected,order:'hot',limit:50,offset:append?exploreOffset:0,total:true};
    if(selected==='排行榜'){path='/toplist';payload={};}
    if(selected==='推荐歌单'){path='/personalized/playlist';payload={limit:100};}
    if(selected==='精品歌单'){path='/playlist/highquality/list';payload={cat:'全部',limit:50,lasttime:append?exploreOffset:0};}
    r=await api(path,payload);if(!append)cache.set(key,r);
  }
  if(selected!==category||ticket!==renderID)return '';
  const incoming=r.playlists||r.result||r.list||[];
  exploreItems=append?[...exploreItems,...incoming.filter(x=>!exploreItems.some(p=>p.id===x.id))]:incoming;
  exploreOffset=selected==='精品歌单'?(r.lasttime||0):exploreItems.length;
  exploreMore=!!r.more&&selected!=='推荐歌单'&&selected!=='排行榜';
  return header('精选')+`<div class="chips" role="tablist">${categories.map(c=>button(e(c),()=>{category=c;render();},`chip ${selected===c?'active':''}`,c)).join('')}</div><div class="grid">${exploreItems.map(x=>card(x,'playlist','explore-cover')).join('')}</div>`+(exploreMore?button('加载更多',async()=>{try{const html=await explorePage(true);if(html&&route.kind==='explore'&&selected===category){const y=$('#page').scrollTop;$('#page').innerHTML=html;$('#page').scrollTop=y;}}catch(err){errorToast(err);}},'load-more'):'');
}
function trackRow(t,i,items,numbered=false,queue=false){
  const current=t.id===player.queue[player.index]?.id;
  return `<div class="track-row ${current?'current':''}" data-track-id="${t.id}">${button(`${numbered?`<span class="track-number">${current?icon('music'):i+1}</span>`:cover(t.cover,'track-cover')}<span class="track-info"><strong>${e(t.name)}</strong><small>${t.fee===1?'<span class="vip">VIP</span>':''}${e(t.artist)}${t.album?.name?' · '+e(t.album.name):''}${t.bytes?' · '+sizeText(t.bytes):''}${t.quality?` · ${e(qualityName(t.quality))}`:''}</small></span>`,()=>queue?play(player.queue,i):play(items,i),'track-main',`播放 ${t.name}`)}${round('more',()=>trackMenu(t,i),'歌曲菜单')}</div>`;
}

const DOWNLOAD_SORTS=[['name','按名称'],['size','按大小'],['newest','从新到旧'],['oldest','从旧到新']];
async function downloadsPage(){
  const raw=(await native('downloads')).map(x=>({...track(x),bytes:x.bytes,quality:x.quality||'',downloadedAt:x.downloadedAt||0}));
  const order=prefs.downloadSort||'name';
  const sorted=raw.slice().sort((a,b)=>{
    if(order==='size')return (b.bytes||0)-(a.bytes||0);
    if(order==='newest')return (b.downloadedAt||0)-(a.downloadedAt||0);
    if(order==='oldest')return (a.downloadedAt||0)-(b.downloadedAt||0);
    return String(a.name).localeCompare(String(b.name),'zh-Hans-CN');
  });
  const chips=DOWNLOAD_SORTS.map(([k,label])=>button(label,()=>{prefs.downloadSort=k;savePrefs();render();},`chip ${order===k?'active':''}`)).join('');
  const body=sorted.length?songPageTools()+tracksHTML(sorted):empty('还没有下载歌曲','在歌曲菜单中选择下载，离线时也能播放。','download');
  return header(route.name||'已下载',round('gear',openStorage,'存储空间'))+`<div class="chip-row download-sort">${chips}</div>`+body;
}
function qualityName(q){if(!q)return '';if(q==='local')return '本地';const hit=(typeof QUALITY_OPTIONS!=='undefined'?QUALITY_OPTIONS:[]).find(x=>x[0]===q);if(hit)return hit[1];return String(q).toUpperCase();}
function tracksHTML(items,numbered=false){if(!items.length)return empty('暂无歌曲');return `<div class="track-list">${items.map((t,i)=>trackRow(t,i,items,numbered)).join('')}</div>`;}
function playlistOrderKey(id){
  const owner=loggedIn?account?.userId:'guest';
  return owner!=null?'playlistOrder.'+owner+'.'+id:null;
}
function commitPlaylistMove(id,anchor,after,playlistID=route.id){
  if(route.kind!=='playlist'||route.id!==playlistID||!selecting||detail?.id!==playlistID)return;
  const key=playlistOrderKey(playlistID);if(!key)return;
  const next=movePlaylistTrack(listTracks,id,anchor,after);if(next===listTracks)return;
  write(key,next.map(t=>t.id));
  listTracks=next;
  updatePlaylistPage(detail,listTracks);
  return true;
}
function playlistTrackRow(t,i,items){
  const current=t.id===player.queue[player.index]?.id;
  const isDownloaded=downloaded.has(String(t.id));
  const main=`${cover(t.cover,'playlist-track-cover')}<span class="playlist-track-info"><span class="playlist-track-title">${e(t.name)}${t.fee===1?'<span class="playlist-vip">VIP</span>':''}</span><small>${e(t.artist)}</small></span>`;
  const on=picked.has(String(t.id));
  const pick=selecting?button(on?icon('tick'):'',()=>{const id=String(t.id);on?picked.delete(id):picked.add(id);render();},`pick${on?' on':''}`,on?'取消选择':'选择'):'';
  const reorder=selecting?`<button type="button" class="playlist-reorder" aria-label="${e('调整'+t.name+'的顺序')}" aria-description="拖动，或使用上、下方向键">${icon('reorder')}</button>`:'';
  return `<div class="track-row playlist-track${isDownloaded?' is-downloaded':''} ${current?'current':''}${selecting?' selecting':''}${picked.has(String(t.id))?' picked':''}" data-track-id="${t.id}" data-search="${e((t.name+' '+t.artist+' '+(t.album?.name||'')).toLowerCase())}">${pick}${button(main,()=>{if(selecting){const id=String(t.id);picked.has(id)?picked.delete(id):picked.add(id);render();return;}play(items,i);},'playlist-track-main',`播放 ${t.name}`)}${liked.has(t.id)?button(icon('heart','fill-icon'),()=>likeTrack(t),'playlist-heart','取消喜欢'):'<span class="playlist-heart-space"></span>'}<span class="playlist-duration">${t.duration?time(t.duration):'···'}</span>${reorder||button(icon('moreVert'),()=>trackMenu(t,i),'playlist-more',`${t.name} 歌曲菜单`)}</div>`;
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
  const actions=$('.collection-locator')||$('.playlist-actions');if(!actions)return;
  const current=actions.querySelector('.playlist-locate'),t=player.queue[player.index];
  if(t&&listTracks.some(item=>item.id===t.id)){if(!current)actions.insertAdjacentHTML('beforeend',playlistLocateButton(listTracks));}
  else current?.remove();
}
const albumFavorites=new Map();
function collectionDescriptionButton(value,cls,title,openEditor){
  const description=typeof value==='string'?value.trim():'';
  if(!description&&!openEditor)return '';
  const preview=description?`<span class="collection-description-preview">${e(description.replace(/\s+/g,' '))}</span>`:'';
  return button(preview+icon('chevron'),
    openEditor||(()=>showOverlay('playlistDescription',`<div class="pad playlist-description-full">${e(description).replaceAll('\n','<br>')}</div>`,{title})),
    cls,openEditor?'打开歌单编辑':'查看'+title);
}
function playlistDescriptionButton(info,cls,title,emptyOnly=false){
  const hasDescription=typeof info.description==='string'&&!!info.description.trim();
  if(emptyOnly===hasDescription)return '';
  const owner=loggedIn?accountOwner():null;
  const canEdit=owner!==null&&Number(info.creator?.userId)===owner;
  return collectionDescriptionButton(info.description,cls,title,canEdit?()=>openPlaylistDescriptionEditor(info):null);
}
function applyPlaylistMetadata(id,changes){
  const key='playlist-'+id,snapshot=cache.get(key);
  const onPlaylist=route.kind==='playlist'&&Number(route.id)===id&&Number(detail?.id)===id;
  if(snapshot)cache.set(key,{...snapshot,playlist:{...snapshot.playlist,...changes}});
  else if(onPlaylist)cache.set(key,{playlist:{...detail,...changes,tracks:listTracks}});
  if(changes.coverImgUrl)playlists=playlists.map(p=>Number(p.id)===id?{...p,coverImgUrl:changes.coverImgUrl}:p);
  if(onPlaylist){detail={...detail,...changes};updatePlaylistPage(detail,listTracks);}
}
function openPlaylistDescriptionEditor(info){
  const id=Number(info.id),owner=accountOwner(),session=sessionGeneration;
  if(!owner||Number(info.creator?.userId)!==owner||!Number.isSafeInteger(id)||id<=0)return;
  const sameAccount=()=>session===sessionGeneration&&accountOwner()===owner;
  let description=info.description??'',pendingCover=null,busy=false;
  const canDelete=Number(info.specialType)!==5;
  showOverlay('playlistEditor',`<form class="pad playlist-editor">
    <div class="playlist-editor-cover">${cover(info.coverImgUrl,'playlist-thumb')}
      <button type="button" class="muted-button" data-pick-cover>更换封面</button>
    </div>
    <label for="playlist-editor-description">歌单简介</label>
    <textarea id="playlist-editor-description" rows="5" maxlength="1000" placeholder="添加歌单简介">${e(description)}</textarea>
    <p role="status" hidden></p>
    ${canDelete?`<div class="playlist-editor-delete">
      <button type="button" class="muted-button danger" data-delete-playlist aria-expanded="false">删除歌单</button>
      <div class="playlist-editor-confirm" role="group" aria-label="确认删除歌单" data-delete-confirmation hidden>
        <p>确定删除「${e(info.name)}」？这会删除网易云音乐上的歌单，无法撤销。</p>
        <div class="playlist-editor-actions">
          <button type="button" class="primary danger" data-confirm-delete>确认删除</button>
          <button type="button" class="muted-button" data-cancel-delete>取消</button>
        </div>
      </div>
    </div>`:''}
  </form>`,{title:'歌单编辑',onDone:finish});
  const form=$('.playlist-editor'),input=form.querySelector('textarea');
  const done=$('#overlay .playlist-editor-sheet .sheet-header button'),pick=form.querySelector('[data-pick-cover]');
  // HTML ignores the first newline immediately after a textarea tag.
  input.value=description;
  const status=form.querySelector('[role=status]'),active=()=>sameAccount()&&form.isConnected&&overlayKind==='playlistEditor';
  const remove=form.querySelector('[data-delete-playlist]'),confirmation=form.querySelector('[data-delete-confirmation]');
  const proceed=form.querySelector('[data-confirm-delete]'),cancel=form.querySelector('[data-cancel-delete]');
  function update(){
    form.setAttribute('aria-busy',String(busy));
    input.disabled=pick.disabled=done.disabled=busy;
    if(remove)remove.disabled=proceed.disabled=cancel.disabled=busy;
  }
  function showStatus(message,error=false){
    status.hidden=!message;status.textContent=message;status.classList.toggle('status-error',error);
  }
  async function run(work,message=''){
    if(busy||!active())return false;
    busy=true;showStatus(message);update();
    try{await work();return true;}
    catch(err){
      if(active()){
        showStatus(err.message||'保存失败，请重试',true);
        status.scrollIntoView({block:'nearest'});
      }
      return false;
    }
    finally{busy=false;if(form.isConnected)update();}
  }
  function preview(url){
    const image=document.createElement('img');
    image.src=url;image.alt='歌单封面预览';image.className='playlist-thumb';
    form.querySelector('.playlist-thumb').replaceWith(image);
  }
  async function finish(){
    const saved=await run(async()=>{
      const value=input.value;
      if(value!==description){
        if(value.length>1000)throw new Error('歌单简介最多 1000 字符');
        await api('/playlist/desc/update',{id,desc:value});
        if(!sameAccount())return;
        description=value;applyPlaylistMetadata(id,{description});
      }
      if(pendingCover){
        const url=await native('updatePlaylistCover',{id,jpeg:pendingCover});
        if(!sameAccount())return;
        if(typeof url!=='string'||!url.startsWith('https://'))throw new Error('未收到封面地址，请刷新确认');
        pendingCover=null;applyPlaylistMetadata(id,{coverImgUrl:url});
      }
    },'正在保存…');
    if(saved&&active())closeOverlay();
  }
  form.addEventListener('submit',ev=>{ev.preventDefault();void finish();});
  pick.addEventListener('click',()=>void run(async()=>{
    const selected=await native('pickPlaylistCover');
    if(!selected||!active())return;
    pendingCover=selected;preview('data:image/jpeg;base64,'+selected);
  }));
  function confirmDelete(show){
    if(!confirmation||busy||!active())return;
    confirmation.hidden=!show;
    remove.setAttribute('aria-expanded',String(show));
  }
  remove?.addEventListener('click',()=>confirmDelete(true));
  cancel?.addEventListener('click',()=>confirmDelete(false));
  proceed?.addEventListener('click',()=>void run(async()=>{
    if(!canDelete||confirmation.hidden)return;
    await api('/playlist/remove',{ids:JSON.stringify([id])});
    if(!sameAccount())return;
    cache.delete('playlist-'+id);
    playlists=playlists.filter(p=>Number(p.id)!==id);
    if(active())closeOverlay(true);
    if(route.kind==='playlist'&&Number(route.id)===id)back();
    else if(route.kind==='library')render();
    toast('歌单已删除');
  }));
}
function gradientCollectionHTML(info,items,kind){
  const isPlaylist=kind==='playlist',author=isPlaylist?info.creator?.nickname:info.artist?.name;
  const image=info.coverImgUrl||info.picUrl||'';
  const own=isPlaylist&&info.creator?.userId===account?.userId;
  const descriptionButton=isPlaylist?playlistDescriptionButton(info,'collection-description','简介'):
    collectionDescriptionButton(info.description,'collection-description','简介');
  const afterAuthor=isPlaylist?playlistDescriptionButton(info,'playlist-description-inline','歌单简介',true):'';
  const favorite=async()=>{
    if(own)return;
    if(!loggedIn){openLogin();return;}
    const session=sessionGeneration;
    await subscribe(kind,info.id,!info.subscribed);
    if(session!==sessionGeneration)return;
    if(!isPlaylist)albumFavorites.set(info.id,!info.subscribed);
    if(route.kind===kind&&Number(route.id)===Number(info.id))render();
  };
  const artist=author&&(info.artist?.id&&!isPlaylist?button(e(author),()=>navigate({kind:'artist',id:info.artist.id}),'collection-author-link',author):`<strong>${e(author)}</strong>`);
  const tools=`<div class="collection-tools"><span>${info.trackCount||items.length} 首${isPlaylist?` · ${count(info.playCount)} 次播放`:info.publishTime?` · ${e(new Date(info.publishTime).toLocaleDateString('zh-CN'))}`:''}</span>
    <div class="collection-tool-buttons">${isPlaylist?playlistSelectionButton():''}${playlistDownloadButton(items)}</div></div>`;
  const topGlass=isPlaylist?'glass ':'';
  const actions=(prefix='')=>button(icon('play'),()=>play(items),prefix+'collection-play','播放全部')+
    button(icon(info.subscribed?'heartFill':'heart'),favorite,prefix+`collection-favorite${own?' own':''}`,info.subscribed?'取消收藏':'收藏');
  return `<div class="collection-gradient" data-collection-art="${e(imageURL(image,coverSize('collection-hero-image')))}">
    <div class="collection-top">${round('back',()=>back(),'返回',topGlass)}<div class="collection-top-actions"><div class="collection-top-pills">${actions('round '+topGlass)}</div>${round('search',toggleGradientSearch,isPlaylist?'歌单内搜索':'专辑内搜索',topGlass)}</div></div>
    <div class="collection-hero">
      <div class="collection-art">${cover(image,'collection-hero-image')}</div>
      <div class="collection-meta-viewport"><div class="collection-meta"><div class="collection-copy"><h1>${e(info.name)}</h1>
        ${author||afterAuthor?`<div class="collection-by">${author?`<span>by ${artist}</span>`:''}${afterAuthor}</div>`:''}${descriptionButton}</div>
        <div class="collection-pills">${actions()}</div>
      </div></div>
    </div>
    <div class="collection-list">
      ${tools}
      <div id="playlist-search" class="playlist-search hidden">${icon('search')}<input type="search" placeholder="搜索列表内歌曲" aria-label="搜索列表内歌曲"></div>
      ${isPlaylist?playlistRowsHTML(items):tracksHTML(items,true)}
    </div>
    ${isPlaylist?'<div class="collection-locator">'+playlistLocateButton(items)+'</div>':''}
  </div>`;
}
function toggleGradientSearch(){
  const box=$('#playlist-search');if(!box)return;
  const input=box.querySelector('input');
  if(box.classList.toggle('hidden')){input.value='';filterPlaylist('');}else{
    box.scrollIntoView({block:'start',behavior:'instant'});
    input.focus({preventScroll:true});
  }
}
let collectionDarkBars=null;
function syncCollectionSystemBars(dark=null){
  if(dark===collectionDarkBars)return;
  collectionDarkBars=dark;
  native('theme',{dark:dark??document.documentElement.dataset.theme==='dark'}).catch(()=>{});
}
function applyCollectionPalette(page){
  const view=page.querySelector('.collection-gradient');
  page.classList.toggle('gradient-collection-page',!!view);
  if(!view){
    delete page.dataset.collectionTone;
    page.style.removeProperty('--collection-hero-accent');
    page.style.removeProperty('--collection-flow-tail');
    page.removeAttribute('data-collection-dimmed');
    syncCollectionSystemBars();
    return;
  }
  const url=view.dataset.collectionArt,style=currentCollectionCoverStyle();
  page.toggleAttribute('data-collection-dimmed',style==='gradientDimmed');
  const art=view.querySelector('.collection-art');
  view.classList.toggle('has-collection-flow',style==='gradientFlow');
  const paint=({primary,secondary,heroAccent,isLight,flowEdges})=>{
    if(!view.isConnected||currentCollectionCoverStyle()!==style)return;
    if(style==='gradientFlow'&&flowEdges){
      drawCollectionFlow(page,view,art,flowEdges,isLight);
    }else{
      view.querySelector('.collection-flow-backdrop')?.remove();
      page.style.removeProperty('--collection-flow-tail');
    }
    page.style.setProperty('--collection-base',`rgb(${primary.join(' ')})`);
    page.style.setProperty('--collection-accent',`rgb(${secondary.join(' ')})`);
    if(heroAccent)page.style.setProperty('--collection-hero-accent',`rgb(${heroAccent.join(' ')})`);
    else page.style.removeProperty('--collection-hero-accent');
    page.dataset.collectionTone=isLight?'light':'dark';
    syncCollectionSystemBars(!isLight);
  };
  const {width,height}=art.getBoundingClientRect();
  const aspect=Math.max(1,Math.round(width/Math.max(1,height)*100));
  const cached=ambientPalette.get(collectionPaletteKey(url,aspect,style));
  paint(cached||COLLECTION_FALLBACK);
  if(url&&!cached)ambientPaletteFor(url,aspect,style).then(paint).catch(()=>{});
}
function drawCollectionFlow(page,view,art,edges,isLight){
  view.querySelector('.collection-flow-backdrop')?.remove();
  const backdrop=document.createElement('div'),canvas=document.createElement('canvas');
  backdrop.className='collection-flow-backdrop';
  backdrop.setAttribute('aria-hidden','true');
  backdrop.append(canvas);view.prepend(backdrop);
  const sw=84,sh=96,context=canvas.getContext('2d'),pixels=context.createImageData(sw,sh);
  canvas.width=sw;canvas.height=sh;
  const drift=document.createElement('div'),driftCanvas=document.createElement('canvas');
  drift.className='collection-flow-drift';
  driftCanvas.width=sw;driftCanvas.height=sh;drift.append(driftCanvas);
  let geometry='';
  const draw=()=>{
    if(!backdrop.isConnected){observer.disconnect();return;}
    const source=art.getBoundingClientRect(),origin=view.getBoundingClientRect();
    const w=origin.width,{width:aw,height:ah}=source;
    if(!w||!aw||!ah)return;
    const wide=window.matchMedia('(orientation:landscape) and (min-width:540px)').matches;
    const h=wide?origin.height:ah+Math.max(w*1.5,380);
    const x0=source.left-origin.left,y0=source.top-origin.top;
    const next=[w,aw,ah,h,x0,y0].join('|');if(next===geometry||!h)return;geometry=next;
    const tail=[];
    for(let y=0;y<sh;y++)for(let x=0;x<sw;x++){
      const color=collectionFlowColor(edges,(x/(sw-1)*w-x0)/aw,(y/(sh-1)*h-y0)/ah,isLight);
      const i=(y*sw+x)*4;
      pixels.data.set([...color,255],i);
      if(!wide&&y===sh-1&&(x%3===0||x===sw-1))tail.push(`rgb(${color.join(' ')}) ${x/(sw-1)*100}%`);
    }
    context.putImageData(pixels,0,0);
    canvas.style.height=h+'px';
    if(wide){
      // Move a copy of the texture only beyond the cover; keep the seam anchored.
      const stop=(position,size)=>Math.min(100,Math.max(0,position/size*100))+'%';
      drift.style.setProperty('--flow-drift-x',stop(x0+aw,w));
      drift.style.setProperty('--flow-drift-y',stop(y0+ah,h));
      driftCanvas.getContext('2d').drawImage(canvas,0,0);
      if(!drift.isConnected)backdrop.append(drift);
      backdrop.style.removeProperty('background');
      page.style.removeProperty('--collection-flow-tail');
    }else{
      drift.remove();
      const tailGradient=`linear-gradient(to right,${tail.join(',')})`;
      backdrop.style.background=tailGradient;
      page.style.setProperty('--collection-flow-tail',tailGradient);
    }
  };
  const observer=new ResizeObserver(draw);
  observer.observe(view);observer.observe(art);
  draw();
}
function playlistSelectionButton(){
  return round('select',()=>{selecting=!selecting;picked.clear();render();},'选择歌曲',`playlist-action${selecting?' on':''}`);
}
function playlistDownloadButton(items){
  return round('downloadArrow',()=>downloadAll(items),'下载全部','playlist-action accent');
}
function playlistRowsHTML(items){
  return items.length?`<div class="playlist-tracks">${items.map((t,i)=>playlistTrackRow(t,i,items)).join('')}</div>`:empty('暂无歌曲');
}
function isCollectionLandscape(){return matchMedia('(orientation:landscape)').matches;}
function currentCollectionCoverStyle(){
  return isCollectionLandscape()?(prefs.collectionCoverStyleLandscape??prefs.collectionCoverStyle):prefs.collectionCoverStyle;
}
function usesGradientCover(){return ['gradient','gradientDimmed','gradientFlow'].includes(currentCollectionCoverStyle());}
function playlistDetails(info,items){
  if(usesGradientCover())return gradientCollectionHTML(info,items,'playlist');
  const creator=info.creator?.nickname||'歌单';
  const avatar=info.creator?.avatarUrl?cover(info.creator.avatarUrl,'playlist-creator-avatar'):`<span class="playlist-creator-avatar placeholder">${icon('user')}</span>`;
  return `<div class="playlist-nav">${round('back',back,'返回','playlist-nav-button glass')}<strong class="playlist-nav-title">${e(info.name)}</strong>${round('search',()=>{const box=$('#playlist-search');box.classList.toggle('hidden');if(!box.classList.contains('hidden'))box.querySelector('input').focus();else{box.querySelector('input').value='';filterPlaylist('');}},'歌单内搜索','playlist-nav-button glass accent')}</div><h1 class="sr-only">歌单</h1><div id="playlist-search" class="playlist-search hidden">${icon('search')}<input type="search" placeholder="搜索歌单内歌曲" aria-label="搜索歌单内歌曲"></div><div class="playlist-cols"><div class="playlist-col"><div class="playlist-summary">${cover(info.coverImgUrl,'playlist-cover')}<div class="playlist-summary-info"><h2>${e(info.name)}</h2><div class="playlist-creator">${avatar}<span>${e(creator)}</span>${playlistDescriptionButton(info,'playlist-description-inline','歌单简介',true)}</div><p>${info.trackCount||items.length} 首 · ${count(info.playCount)} 次播放</p></div></div>${playlistDescriptionButton(info,'playlist-description','歌单简介')}<div class="playlist-actions">${button(icon('play')+`播放全部 (${items.length})`,()=>play(items),'playlist-play')}${playlistSelectionButton()}${playlistDownloadButton(items)}${round(info.subscribed?'starFill':'starOutline',async()=>{if(!loggedIn){openLogin();return;}await subscribe('playlist',info.id,!info.subscribed);cache.delete('playlist-'+info.id);render();},info.subscribed?'取消收藏歌单':'收藏歌单',`playlist-action star-action${info.subscribed?' on':''}`)}${playlistLocateButton(items)}</div></div><div class="playlist-col">${playlistRowsHTML(items)}</div></div>`;
}
function filterPlaylist(query){
  const term=query.trim().toLowerCase();
  document.querySelectorAll('.playlist-track, .collection-gradient .track-row').forEach(row=>{
    const text=row.dataset.search??row.querySelector('.track-info')?.textContent.toLowerCase()??'';
    row.hidden=!!term&&!text.includes(term);
  });
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
    const info=data.playlist,key=playlistOrderKey(id),order=key?read(key,[]):[];
    const original=uniqueTracks(info.tracks||[]),tracks=Array.isArray(order)&&order.length?applyPlaylistOrder(original,order):original;
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
  const columnSelector='.collection-list,.playlist-col:last-child';
  const columnScroll=page.querySelector(columnSelector)?.scrollTop||0;
  const next=document.createElement('template');next.innerHTML=playlistDetails(info,items);
  // Reuse decoded images so a silent refresh never blanks unchanged artwork.
  const images=new Map();for(const img of page.querySelectorAll('img')){const key=img.className+'|'+img.getAttribute('src');if(!images.has(key))images.set(key,[]);images.get(key).push(img);}
  for(const img of next.content.querySelectorAll('img')){const old=images.get(img.className+'|'+img.getAttribute('src'))?.shift();if(old)img.replaceWith(old);}
  page.replaceChildren(next.content);page.classList.toggle('has-track',!!player.queue[player.index]);setupPlaylistSearch();applyCollectionPalette(page);
  const search=$('#playlist-search input');if(search&&searchOpen){search.closest('#playlist-search').classList.remove('hidden');search.value=query;filterPlaylist(query);if(focused)search.focus({preventScroll:true});}
  page.scrollTop=scroll;
  const column=page.querySelector(columnSelector);if(column)column.scrollTop=columnScroll;
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
  if(r.kind==='album'&&usesGradientCover()){
    let subscribed=albumFavorites.get(info.id)??info.subscribed??info.isSub;
    if(subscribed==null&&loggedIn){
      const favorites=await cached('album-favorites',()=>api('/album/sublist',{limit:500,offset:0,total:true})).catch(()=>null);
      subscribed=(favorites?.data||[]).some(a=>Number(a.id)===Number(info.id));
    }
    return gradientCollectionHTML({...info,subscribed},listTracks,'album');
  }
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
const profileBioKey=userID=>'customProfileBio.'+userID;
const customProfileBio=userID=>prefs[profileBioKey(userID)]||'';
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
  const profile=`<div class="group">${loggedIn&&account?`<div class="list-row profile-row">${account.avatarUrl?cover(account.avatarUrl,'avatar'):`<span class="avatar">${icon('user')}</span>`}<span class="list-label"><strong>${e(account.nickname)}</strong><small>${e(customProfileBio(accountOwner())||account.signature||'Antunes，随心而听')}</small></span></div>`:button(`<span class="avatar">${icon('user')}</span><span><strong>登录</strong><small>同步我喜欢的音乐、歌单与每日推荐</small></span>${icon('chevron','chevron')}`,()=>openLogin(),'list-row profile-row')}</div>`;
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
function showOverlay(kind,body,{title='',compact=false,raw=false,replace=false,onDone=()=>closeOverlay()}={}){
  if(overlayKind&&!replace)overlayHistory.push({kind:overlayKind,html:$('#overlay').innerHTML});
  clearTimeout(overlayTimer);overlayKind=kind;
  $('#overlay').innerHTML=raw?body:`<div class="scrim" ${bind(()=>closeOverlay())}></div><section class="sheet ${compact?'compact-sheet':''}${kind==='settings'?' settings-sheet':''}${kind==='comments'?' comments-sheet':''}${kind==='login'?' login-sheet':''}${kind==='storage'?' storage-sheet':''}${kind==='playlistPicker'?' playlist-picker-sheet':''}${kind==='playlistEditor'?' playlist-editor-sheet':''}" role="dialog" aria-modal="true" aria-label="${e(title)}"><div class="drag"></div><div class="sheet-header"><h2>${e(title)}</h2>${button('完成',onDone)}</div><div class="sheet-body">${body}</div></section>`;
}
function closeOverlay(all=false){
  if(!all&&overlayKind==='playlistEditor'&&$('.playlist-editor[aria-busy="true"]'))return;
  closePopover();closeComments();const wasSettings=overlayKind==='settings';clearTimeout(overlayTimer);const prev=all?null:overlayHistory.pop();if(all)overlayHistory=[];if(prev){overlayKind=prev.kind;$('#overlay').innerHTML=prev.html;if(overlayKind==='nowPlaying')updateNowPlaying(true);}else{overlayKind='';$('#overlay').innerHTML='';overlayHistory=[];}
  if(overlayKind!=='nowPlaying')closePlayPanel();
  fmLyricKey='';updateFmPlaybackLyrics();
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
function openCustomProfileBio(){
  const owner=accountOwner(),session=sessionGeneration;
  if(!owner)return;
  formSheet('自定义个人简介',`<label class="field"><input name="bio" aria-label="自定义个人简介" placeholder="留空使用网易云音乐简介" value="${e(customProfileBio(owner))}"></label><p class="notice">仅修改本机显示，不会更新网易云音乐上的简介。</p>`,'保存',values=>{
    if(session!==sessionGeneration||accountOwner()!==owner)throw new Error('账号已切换，请重新打开设置');
    const bio=String(values.get('bio')||'').trim(),key=profileBioKey(owner);
    if(bio)prefs[key]=bio;else delete prefs[key];
    write('preferences',prefs);
    closeOverlay();
  });
}
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
async function likeTrack(t){if(!t){return}if(!loggedIn){openLogin();return}const like=!liked.has(t.id);try{await api('/radio/like',{alg:'itembased',trackId:t.id,like:like,time:'3'});}catch(err){toast(err.message||'操作失败，请重试');return}if(like)liked.add(t.id);else liked.delete(t.id);toast(like?'已加入我喜欢的音乐':'已取消喜欢');syncHeart(t);updateNowPlaying(true);}
async function subscribe(kind,id,yes){if(!loggedIn){openLogin();return;}await api(`/${kind}/${kind==='playlist'?(yes?'subscribe':'unsubscribe'):(yes?'sub':'unsub')}`,kind==='artist'?{artistId:id,artistIds:JSON.stringify([id])}:{id});toast(yes?'收藏成功':'已取消收藏');cache.clear();await loadAccount();}
function detailMenu(){if(!detail)return;const d={...detail};const own=d.creator?.userId===account?.userId;const items=[['播放全部','play',()=>{closeOverlay();play(listTracks);}],['收藏','star',()=>subscribe(d.kind,d.id,true)],['取消收藏','star',()=>confirmAction('取消收藏','确认取消收藏此内容？',()=>subscribe(d.kind,d.id,false))],['下载全部','download',()=>downloadAll(listTracks)]];if(d.kind==='playlist'&&own)items.push(['删除歌单','trash',()=>confirmAction('删除歌单','此操作将删除服务端歌单，确认继续？',async()=>{await api('/playlist/remove',{ids:JSON.stringify([d.id])});cache.clear();await loadAccount();closeOverlay(true);back();}),true]);menu(d.name,items);}
function trackMenu(t,index){
  const items=[[(liked.has(t.id)?'取消喜欢':'喜欢'),'heart',()=>likeTrack(t)],['下一首播放','next',async()=>{let q=[...player.queue];if(!q.length){await play([t]);}else{q.splice(player.index+1,0,t);await native('control',{action:'replaceQueue',queue:q,index:player.index});}toast('已添加到下一首播放');closeOverlay();}],['添加到歌单','plus',()=>addToPlaylist(t)],['下载','download',()=>downloadTrack(t)],['随机播放',player.mode==='shuffle'?'tick':'shuffle',()=>setMode(player.mode==='shuffle'?'list':'shuffle')],['列表循环',player.mode==='list'?'tick':'repeat',()=>setMode('list')],['单曲循环',player.mode==='single'?'tick':'repeat',()=>setMode('single')],['音效','eq',()=>openEQ()],['睡眠定时','clock',()=>openSleep()],['专辑','album',()=>{closeOverlay(true);if(t.album?.id)navigate({kind:'album',id:t.album.id});}],['歌手','artist',()=>{const a=t.artists?.[0];if(a){closeOverlay(true);navigate({kind:'artist',id:a.id});}}]];
  if(route.kind==='downloads')items.push(['删除本地下载','trash',()=>confirmAction('删除下载','仅删除这首歌的本地下载文件。',async()=>{await native('deleteDownload',{id:t.id});downloaded.delete(String(t.id));closeOverlay(true);render();}),true]);
  if(route.kind==='playlist'&&detail?.creator?.userId===account?.userId)items.push(['从歌单移除','trash',()=>confirmAction('移除歌曲','确认将这首歌从此歌单中移除？',async()=>{await api('/playlist/manipulate/tracks',{op:'del',pid:detail.id,trackIds:JSON.stringify([t.id]),imme:'true'});cache.delete('playlist-'+detail.id);closeOverlay(true);render();}),true]);
  menu(t.name,items);
}
function addPickedToPlaylist(tracks){
  if(!tracks.length){toast('先选几首');return;}
  showPlaylistPicker(tracks,true);
}
function addToPlaylist(track){showPlaylistPicker([track]);}
function showPlaylistPicker(tracks,batch=false){
  if(!loggedIn){openLogin();return;}
  const owner=accountOwner(),session=sessionGeneration;
  if(!owner){toast('账号资料尚未就绪，请稍后重试');return;}
  const trackIds=JSON.stringify(tracks.map(t=>t.id));
  const own=playlists.filter(p=>Number(p.creator?.userId)===owner);
  const rows=own.map(p=>button(
    `${cover(p.coverImgUrl,'playlist-thumb')}<span class="list-label"><strong>${e(p.name)}</strong><small>${p.trackCount||0} 首</small></span>`,
    ()=>save(p),'list-row pick-playlist')).join('');
  showOverlay('playlistPicker',`<div class="playlist-picker-list">${rows||empty('还没有歌单','可在下方创建并添加歌曲','music')}</div>
    <form class="playlist-picker-create">
      <input class="search-input" name="name" type="text" maxlength="100" placeholder="新建歌单" aria-label="新建歌单名称">
      <button class="accent" type="submit" disabled>创建并收藏</button>
      <p class="status-error" role="status" hidden></p>
    </form>`,{title:batch?`添加到歌单（${tracks.length} 首）`:'添加到歌单'});
  const form=$('.playlist-picker-create'), field=form.elements.name, submit=form.querySelector('button');
  const status=form.querySelector('[role=status]'), choices=[...$('.playlist-picker-list').querySelectorAll('button')];
  let busy=false,created=null;
  const sameAccount=()=>session===sessionGeneration&&owner===accountOwner();
  const active=()=>sameAccount()&&overlayKind==='playlistPicker'&&form.isConnected;
  function update(){
    field.disabled=busy||created!==null;
    submit.disabled=busy||(!created&&!field.value.trim());
    for(const choice of choices)choice.disabled=busy;
  }
  field.addEventListener('input',update);
  form.addEventListener('submit',ev=>{ev.preventDefault();void save(null);});
  async function save(target){
    if(busy||!active()||(!target&&!created&&!field.value.trim()))return;
    busy=true;status.hidden=true;update();
    try{
      if(!target&&!created){
        const name=field.value.trim();
        const result=await api('/playlist/create',{name,privacy:0,type:'NORMAL'});
        const id=Number(result?.id??result?.playlist?.id);
        if(!Number.isSafeInteger(id)||id<=0)throw new Error('服务端未返回新歌单编号，请先到「我的」确认');
        created={id,name};
      }
      if(!active())return;
      const playlist=target||created;
      await api('/playlist/manipulate/tracks',{op:'add',pid:playlist.id,trackIds,imme:'true'});
      if(!sameAccount())return;
      cache.delete('playlist-'+playlist.id);
      if(active()){
        toast(batch?`已添加 ${tracks.length} 首到「${playlist.name}」`:'已添加到歌单');
        if(batch){selecting=false;picked.clear();}
        closeOverlay(batch);
        if(batch||route.kind==='playlist'&&route.id===playlist.id)render();
      }
      void loadAccount().then(()=>{if(sameAccount()&&route.kind==='library')render();}).catch(()=>{});
    }catch(err){
      if(active()){
        status.hidden=false;
        status.textContent=!target&&created?`歌单已创建，添加失败：${err.message}。可重试添加。`:err.message;
        if(!target&&created)submit.textContent='重试添加';
      }
    }finally{
      busy=false;
      if(active())update();
    }
  }
}
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
function toggleRow(label,key,after,defaultValue=false){return `<label class="list-row"><span>${e(label)}</span><input class="toggle" type="checkbox" aria-label="${e(label)}" ${(prefs[key]??defaultValue)?'checked':''} ${bindChange(ev=>{prefs[key]=ev.target.checked;savePrefs();if(after)after();})}></label>`;}
// 音质七档：与 iOS / 备用源码 MeloX 同序同值，level 直接发给 /song/enhance/player/url/v1。
const QUALITY_OPTIONS=[['standard','标准'],['exhigh','极高'],['lossless','无损'],['hires','Hi-Res'],['jyeffect','高清环绕声'],['sky','沉浸环绕声'],['jymaster','超清母带']];
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
  const expanded=new Set([...body.querySelectorAll('details[data-section-group][open]')].map(node=>node.dataset.sectionGroup));
  body.innerHTML=settingsHTML(expanded);
}
function ambientIntensityRow(){
  const percent=Math.round(Math.min(1.5,Math.max(0.5,Number(prefs.ambientIntensity)||1))*100);
  return `<label class="list-row slider-row"><span>背景色强度</span><input type="range" aria-label="背景色强度" min="50" max="150" step="10" value="${percent}" ${bindChange(ev=>{prefs.ambientIntensity=Number(ev.target.value)/100;write('preferences',prefs);const out=document.getElementById('ambient-intensity');if(out)out.textContent=Math.round(prefs.ambientIntensity*100)+'%';refreshAmbient();})}><output id="ambient-intensity">${percent}%</output></label><div class="slider-scale"><span>50%</span><span>150%</span></div>`;
}
function collectionCoverSettingsRows(){
  const choices=[['classic','经典歌单封面'],['gradient','渐变封面柔和'],['gradientDimmed','渐变封面压暗']];
  const renderCover=()=>{if(['playlist','album'].includes(route.kind))return render();};
  return selectRow('竖屏歌单封面风格','collectionCoverStyle',choices,renderCover)+
    selectRow('横屏歌单封面风格','collectionCoverStyleLandscape',[...choices,['gradientFlow','渐变封面流光']],renderCover);
}
function settingsHTML(expanded=new Set()){
  // 音质七档（与备用源码 MeloX 一致）：选到的档位拿不到时自动往下降。
  let html=`<div class="group-label">播放</div><div class="group">${selectRow('音质','quality',QUALITY_OPTIONS,v=>native('quality',{value:v}).catch(()=>{}))}${selectRow('下载音质','downloadQuality',QUALITY_OPTIONS,v=>native('downloadQuality',{value:v}).catch(()=>{}))}${listRow('音效','eq',openEQ)}${listRow('睡眠定时','clock',openSleep)}</div>`;
  html+=`<div class="group-label">启动</div><div class="group">${selectRow('冷启动板块','startTab',[['auto','自动（第一个板块）'],['home','推荐'],['explore','精选'],['fm','漫游'],['library','我的'],['search','搜索']])}</div>`;
  const sectionGroup=(title,content,note='')=>`<details data-section-group="${title}"${expanded.has(title)?' open':''}><summary>${title}</summary>${content}${note?`<p class="group-note">${note}</p>`:''}</details>`;
  const recommendationRows=[...Object.entries(HOME_CARD_TITLES),...HOME_SLOTS.map(slot=>[slot,HOME_SLOT_TITLES[slot]]),...Object.entries(HOME_EXTRA_TITLES)]
    .map(([slot,title])=>toggleRow(title,homeSectionKey(slot),()=>{if(route.kind==='home')render();},true)).join('');
  html+=`<div class="group-label">板块管理</div><div class="group section-management">
    ${sectionGroup('主页板块',sectionRows(),'只留一项时底栏直接显示该板块图标，两项及以上折叠为头像。「我的」只能在其它四个板块全部关闭后关闭；全部关闭时默认显示「我的」。')}
    ${sectionGroup('我的音乐板块',librarySectionRows(),'点右侧三个点可调整“我的”页里的顺序；关掉的项不再显示。')}
    ${sectionGroup('主页歌单展示',`<div class="group">${toggleRow('创建的歌单','libCreatedLists',()=>{if(route.kind==='library')render();})}${toggleRow('收藏的歌单','libCollectedLists',()=>{if(route.kind==='library')render();})}${toggleRow('我喜欢的音乐显示在创建的歌单','showLikedInCreated',()=>{if(route.kind==='library')render();})}</div>`)}
    ${sectionGroup('推荐页板块',`<div class="group">${recommendationRows}</div>`)}
    </div>`;
  html+=`<div class="group-label">玻璃</div><div class="group">${selectRow('玻璃样式','glassStyle',[['native','原生磨砂'],['frost','高透磨砂'],['clear','清透玻璃'],['off','关闭']],applyTheme)}</div>`;
  html+=`<div class="group-label">外观</div><div class="group">${collectionCoverSettingsRows()}${selectRow('主题','appearance',[['system','跟随系统'],['light','浅色'],['dark','深色']])}${toggleRow('底栏歌词','lyricBar',()=>{lyricsBar=prefs.lyricBar;if(!lyricsBar)tabsExpanded=false;renderChrome();})}${selectRow('歌词对齐','lyricAlignMode',[['left','居左'],['center','居中'],['right','居右']],()=>{chromeKey='';renderChrome();})}${toggleRow('底栏文字','tabLabels',applyTheme)}${toggleRow('我的页搜索按钮','librarySearch',()=>{if(route.kind==='library')render();})}${toggleRow('点击封面打开专辑','artworkLink')}${toggleRow('显示歌词翻译','translation')}${toggleRow('逐字歌词（卡拉OK）','karaoke',()=>{const t=player.queue[player.index];if(t)loadLyrics(t.id);})}${selectRow('日文歌词读音','annotation',[['none','无'],['romaji','罗马音']])}${toggleRow('主界面环境色','ambient',()=>{refreshSettings();refreshAmbient();})}${prefs.ambient?ambientIntensityRow():''}</div>`;
  html+=`<div class="group-label">存储</div><div class="group">${listRow('存储空间','download',openStorage)}${listRow('已下载','music',()=>{closeOverlay(true);navigate({kind:'downloads'});})}</div><div class="group-label">账号</div><div class="group">${loggedIn?`${listRow(account?.nickname||'已登录','user',()=>{})}${accountOwner()?listRow('自定义个人简介','user',openCustomProfileBio):''}${button('<span>退出登录</span>',()=>confirmAction('退出登录','将退出当前账号，本地下载与设置会保留。',async()=>{await native('logout');resetAccountSession(false);closeOverlay(true);render();}),'list-row danger')}`:listRow('登录','user',()=>openLogin())}</div>`;
  html+=`<div class="group-label">关于</div><div class="group">${listRow('Antunes','music',openAbout,'<small>2.2</small>')}${listRow('开源许可','album',openLicenses)}</div>`;
  return html;
}
function openSettings(){showOverlay('settings',settingsHTML(),{title:'设置'});}
function openAbout(){showOverlay('about',`<div class="about"><img src="icon.png" alt="Antunes 图标"><h2>Antunes</h2><p>随心而听的第三方网易云客户端</p><div class="group about-meta"><div class="list-row about-row"><span class="about-row-icon">${icon('user')}</span><strong>作者</strong><small>Anyu</small></div><div class="list-row about-row"><span class="about-row-icon">${icon('album')}</span><strong>当前版本</strong><small>2.2</small></div><div class="list-row about-row" role="button" tabindex="0" data-open-repo><span class="about-row-icon">${icon('link')}</span><strong>仓库</strong><small>Anyu1014/Antunes ›</small></div></div><p class="notice" style="margin-top:16px">许可证：LGPL-3.0-only</p></div>`,{title:'关于'});const repo=$('[data-open-repo]');if(repo)repo.onclick=()=>native('openUrl',{url:'https://github.com/Anyu1014/Antunes'}).catch(()=>{});}
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
  l.innerHTML=`<div class="np-float-scrim"></div><section class="play-panel${kind==='queue'?' queue-panel':''}" role="dialog" aria-label="${e(title)}"><div class="np-grab"><i></i></div><header class="pp-head"><strong>${e(title)}</strong><button class="pp-done" aria-label="完成">完成</button></header><div class="pp-body">${html}</div></section>`;
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
function nowPlayingHTML(t){return `<section class="now-playing np-immersive" role="dialog" aria-modal="true" aria-label="正在播放">${nowPlayingLandscape(t)}<div class="np-grab" id="np-grab" aria-label="下拉关闭播放页"><i></i></div><div class="np-backdrop" style="background-image:url('${e(imageURL(t.cover)).replaceAll("'",'%27')}')"></div><header class="np-head${showLyric?'':' no-thumb'}"><span class="np-thumb-slot">${cover(t.cover,'np-thumb')}</span><div class="np-head-meta"><strong id="np-title">${e(t.name)}</strong><small id="np-artist">${e(t.artist)}</small></div>${round(liked.has(t.id)?'heartFill':'heart',()=>likeTrack(player.queue[player.index]),liked.has(t.id)?'取消喜欢':'喜欢歌曲',liked.has(t.id)?'accent':'')}${button(icon('more'),()=>trackMenu(player.queue[player.index],player.index),'','歌曲菜单')}</header><div class="np-pager" id="np-pager"><div class="np-page"><div class="np-cover-wrap" id="np-visual">${button(cover(t.cover,`np-cover ${player.playing?'':'paused'}`),()=>{if(prefs.artworkLink&&t.album?.id){closeOverlay(true);navigate({kind:'album',id:t.album.id});}else toggleLyrics();},'','打开专辑')}</div><div class="np-strip" id="np-strip" role="button" aria-label="查看歌词" ${bind(()=>{if(!showLyric)toggleLyrics();})}></div></div><div class="np-page np-comments" id="np-comments"><div class="loading"><span class="spinner"></span></div></div></div><div class="np-dots" id="np-dots"><i class="on"></i><i></i></div><div class="np-seek"><div class="np-seek-track"><input id="seek" type="range" min="0" max="${player.duration||t.duration||1}" value="${player.position||0}" aria-label="播放进度"></div><div class="np-time"><span id="elapsed">${time(player.position)}</span><button class="np-quality" id="np-quality" aria-label="切换音质">${icon('eq')}<span>${e(qualityName(player.quality||prefs.quality))}${player.quality&&prefs.quality&&player.quality!==prefs.quality&&player.quality!=='local'?' ↓':''}</span></button><span id="remaining">${time(player.duration||t.duration)}</span></div></div><div class="np-controls">${button(icon(player.fm?'trash':'previous'),()=>player.fm?fmTrash():control('previous'),'',player.fm?'不喜欢，换一首':'上一首')}${button(icon(player.playing?'pause':'play'),()=>control('toggle'),'play-main','播放或暂停')}${button(icon('next'),()=>control('next'),'','下一首')}</div><p class="np-error" id="np-error">${e(player.error||'')}</p><div class="np-bottom"><button class="glass np-lyrics-toggle" ${bind(toggleLyrics)} aria-label="歌词" aria-pressed="${showLyric}">${icon(showLyric?'lyricFill':'lyric')}</button>${button(icon('lyrics'),()=>openComments(player.queue[player.index]),'glass','评论区')}${button(icon('queue'),openQueue,'glass','播放列表')}</div></section>`;}
function setupSeek(){const seek=$('#seek');if(!seek)return;updateSeekFill(seek);seek.addEventListener('input',()=>{seek.dataset.dragging='true';updateSeekFill(seek);$('#elapsed').textContent=time(seek.value);});seek.addEventListener('change',()=>{control('seek',{value:Number(seek.value)});seek.dataset.dragging='false';});}
function setMode(mode){player.mode=mode;control('mode',{mode});toast({list:'列表循环',shuffle:'随机播放',single:'单曲循环'}[mode]);if(playPanelKind==='queue')openQueue();}
function cycleMode(){const modes=['list','shuffle','single'];setMode(modes[(modes.indexOf(player.mode)+1)%3]);}
async function loadLyrics(id){if(lyricID!==id){lyrics=[];translations=[];romaji=[];}lyricID=id;activeLine=-2;fmLyricsLoading=true;
  try{let r=null;try{const cached=await native('lyric',{id:String(id)});if(cached)r=JSON.parse(cached);}catch{}
    if(!r){r=await fetchLyricPayload(id);if(r)cacheLyricPayload(id,r);}if(lyricID!==id)return;
    const verbatim=parseVerbatim(r.yrc?.lyric);lyrics=prefs.karaoke&&verbatim.length?verbatim:parseLyrics(r.lrc?.lyric);translations=parseLyrics(r.ytlrc?.lyric||r.tlyric?.lyric);romaji=parseLyrics(r.yromalrc?.lyric||r.romalrc?.lyric);if(overlayKind==='nowPlaying'){if(showLyric)renderLyrics();else updateNowPlayingLyrics(true);}
  }catch(err){if(lyricID===id&&showLyric&&$('#np-visual'))$('#np-visual').innerHTML=`<p class="secondary">歌词加载失败：${e(err.message)}</p>`;}
  finally{if(lyricID===id){fmLyricsLoading=false;updateFmPlaybackLyrics();}}
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
  const quality=$('#np-quality');
  if(quality&&!quality.dataset.wired){quality.dataset.wired='1';quality.addEventListener('click',ev=>{ev.preventDefault();ev.stopPropagation();openQualityMenu();});}
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
const fmLyricViewport=matchMedia('(orientation:landscape) and (min-width:540px)');
function fmLyricHost(){return route.kind==='fm'&&player.fm&&fmLyricViewport.matches?$('#fm-lyrics'):null;}
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
  if(!nowPlayingLyricRAF)nowPlayingLyricRAF=scheduleFullLyricFrame(advancing,()=>{nowPlayingLyricRAF=0;updateNowPlayingLyrics();});
  const pos=fullLyricPosition();
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
  paintLyricWords(row,pos);
}
function fullLyricPosition(){return player.playing&&!player.loading&&lyricSync?lyricPosition():player.position;}
function scheduleFullLyricFrame(advancing,callback){
  return advancing?requestAnimationFrame(callback):0;
}
function paintLyricWords(row,pos,words=row?.querySelectorAll('.lyric-word')){
  words?.forEach(w=>{
    const progress=Math.max(0,Math.min(100,(pos-Number(w.dataset.start))/Math.max(1,Number(w.dataset.duration))*100))+'%';
    if(w.style.getPropertyValue('--progress')!==progress)w.style.setProperty('--progress',progress);
  });
}
let fmLyricKey='',fmActive=-1,fmLyricsLoading=false,fmLyricRAF=0,fmLyricWords=[];
function updateFmPlaybackLyrics(){
  if(document.hidden||overlayKind==='nowPlaying')return;
  const host=fmLyricHost();if(!host||!player.queue[player.index])return;
  if(!fmLyricRAF)fmLyricRAF=scheduleFullLyricFrame(player.playing&&!player.loading,()=>{fmLyricRAF=0;updateFmPlaybackLyrics();});
  renderFmLyrics(host);
  paintFmLyrics(host);
}
function renderFmLyrics(host){
  const key=`${lyricID}|${lyrics.length}|${fmLyricsLoading}`;
  if(key===fmLyricKey)return;
  fmLyricKey=key;
  host.innerHTML=fmLyricsLoading&&!lyrics.length?'':lyricLinesHTML();
  fmActive=-1;fmLyricWords=[];
  if(lyrics.length&&fmMotion())host.animate([{opacity:.65},{opacity:1}],{duration:220,easing:'ease-out'});
}
function paintFmLyrics(host){
  if(!lyrics.length)return;
  const pos=fullLyricPosition(),next=Math.max(0,currentLyric(lyrics,pos)),row=host.children[next];
  if(next!==fmActive){
    const first=fmActive<0;
    host.children[fmActive]?.classList.remove('active');
    fmActive=next;fmLyricWords=row?[...row.querySelectorAll('.lyric-word')]:[];
    if(row){
      row.classList.add('active');
      const hr=host.getBoundingClientRect(),ar=row.getBoundingClientRect();
      host.scrollTo({top:host.scrollTop+(ar.top+ar.height/2)-(hr.top+hr.height/2),behavior:first||!fmMotion()?'instant':'smooth'});
    }
  }
  paintLyricWords(row,pos,fmLyricWords);
}
function openSleep(){
  const opts=[[0,'关闭定时'],[15,'15 分钟后暂停'],[30,'30 分钟后暂停'],[45,'45 分钟后暂停'],[60,'60 分钟后暂停'],[90,'90 分钟后暂停']];
  const current=Math.max(0,Math.ceil(((player.sleepAt||0)-Date.now())/60000));
  const rows=opts.map(([mins,label])=>button(`<span>${label}</span>${mins===0&&!(player.sleepAt>0)?icon('tick'):''}`,async()=>{await control('sleep',{value:mins});player.sleepAt=mins?Date.now()+mins*60000:0;closePlayPanel();toast(mins?`${mins} 分钟后暂停`:'已关闭定时');},`list-row${mins===0&&!(player.sleepAt>0)?' accent':''}`)).join('');
  openPlayPanel('sleep','睡眠定时',`<div class="group">${rows}</div><p class="group-note">到点后自动暂停播放，不会退出应用。</p>`);
}
function openQualityMenu(){
  const body=QUALITY_OPTIONS.map(([value,label])=>button(`${label}${value===prefs.quality?'<span class="tick">✓</span>':''}`,()=>{
    // savePrefs() 不接收参数（只把 prefs 写回存储），必须先把 prefs.quality 改掉，
    // 否则设置页仍显示旧档位、胶囊的 ↓ 判断也拿旧值。
    prefs.quality=value;
    savePrefs();
    native('quality',{value}).catch(()=>{});
    const at=player.position||0;
    player.quality=value;
    closePlayPanel();
    control('reload',{value:at,force:true});
    setTimeout(()=>render(),160);
  },'quality-row',label)).join('');
  openPlayPanel('quality','音质',`<div class="quality-list">${body}</div>`);
}

function openQueue(){openPlayPanel('queue','播放队列',`<div class="detail-tools"><span>${player.queue.length} 首歌曲</span>${button({list:'列表循环',shuffle:'随机播放',single:'单曲循环'}[player.mode],cycleMode,'accent')}</div><div class="track-list">${player.queue.map((t,i)=>`<div class="track-row ${i===player.index?'current':''}">${button(`${cover(t.cover,'track-cover')}<span class="track-info"><strong>${e(t.name)}</strong><small>${e(t.artist)}</small></span>`,()=>{play(player.queue,i);closePlayPanel();},'track-main',`播放 ${t.name}`)}${i!==player.index?round('close',async()=>{await control('remove',{value:i});player.queue.splice(i,1);if(i<player.index)player.index--;openQueue();},'从队列移除'):icon('music')}</div>`).join('')}</div>`);requestAnimationFrame(()=>{const cur=document.querySelector('.track-row.current');const body=cur&&cur.closest('.pp-body');if(!cur||!body)return;
  // 用视口矩形算，避免 offsetTop 基准（.track-list/表头）不一致带来的偏移。
  const r=cur.getBoundingClientRect(), b=body.getBoundingClientRect();
  body.scrollTop += (r.top+r.height/2)-(b.top+b.height/2);});}
window.addEventListener('playback',({detail:s})=>{
  PlaybackLive=true;const previous=player.queue[player.index],wasPlaying=player.playing,wasFM=player.fm;player={...player,...s};lyricSync=Date.now();const t=player.queue[player.index];
  const trackChanged=t?.id!==previous?.id;const chromeChanged=trackChanged||wasPlaying!==player.playing;
  if(trackChanged&&t){lastTrackID=t.id;const recent=[t,...read('recents',[]).filter(x=>x.id!==t.id)].slice(0,200);write('recents',recent);if(lyricID!==t.id)loadLyrics(t.id);if(overlayKind==='nowPlaying'){$('#overlay').innerHTML=nowPlayingHTML(t);
      // 播放页已经开着，只是换了首歌：不要再放一次「从底部升起」的入场动画，
      // 否则替换 DOM 的瞬间会看到主界面在底下闪一下。
      const npNow=document.querySelector('.now-playing');if(npNow)npNow.style.animation='none';
      setupSeek();setupPager();setupCommentsSwipe();setupDismissDrag();loadNowComments(t);wireNowPlaying();if(showLyric)renderLyrics();}document.querySelectorAll('[data-track-id]').forEach(n=>n.classList.toggle('current',Number(n.dataset.trackId)===t.id));}
  if(trackChanged&&player.fm&&player.index>=player.queue.length-2)fmRefill();
  if(trackChanged)updatePlaylistLocator();
  if((trackChanged||wasPlaying!==player.playing||wasFM!==player.fm)&&route.kind==='fm')syncFmPage();
  if(trackChanged)refreshAmbient();
  if(chromeChanged){renderChrome();if(overlayKind==='nowPlaying'){document.querySelectorAll('.np-controls .play-main,.np-land-controls .play-main').forEach(b=>{b.innerHTML=icon(player.playing?'pause':'play');if(b.dataset.transport)b.setAttribute('aria-label',player.playing?'暂停':'播放');});$('.np-cover')?.classList.toggle('paused',!player.playing);}}
  if(player.error&&player.error!==window.lastPlaybackError){toast(player.error);window.lastPlaybackError=player.error;}if(!player.error)window.lastPlaybackError='';
  updateNowPlaying(trackChanged&&!showLyric);
  if(!fmLyricRAF||!player.playing||player.loading)updateFmPlaybackLyrics();
  if(lyricsBar)updateLyricBar();
});
document.addEventListener('visibilitychange',updateFmPlaybackLyrics);
window.addEventListener('native-error',ev=>toast(ev.detail));
document.addEventListener('submit',ev=>{if(ev.target&&ev.target.id==='chat-form'){ev.preventDefault();sendChat();}},true);
document.addEventListener('click',ev=>{if(swallowLongPress())return;const button=ev.target.closest('[data-call]');if(!button||button.disabled)return;const fn=callbacks.get(button.dataset.call);if(fn)Promise.resolve().then(()=>fn(ev)).catch(errorToast);});
// Touch and mouse use the same handle; the list only changes after a valid drop.
let reorderDrag=null;
function playlistReorderFrame(){
  const drag=reorderDrag;if(!drag)return;
  if(!drag.row.isConnected){endPlaylistDrag(false);return;}
  const rect=drag.scroller.getBoundingClientRect(),edge=45;
  const y=drag.y,step=y<rect.top+edge?-8:y>rect.bottom-edge?8:0;
  if(drag.moved&&step)drag.scroller.scrollTop+=step;
  const hit=document.elementFromPoint(drag.x,y)?.closest('.playlist-track');
  const target=hit&&hit!==drag.row&&hit.parentElement===drag.row.parentElement?hit:null;
  drag.target?.removeAttribute('data-reorder-side');
  drag.target=target;
  if(target&&drag.moved){
    const box=target.getBoundingClientRect();
    drag.after=y>=box.top+box.height/2;
    target.dataset.reorderSide=drag.after?'after':'before';
  }
  drag.frame=requestAnimationFrame(playlistReorderFrame);
}
function endPlaylistDrag(commit){
  const drag=reorderDrag;if(!drag)return;
  reorderDrag=null;cancelAnimationFrame(drag.frame);
  drag.target?.removeAttribute('data-reorder-side');
  drag.row.classList.remove('reordering');
  if(commit&&drag.moved&&drag.target?.isConnected&&drag.row.isConnected)
    commitPlaylistMove(Number(drag.row.dataset.trackId),Number(drag.target.dataset.trackId),drag.after,drag.playlistID);
}
document.addEventListener('pointerdown',event=>{
  const handle=event.target.closest('.playlist-reorder');
  if(!handle||event.button!==0||!selecting||route.kind!=='playlist'||reorderDrag)return;
  const row=handle.closest('.playlist-track'),column=row.closest('.collection-list,.playlist-col'),page=$('#page');
  const scroller=column&&getComputedStyle(column).overflowY==='auto'?column:page;
  reorderDrag={row,scroller,pointer:event.pointerId,x:event.clientX,y:event.clientY,startY:event.clientY,playlistID:route.id};
  handle.setPointerCapture(event.pointerId);
  row.classList.add('reordering');
  playlistReorderFrame();
});
document.addEventListener('pointermove',event=>{
  if(reorderDrag?.pointer!==event.pointerId)return;
  reorderDrag.x=event.clientX;reorderDrag.y=event.clientY;
  if(Math.abs(event.clientY-reorderDrag.startY)>4)reorderDrag.moved=true;
});
document.addEventListener('pointerup',event=>{
  if(reorderDrag?.pointer!==event.pointerId)return;
  cancelAnimationFrame(reorderDrag.frame);
  reorderDrag.x=event.clientX;reorderDrag.y=event.clientY;
  playlistReorderFrame();
  endPlaylistDrag(true);
});
document.addEventListener('lostpointercapture',event=>{if(reorderDrag?.pointer===event.pointerId)endPlaylistDrag(false);});
document.addEventListener('keydown',event=>{
  const handle=event.target.closest('.playlist-reorder');
  if(!handle||!['ArrowUp','ArrowDown'].includes(event.key))return;
  event.preventDefault();
  const row=handle.closest('.playlist-track'),visible=[...row.parentElement.children].filter(r=>!r.hidden),
    down=event.key==='ArrowDown',other=visible[visible.indexOf(row)+(down?1:-1)],id=Number(row.dataset.trackId);
  if(other&&commitPlaylistMove(id,Number(other.dataset.trackId),down))
    $(`.playlist-track[data-track-id="${id}"] .playlist-reorder`)?.focus({preventScroll:true});
});
document.addEventListener('contextmenu',ev=>{const row=ev.target.closest('.playlist-track');if(!row)return;ev.preventDefault();if(ev.target.closest('.playlist-reorder'))return;const index=listTracks.findIndex(t=>t.id===Number(row.dataset.trackId));if(index>=0)trackMenu(listTracks[index],index);});
document.addEventListener('change',ev=>{const el=ev.target.closest('[data-change]');if(!el)return;const fn=callbacks.get(el.dataset.change);if(fn)Promise.resolve().then(()=>fn(ev)).catch(errorToast);});
window.addEventListener('android-back',()=>{if(playPanelKind==='queue'){closePlayPanel();return;}if(route.kind===tab&&!history.length&&!overlayKind){toast('Antunes 已在前台，音乐可在后台继续播放');return;}back();});
async function boot(){applyTheme();if(!prefs.ambientOffMigrated){prefs.ambient=false;prefs.ambientOffMigrated=true;write('preferences',prefs);}
  // 搜索板块改为默认关闭：只在从没迁移过时改一次，之后用户自己开的不会被覆盖。
  // 「我的」只有在其它四个板块都关闭时才允许关闭；老数据里若出现非法组合，启动时纠正。
  if(prefs.showLibrary===false&&!othersAllOff()){prefs.showLibrary=true;write('preferences',prefs);}
  if(!prefs.sectionLayoutMigrated){prefs.tabOrder=['showHome','showExplore','showFM','showSearch','showLibrary'];prefs.showExplore=true;prefs.sectionLayoutMigrated=true;savePrefs();}if(!prefs.searchOffMigrated){prefs.showSearch=false;prefs.searchOffMigrated=true;write('preferences',prefs);}if(!prefs.losslessDefault){prefs.losslessDefault=true;if(prefs.quality==='exhigh')prefs.quality='lossless';savePrefs();}if(!prefs.downloadQuality)prefs.downloadQuality='lossless';try{native('quality',{value:prefs.quality}).catch(()=>{});const status=await native('status');loggedIn=status.loggedIn;const restored=await native('state');player={...player,...restored};player.fm=!!prefs.fm&&!!(player.queue&&player.queue[player.index]);const cur0=player.queue&&player.queue[player.index];if(cur0){loadLyrics(cur0.id);if(player.position>0)control('seek',{value:player.position});}await native('quality',{value:prefs.quality});await native('downloadQuality',{value:prefs.downloadQuality});await native('eq',{bands:prefs.eqBands,enabled:prefs.eqEnabled});try{(await native('downloads')).forEach(t=>downloaded.add(String(t.id)));}catch{}if(loggedIn)loadAccount().then(()=>{if(['library','home','rank','messages','chat'].includes(route.kind))render();}).catch(errorToast);await render();}catch(err){$('#page').innerHTML=header('Antunes')+empty('启动失败',err.message,'wifi',button('重试',boot,'primary'));}}
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
