import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {uniqueTracks,preserveTrackCovers} from '../../android/app/src/main/assets/core.mjs';
const source=readFileSync(process.argv[2]||new URL('../../android/app/src/main/assets/app.js',import.meta.url),'utf8');
const segment=(a,b)=>source.slice(source.indexOf(a),source.indexOf(b,source.indexOf(a)));
const code=segment('async function render(){','function card(')+segment('async function cached(','async function homePage(')+
 (source.includes('async function loadPlaylist(')?segment('async function loadPlaylist(','function updatePlaylistPage('):'')+
 segment('async function detailPage(','function listRow(');
const snapshot=(name='Cached',ids=[1,2])=>({playlist:{id:7,name,coverImgUrl:'https://example.test/cover.jpg',tracks:ids.map(id=>({id,name:'Song '+id})),trackIds:ids.map(id=>({id}))}});
function fixture(cached=snapshot()){
 let resolve,reject;const response=new Promise((a,b)=>{resolve=a;reject=b;});
 const calls=[],writes=[];const page={dataset:{route:'playlist'},scrollTop:83,className:'',classList:{toggle(){}},innerHTML:'Cached'};
 const context={route:{kind:'playlist',id:7},renderID:0,sessionGeneration:0,detail:{kind:'playlist',id:7},listTracks:[],cache:new Map(cached?[['playlist-7',cached]]:[]),player:{queue:[],index:0},$:()=>page,renderChrome(){},watchPlaylistNavMerged(){},preloadCoversAsync:async()=>{},loading(){writes.push('loading');page.innerHTML='loading';},uniqueTracks,preserveTrackCovers,playlistDetails:(info,tracks)=>info.name+'|'+tracks.map(t=>t.id).join(','),setupPlaylistSearch(){},header:()=>'',empty:()=> 'error',button:()=>'',api:(path,payload)=>{calls.push({path,payload});return response;},updatePlaylistPage(info,tracks){writes.push(info.name);page.innerHTML=info.name+'|'+tracks.map(t=>t.id).join(',');}};
 vm.createContext(context);vm.runInContext(code,context);return {context,page,calls,writes,resolve,reject};
}
const flush=async()=>{for(let n=0;n<12;n++)await Promise.resolve();};
{
 const f=fixture();const run=f.context.render();
 assert(!f.writes.includes('loading'),'cached playlist must not flash a loading page');
 assert.equal(f.page.innerHTML,'Cached|1,2','cache must render synchronously before network settles');
 assert.equal(f.calls.length,1,'cache hit must revalidate in background');
 f.resolve(snapshot('Fresh',[2,3]));await run;
 assert.equal(f.page.innerHTML,'Fresh|2,3');assert.equal(f.context.listTracks.map(t=>t.id).join(','),'2,3');
 console.log('CACHE: immediate=YES; loading=0; background=YES; refreshed=YES; PASS');
}
{
 const f=fixture();const run=f.context.render();f.reject(new Error('offline'));await run;
 assert.equal(f.page.innerHTML,'Cached|1,2');assert.equal(f.context.cache.get('playlist-7').playlist.name,'Cached');
 console.log('OFFLINE: cached content retained; PASS');
}
{
 const f=fixture();const run=f.context.render();const before=f.writes.length;f.resolve(snapshot());await run;
 assert.equal(f.writes.length,before,'unchanged response must not redraw');
 console.log('UNCHANGED: redraw=0; PASS');
}
{
 const f=fixture(null);const run=f.context.render();assert(f.writes.includes('loading'));f.resolve(snapshot('First'));await run;
 assert.equal(f.page.innerHTML,'First|1,2');assert.equal(f.context.cache.get('playlist-7').playlist.tracks.length,2);
 const broken=fixture(null);const failed=broken.context.render();broken.reject(new Error('offline'));await failed;assert.equal(broken.page.innerHTML,'error');
 console.log('COLD: loading then content; failure=retry-page; PASS');
}
{
 const f=fixture();const run=f.context.render();f.context.renderID++;f.context.route={kind:'library'};f.page.innerHTML='Other page';f.resolve(snapshot('Late'));await run;
 assert.equal(f.page.innerHTML,'Other page');assert.equal(f.context.detail.name,'Cached');
 assert.equal(f.context.cache.get('playlist-7').playlist.name,'Cached');
 console.log('NAVIGATION: late response ignored; PASS');
}
{
 const f=fixture(null);const calls=[];
 f.context.api=async(path,payload)=>{calls.push(path);if(path==='/v6/playlist/detail'){const data=snapshot('Complete');data.playlist.tracks=data.playlist.tracks.slice(0,1);return data;}return {songs:snapshot().playlist.tracks};};
 await f.context.render();assert.equal(f.context.cache.get('playlist-7').playlist.tracks.length,2);
 assert.deepEqual(calls,['/v6/playlist/detail','/v3/song/detail']);
 console.log('COMPLETE: expanded song list cached atomically; PASS');
}
{
 const f=fixture();const run=f.context.render();f.context.cache.clear();f.resolve(snapshot('Invalidated'));await run;await flush();
 assert.equal(f.context.cache.size,0);
 console.log('INVALIDATION: old request cannot repopulate cleared cache; PASS');
}
{
 const f=fixture(null),batchSizes=[];const ids=Array.from({length:801},(_,n)=>n+1);
 f.context.api=async(path,payload)=>{if(path==='/v6/playlist/detail'){const data=snapshot('Large',ids);data.playlist.tracks=[];return data;}const batch=JSON.parse(payload.c);batchSizes.push(batch.length);return {songs:batch.map(({id})=>({id,name:'Song '+id}))};};
 await f.context.render();assert.deepEqual(batchSizes,[400,400,1]);assert.equal(f.context.cache.get('playlist-7').playlist.tracks.length,801);
 console.log('BATCHES: 801 songs=400+400+1; PASS');
}
{
 const f=fixture();f.context.api=async path=>{if(path==='/v6/playlist/detail'){const data=snapshot('Incomplete');data.playlist.tracks=[];return data;}throw new Error('song details unavailable');};
 await f.context.render();assert.equal(f.page.innerHTML,'Cached|1,2');assert.equal(f.context.cache.get('playlist-7').playlist.name,'Cached');
 console.log('PARTIAL_FAILURE: complete cache retained; PASS');
}
