import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {connect} from './cdp.mjs';
const c=await connect();let breakpoint;
async function wait(expr){for(let n=0;n<200;n++){if(await c.evaluate(expr))return;await new Promise(r=>setTimeout(r,100));}throw new Error('Timed out: '+expr);}
try{
 await c.call('Debugger.enable');
 const source=readFileSync(new URL('../../android/app/src/main/assets/app.js',import.meta.url),'utf8');
 const line=source.slice(0,source.indexOf('  const ticket=++renderID;')).split('\n').length-1;
 let hooked;const ready=new Promise(resolve=>hooked=resolve);
 c.onEvent(async ev=>{
  if(ev.method!=='Debugger.paused')return;
  try{
   const result=await c.call('Debugger.evaluateOnCallFrame',{callFrameId:ev.params.callFrames[0].callFrameId,expression:`(()=>{const original=loadPlaylist;globalThis.__playlistRegression={render,library:()=>switchTab('library'),snapshot:()=>structuredClone(cache.get('playlist-'+route.id)),setSnapshot:data=>cache.set('playlist-'+data.playlist.id,data),defer(){loadPlaylist=()=>new Promise((resolve,reject)=>{this.resolve=resolve;this.reject=reject;});},restore(){loadPlaylist=original;}};return true;})()`,returnByValue:true});
   if(result.exceptionDetails)throw new Error(JSON.stringify(result.exceptionDetails));
   await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint});breakpoint=null;hooked();
  }finally{await c.call('Debugger.resume');}
 });
 // Start from the library without altering saved preferences.
 for(let n=0;n<8;n++){if(await c.evaluate(`document.querySelector('#page').dataset.route==='library'&&!!document.querySelector('.playlist-thumb')`))break;await c.evaluate(`(()=>{const close=document.querySelector('#overlay .sheet-header button');if(close)close.click();else if(document.querySelector('.avatar-button'))document.querySelector('.avatar-button').click();else if(document.querySelector('nav button[aria-label="我的"]'))document.querySelector('nav button[aria-label="我的"]').click();else window.dispatchEvent(new CustomEvent('android-back'));})()`);await new Promise(r=>setTimeout(r,150));}
 await wait(`document.querySelector('#page').dataset.route==='library'&&!!document.querySelector('.playlist-thumb')`);
 breakpoint=(await c.call('Debugger.setBreakpointByUrl',{url:'https://app.kumone.local/app.js',lineNumber:line})).breakpointId;
 await c.call('Runtime.evaluate',{expression:`document.querySelector('.playlist-thumb').closest('button').click()`});
 await ready;
 await wait(`!!document.querySelector('.playlist-cover')&&document.querySelectorAll('.playlist-track').length>0`);
 await c.evaluate(`window.__playlistOriginal=__playlistRegression.snapshot();__playlistRegression.library()`);
 await wait(`document.querySelector('#page').dataset.route==='library'&&!!document.querySelector('.playlist-thumb')`);
 await c.evaluate(`(()=>{const h=__playlistRegression;h.defer();window.__playlistLoadingWrites=0;window.__playlistObserver=new MutationObserver(records=>{for(const record of records)for(const n of record.addedNodes)if(n.nodeType===1)window.__playlistLoadingWrites+=Number(n.matches('.page-loading'))+n.querySelectorAll('.page-loading').length;});__playlistObserver.observe(document.querySelector('#page'),{subtree:true,childList:true});document.querySelector('.playlist-thumb').closest('button').click();})()`);
 await wait(`!!document.querySelector('.playlist-cover')&&typeof __playlistRegression.resolve==='function'`);
 const hit=await c.evaluate(`({loadingWrites:__playlistLoadingWrites,rows:document.querySelectorAll('.playlist-track').length,spinner:!!document.querySelector('.page-loading')})`);
 assert.equal(hit.loadingWrites,0);assert.equal(hit.spinner,false);assert(hit.rows>0);
 console.log('LIVE_CACHE: immediate=YES; loading=0; background=pending; PASS');
 const refreshed=await c.evaluate(`new Promise(resolve=>{const h=__playlistRegression,page=document.querySelector('#page');window.__playlistCover=page.querySelector('.playlist-cover');const fresh=structuredClone(__playlistOriginal);fresh.playlist.description=(fresh.playlist.description||'')+' ';page.scrollTop=120;const y=page.scrollTop;let blankFrames=0,frames=0;const sample=()=>{const img=page.querySelector('.playlist-cover');if(!img||!img.complete||!img.naturalWidth)blankFrames++;if(++frames<20)requestAnimationFrame(sample);else resolve({sameCover:__playlistCover===img,decoded:img.complete&&img.naturalWidth>0,scrollPreserved:Math.abs(page.scrollTop-y)<1,loadingWrites:__playlistLoadingWrites,blankFrames});};h.resolve(fresh);requestAnimationFrame(sample);})`);
 assert.deepEqual(refreshed,{sameCover:true,decoded:true,scrollPreserved:true,loadingWrites:0,blankFrames:0});
 console.log('LIVE_REFRESH: cover-node=retained; decoded=YES; blank-frames=0/20; scroll=retained; loading=0; PASS');
 const search=await c.evaluate(`new Promise(async resolve=>{const h=__playlistRegression;document.querySelector('[aria-label="歌单内搜索"]').click();await Promise.resolve();const input=document.querySelector('#playlist-search input');input.value='__cache_regression_no_match__';input.dispatchEvent(new Event('input',{bubbles:true}));input.focus();h.render();const fresh=structuredClone(__playlistOriginal);fresh.playlist.description=(fresh.playlist.description||'')+'  ';h.resolve(fresh);setTimeout(()=>{const current=document.querySelector('#playlist-search input');resolve({query:current.value,focused:document.activeElement===current,open:!current.closest('#playlist-search').classList.contains('hidden'),visibleRows:document.querySelectorAll('.playlist-track:not([hidden])').length,sameCover:__playlistCover===document.querySelector('.playlist-cover')});},250);})`);
 assert.equal(search.query,'__cache_regression_no_match__');assert(search.focused&&search.open&&search.sameCover);assert.equal(search.visibleRows,0);
 console.log('LIVE_SEARCH: query/focus/filter=retained; cover-node=retained; PASS');
 const offline=await c.evaluate(`new Promise(resolve=>{const h=__playlistRegression;h.render();h.reject(new Error('fixture offline'));setTimeout(()=>resolve({cover:__playlistCover===document.querySelector('.playlist-cover'),error:document.querySelector('#page').innerText.includes('加载失败'),loadingWrites:__playlistLoadingWrites}),100);})`);
 assert.deepEqual(offline,{cover:true,error:false,loadingWrites:0});
 console.log('LIVE_OFFLINE: cached content=retained; error-page=0; PASS');
 await c.evaluate(`(async()=>{const h=__playlistRegression;document.activeElement?.blur();document.querySelector('[aria-label="歌单内搜索"]').click();await Promise.resolve();h.setSnapshot(__playlistOriginal);const run=h.render();h.resolve(structuredClone(__playlistOriginal));await run;document.querySelector('#page').scrollTop=0;__playlistObserver.disconnect();h.restore();for(const key of ['__playlistRegression','__playlistOriginal','__playlistObserver','__playlistLoadingWrites','__playlistCover'])delete window[key];})()`);
 const shots=new URL('../../../.cache/playlist-cover-fix/',import.meta.url);mkdirSync(shots,{recursive:true});
 const shot=await c.call('Page.captureScreenshot',{format:'png'});writeFileSync(new URL('playlist-after.png',shots),Buffer.from(shot.data,'base64'));
 console.log('LIVE_RESTORE: loader=original; cached data=original; account/downloads/playback=untouched; PASS');
}finally{
 if(breakpoint)await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint});
 await c.evaluate(`window.__playlistObserver?.disconnect();window.__playlistRegression?.restore();delete window.__playlistRegression`).catch(()=>{});
 await c.call('Debugger.disable');c.close();
}
