import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import vm from 'node:vm';

const root=process.argv[2]||resolve(import.meta.dirname,'../..');
const path=resolve(root,'android/app/src/main/assets');
const source=readFileSync(resolve(path,'app.js'),'utf8');
const core=await import(pathToFileURL(resolve(path,'core.mjs')));
function section(start,end) {
  const first=source.indexOf(start), last=source.indexOf(end,first+start.length);
  return first<0||last<0?'':source.slice(first,last);
}
function pending(){
  let answer;
  const promise=new Promise(resolve=>answer=resolve);
  return {promise,answer};
}
const drain=async()=>{for(let n=0;n<16;n++)await Promise.resolve();};
function context(code,locals={}){
  const env=vm.createContext({
    ...core,e:core.escapeHTML,sessionGeneration:1,renderID:1,playbackIntent:0,
    loggedIn:true,account:{userId:101},cache:new Map(),route:{kind:'home'},
    player:{queue:[],index:0},prefs:{},savePrefs(){},render(){},openLogin(){},
    header:t=>'<h1>'+t+'</h1>',button:t=>t,empty:t=>t,icon:()=>'',round:()=>'',toast(){},errorToast(){},
    window:{matchMedia:()=>({matches:false})},
    ...locals
  });
  vm.runInContext('const accountOwner=()=>loggedIn?account?.userId??null:null;'+code,env);
  return env;
}
const cases=[];
const test=(name,run)=>cases.push([name,run]);

test('partial album retains cover without carrying it onto a different album',async()=>{
  const old=[{id:1,al:{id:9,picUrl:'https://example.test/cover'}}];
  const next=[{id:1,name:'partial'},{id:2,al:{id:9}},{id:3,al:{id:10}}];
  const f=context(section('async function loadPlaylist(','function updatePlaylistPage('),{
    api:async()=>({playlist:{id:23,tracks:next}})
  });
  const data=await f.loadPlaylist(23,{playlist:{tracks:[...old,{id:3,al:old[0].al}]}});
  const merged=data.playlist.tracks;
  assert.equal(core.track(merged[0]).cover,old[0].al.picUrl);
  assert.equal(core.track(merged[1]).cover,'');
  assert.equal(core.track(merged[2]).cover,'');
});

test('superseded thumbnail wait cannot replace the active tab',async()=>{
  const image=pending(),network=pending(),writes=[];
  const snapshot={playlist:{id:23,tracks:[{id:1,al:{id:9,picUrl:'https://example.test/cover'}}]}};
  const f=context(section('async function loadPlaylist(','function updatePlaylistPage('),{
    route:{kind:'playlist',id:23}, cache:new Map([['playlist-23',snapshot]]),
    preloadCoversAsync:()=>image.promise,api:()=>network.promise,loading(){},
    updatePlaylistPage(){writes.push('stale playlist');}
  });
  const loading=f.playlistPage(1);
  f.renderID++;f.route={kind:'library'};
  image.answer();network.answer(snapshot);await loading;
  assert.deepEqual(writes,[]);
});

test('main home data displays before optional requests resolve',async()=>{
  const extras=pending(),page={innerHTML:'loading',classList:{toggle(){}}};
  const f=context(section('const HOME_SLOTS=','async function startFM(')+section(
    'async function homePage(','async function explorePage('),{
    $:()=>page, cover:()=>'', count:()=>'', read:()=>[], write(){}, card:item=>item.name,startHeart(){},
    api:path=>path.includes('homepage/block/page')?Promise.resolve({data:{blocks:[{
      blockCode:'HOMEPAGE_BLOCK_MGC_PLAYLIST',uiElement:{mainTitle:{title:'首屏雷达'}},
      creatives:[{resources:[{resourceType:'list',resourceId:'9',uiElement:{mainTitle:{title:'测试歌单'}}}]}]
    }]}}):extras.promise,
  });
  const task=f.homePage(1,1);
  await drain();
  try { assert.match(page.innerHTML,/首屏雷达/); }
  finally { extras.answer({});await task.catch(()=>{}); }
});

