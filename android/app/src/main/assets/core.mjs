export function escapeHTML(value) { return String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
export function applyPlaylistOrder(tracks, order) {
  const rank=new Map(order.map((id,i)=>[id,i]));
  const ranked=tracks.filter(t=>rank.has(t.id)).sort((a,b)=>rank.get(a.id)-rank.get(b.id));
  let i=0;
  return tracks.map(t=>rank.has(t.id)?ranked[i++]:t);
}
export function movePlaylistTrack(tracks, id, anchor, after) {
  if(id===anchor)return tracks;
  const next=tracks.slice(),from=next.findIndex(t=>t.id===id);
  if(from<0)return tracks;
  const [item]=next.splice(from,1),to=next.findIndex(t=>t.id===anchor);
  if(to<0)return tracks;
  const at=to+Number(after);
  if(at===from)return tracks;
  next.splice(at,0,item);
  return next;
}
export function imageURL(value, size = 384) {
  if (!value) return '';
  try {
    const u=new URL(value);
    if(!['https:','http:'].includes(u.protocol))return '';
    u.protocol='https:';
    const n=Number(size)>0?Math.round(Number(size)):384, dimensions=`${n}y${n}`;
    // The CDN executes the raw processing pipeline before serving the final thumbnail.
    if(u.hostname.endsWith('.music.126.net')&&/%7cimageView=1/i.test(u.search)&&/thumbnail=\d+y\d+(?!.*thumbnail=)/i.test(u.search)){
      u.search=u.search.replace(/thumbnail=\d+y\d+(?!.*thumbnail=)/i,'thumbnail='+dimensions);
    }else u.searchParams.set('param',dimensions);
    return u.href;
  }catch{return '';}
}
export function track(raw) {
  const t = raw.simpleSong || raw.song || raw;
  return {id:Number(t.id),name:t.name||'未知歌曲',artist:t.artist||((t.ar||t.artists||[]).map(a=>a.name).join(' / ')),artists:t.ar||t.artists||[],album:t.al||t.album||{},cover:t.cover||(t.al||t.album||{}).picUrl||'',duration:Number(t.dt||t.duration||0),fee:Number(t.fee||0)};
}
export function uniqueTracks(items) { const seen=new Set(); return items.map(track).filter(t=>Number.isSafeInteger(t.id)&&t.id>0&&!seen.has(t.id)&&seen.add(t.id)); }
// A partial detail response may omit the album altogether. Never reuse its
// cover on a different song, or when the response names a changed album.
export function preserveTrackCovers(incoming,previous) {
  const known=new Map(previous.filter(Boolean).map(raw=>{const t=track(raw);return [t.id,t];}));
  return incoming.map(item=>{
    const now=track(item),old=known.get(now.id);
    const album=Number(now.album?.id)||0,oldAlbum=Number(old?.album?.id)||0;
    if(now.cover||!old?.cover||!oldAlbum||(album&&album!==oldAlbum))return item;
    const raw=item.simpleSong||item.song||item;
    const updated={...raw,al:album?now.album:old.album,cover:old.cover};
    return item.simpleSong?{...item,simpleSong:updated}:item.song?{...item,song:updated}:updated;
  });
}
export function time(ms) { const s=Math.floor(Math.max(0,Number(ms)||0)/1000);return `${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`; }
export function count(n) { return n>=100000000?`${(n/100000000).toFixed(1)}亿`:n>=10000?`${(n/10000).toFixed(1)}万`:String(n||0); }
export function parseLyrics(text) {
  const result=[]; let offset=0;
  for(const line of String(text||'').split(/\r?\n/)){
    const off=line.match(/\[offset:([+-]?\d+)\]/);if(off){offset=Number(off[1]);continue;}
    const stamps=[...line.matchAll(/\[(\d+):(\d{2})(?:[.:](\d{1,3}))?\]/g)];
    const words=line.replace(/\[[^\]]*\]/g,'').trim();
    for(const s of stamps)result.push({at:Number(s[1])*60000+Number(s[2])*1000+Number((s[3]||'').padEnd(3,'0')),text:words});
  }
  return result.map(x=>({...x,at:Math.max(0,x.at+offset)})).sort((a,b)=>a.at-b.at);
}
export function parseVerbatim(text) {
  const lines=[];
  for(const line of String(text||'').split(/\r?\n/)) {
    const m=line.match(/^\[(\d+),(\d+)\](.*)$/);if(!m)continue;
    const words=[...m[3].matchAll(/\((\d+),(\d+),\d+\)([^()]*)/g)].map(w=>({at:Number(w[1]),duration:Number(w[2]),text:w[3]}));
    lines.push({at:Number(m[1]),duration:Number(m[2]),text:words.map(w=>w.text).join(''),words});
  }return lines;
}
export function currentLyric(lines, ms) { let i=-1;for(let n=0;n<lines.length&&lines[n].at<=ms;n++)i=n;return i; }
export const categories=['全部','推荐歌单','精品歌单','排行榜','官方','华语','流行','摇滚','民谣','电子','轻音乐','说唱','爵士','古典','影视原声','ACG','古风','怀旧','治愈','放松','伤感','快乐','学习','工作','运动','驾车','夜晚'];

export function navigationTabs(prefs) {
  const all = [
    ['home','推荐','home','showHome'], ['explore','精选','grid','showExplore'],
    ['fm','漫游','fm','showFM'], ['library','我的','user','showLibrary'],
    ['search','搜索','search','showSearch']
  ];
  // 我的 也可以关，但全部关掉时至少留一个「我的」，否则底栏无处可去
  const order = Array.isArray(prefs.tabOrder) && prefs.tabOrder.length
    ? prefs.tabOrder
    : all.map(([key]) => key);
  // tabOrder 存的是偏好键（showHome…）；老数据里可能存板块 id（home…），两种都认
  const rank = (id, prefKey) => {
    let i = order.indexOf(prefKey);
    if (i < 0) i = order.indexOf(id);
    return i < 0 ? order.length + 1 : i;
  };
  const on = all.filter(([, , , key]) => prefs[key] !== false)
    .sort((a, b) => rank(a[0], a[3]) - rank(b[0], b[3]));
  return on.length ? on : all.filter(([key]) => key === 'library');
}