test('late FM does not replace a later play intent',async()=>{
  const radio=pending(),writes=[];
  const f=context(section('async function startFM()','async function homePage('),{
    api:()=>radio.promise,play:async()=>{writes.push('FM');return true;}
  });
  const start=f.startFM();
  f.playbackIntent++;writes.push('new choice');
  radio.answer({data:[{id:2}]});await start;
  assert.deepEqual(writes,['new choice']);
});

test('search category responses cannot replace newer results',async()=>{
  const old=pending(),newer=pending(),nodes={
    '#search-results':{},'#search-filters':{},'#search-clear':{},'#page .header h1':{}
  };
  const requests=[];
  const start=source.includes('async function searchPage()')?'async function searchPage()':'function searchPage()';
  const f=context(section('async function cached(','function fmPage(')+section(
    start,'function showOverlay('),{
    route:{kind:'search'},searchQuery:'fixture',searchType:1,$:k=>nodes[k],read:()=>[],write(){},
    tracksHTML:tracks=>tracks[0]?.name,closeSearch(){},api:(_,payload)=>{requests.push(payload.type);return requests.length===1?old.promise:newer.promise;}
  });
  if(!f.updateSearch){
    const view=f.searchPage();
    // A slow category request cannot block rendering of the input and picker.
    if(typeof view!=='string'){
      old.answer({result:{songs:[{id:1,name:'fixture'}]}});
      await view;
      assert.fail('search controls wait on the network');
    }
    return;
  }
  const first=f.updateSearch(1);
  f.renderID++;f.searchType=1;
  const second=f.updateSearch(2);
  newer.answer({result:{songs:[{id:2,name:'new result'}]}});await second;
  old.answer({result:{songs:[{id:1,name:'stale result'}]}});await first;
  assert.equal(nodes['#search-results'].innerHTML,'new result');
});

test('closing search from the startup library returns to that tab',()=>{
  const input={blur(){}};
  const f=context(section('function navigate(','async function render()'),{
    route:{kind:'library'}, tab:'library',prefs:{showLibrary:true,showSearch:true,showHome:true},
    history:[],selecting:false,overlayKind:'',closeOverlay(){},clearTimeout(){},queryTimer:null,$:()=>input
  });
  f.openSearchFromLibrary();
  assert.equal(f.route.kind,'search');
  f.closeSearch();
  assert.equal(f.route.kind,'library');
});

test('chat protects drafts and rejects an account-mismatched route',async()=>{
  const sent=pending(),input={value:'first draft'},body={innerHTML:''},paths=[];
  const chat={kind:'chat',userId:88,owner:101,session:1};
  const f=context(section('async function messagesPage()','async function collectionsPage('),{
    route:chat,$:k=>k==='#chat-input'?input:body,
    api:path=>{paths.push(path);return path.endsWith('/send')?sent.promise:Promise.resolve({msgs:[]});}
  });
  const sending=f.sendChat(chat);
  const duplicate=f.sendChat(chat);
  input.value='new draft';sent.answer();await sending;await duplicate;
  assert.equal(input.value,'new draft');
  assert(paths.includes('/msg/private/history'));
  assert.equal(paths.filter(x=>x.endsWith('/send')).length,1);
  f.sessionGeneration++;f.account={userId:202};
  await f.sendChat(chat);
  assert.equal(paths.filter(x=>x.endsWith('/send')).length,1);
});

test('rank does not query user zero while awaiting the profile',async()=>{
  const calls=[];
  const f=context(section('async function rankPage()','function decodeMsg('),{
    account:null,read:()=>[],listRow:()=>'',api:async(_,p)=>{calls.push(p);return {};}
  });
  assert.match(await f.rankPage(),/账号资料尚未就绪/);
  assert.deepEqual(calls,[]);
});

let failed=0;
for(const [label,run] of cases){
  try{ await run();console.log('PASS '+label); }
  catch(error){failed++;console.log('FAIL '+label+': '+String(error.message).split('\n')[0]);}
}
console.log(`ANDROID FIXTURES ${cases.length-failed}/${cases.length}`);
process.exitCode=Number(failed>0);
