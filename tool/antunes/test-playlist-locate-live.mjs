import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {connect} from './cdp.mjs';
const c=await connect();let breakpoint;
async function wait(expr){for(let n=0;n<200;n++){if(await c.evaluate(expr))return;await new Promise(r=>setTimeout(r,100));}throw new Error('Timed out: '+expr);}
try{
 for(let n=0;n<8;n++){if(await c.evaluate(`document.querySelector('#page').dataset.route==='library'&&!!document.querySelector('.playlist-thumb')`))break;await c.evaluate(`(()=>{const close=document.querySelector('#overlay .sheet-header button');if(close)close.click();else if(document.querySelector('.avatar-button'))document.querySelector('.avatar-button').click();else if(document.querySelector('nav button[aria-label="我的"]'))document.querySelector('nav button[aria-label="我的"]').click();else window.dispatchEvent(new CustomEvent('android-back'));})()`);await new Promise(r=>setTimeout(r,150));}
 await wait(`document.querySelector('#page').dataset.route==='library'&&!!document.querySelector('.playlist-thumb')`);
 await c.call('Debugger.enable');
 const source=readFileSync(new URL('../../android/app/src/main/assets/app.js',import.meta.url),'utf8');
 const line=source.slice(0,source.indexOf('  const ticket=++renderID;')).split('\n').length-1;
 let hooked;const ready=new Promise(resolve=>hooked=resolve);
 c.onEvent(async ev=>{
  if(ev.method!=='Debugger.paused')return;
  try{
   const result=await c.call('Debugger.evaluateOnCallFrame',{callFrameId:ev.params.callFrames[0].callFrameId,returnByValue:true,expression:`(()=>{const original=structuredClone(player),live=PlaybackLive,last=lastTrackID,loader=loadLyrics,recent=localStorage.getItem('recents');loadLyrics=async()=>{};globalThis.__locateTest={tracks:()=>listTracks,state:()=>player,restore(){loadLyrics=loader;window.dispatchEvent(new CustomEvent('playback',{detail:original}));PlaybackLive=live;lastTrackID=last;if(recent===null)localStorage.removeItem('recents');else localStorage.setItem('recents',recent);}};return true;})()`});
   if(result.exceptionDetails)throw new Error(JSON.stringify(result.exceptionDetails));
   await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint});breakpoint=null;hooked();
  }finally{await c.call('Debugger.resume');}
 });
 breakpoint=(await c.call('Debugger.setBreakpointByUrl',{url:'https://app.kumone.local/app.js',lineNumber:line})).breakpointId;
 await c.call('Runtime.evaluate',{expression:`document.querySelector('.playlist-thumb').closest('button').click()`});await ready;
 await wait(`document.querySelectorAll('.playlist-track').length>10`);
 await c.evaluate(`(()=>{const queue=__locateTest.tracks();window.dispatchEvent(new CustomEvent('playback',{detail:{queue,index:Math.min(100,queue.length-1),playing:false,position:0}}));})()`);
 await wait(`!!document.querySelector('.playlist-locate')`);
 assert(await c.evaluate(`document.querySelector('.playlist-actions').lastElementChild.matches('.playlist-locate')`));
 await c.evaluate(`document.querySelector('[aria-label="歌单内搜索"]').click()`);
 await wait(`!document.querySelector('#playlist-search').classList.contains('hidden')`);
 await c.evaluate(`(()=>{const input=document.querySelector('#playlist-search input');input.value='__locate_hidden_song__';input.dispatchEvent(new Event('input',{bubbles:true}));})()`);
 assert.equal(await c.evaluate(`document.querySelectorAll('.playlist-track:not([hidden])').length`),0);
 await c.evaluate(`document.querySelector('.playlist-locate').click()`);
 await wait(`(()=>{const row=document.querySelector('.playlist-track.current'),page=document.querySelector('#page');if(!row)return false;const b=row.getBoundingClientRect(),p=page.getBoundingClientRect();return !row.hidden&&page.scrollTop>0&&Math.abs(b.top+b.height/2-p.top-p.height/2)<3;})()`);
 assert(await c.evaluate(`document.querySelector('#playlist-search').classList.contains('hidden')&&document.querySelector('#playlist-search input').value===''`));
 console.log('LIVE_LOCATE: member=visible/rightmost; hidden-filter=cleared; target=centered; PASS');
 await c.evaluate(`window.dispatchEvent(new CustomEvent('playback',{detail:{queue:[{...__locateTest.tracks()[0],id:Number.MAX_SAFE_INTEGER}],index:0}}))`);
 assert.equal(await c.evaluate(`!!document.querySelector('.playlist-locate')`),false);
 await c.evaluate(`window.dispatchEvent(new CustomEvent('playback',{detail:{queue:[],index:0}}))`);
 assert.equal(await c.evaluate(`!!document.querySelector('.playlist-locate')`),false);
 await c.evaluate(`window.dispatchEvent(new CustomEvent('playback',{detail:{queue:__locateTest.tracks(),index:0}}))`);
 await wait(`!!document.querySelector('.playlist-locate')&&!!document.querySelector('.mini-info')`);
 console.log('LIVE_MEMBERSHIP: nonmember=hidden; empty=hidden; member-after-change=visible; PASS');
 const before=await c.evaluate(`__locateTest.state().queue[__locateTest.state().index].id`);
 const rect=await c.evaluate(`(()=>{const b=document.querySelector('.mini-info').getBoundingClientRect();return {left:b.left+8,right:b.right-8,y:b.top+b.height/2};})()`);
 for(const reverse of [false,true]){
  const a=reverse?rect.right:rect.left,b=reverse?rect.left:rect.right;
  await c.call('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:a,y:rect.y}]});
  for(let step=1;step<=8;step++){await c.call('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:a+(b-a)*step/8,y:rect.y}]});await new Promise(r=>setTimeout(r,20));}
  await c.call('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 }
 assert.equal(await c.evaluate(`__locateTest.state().queue[__locateTest.state().index].id`),before);
 assert.equal(await c.evaluate(`!!document.querySelector('#overlay .sheet')`),false);
 assert(await c.evaluate(`!!document.querySelector('.mini [aria-label="上一首"]')&&!!document.querySelector('.mini [aria-label="下一首"]')`));
 console.log('LIVE_SWIPE: left/right=track-unchanged; no-detail-open; skip-buttons=retained; PASS');
 await c.call('Emulation.setDeviceMetricsOverride',{width:320,height:800,deviceScaleFactor:1,mobile:true});
 await new Promise(r=>setTimeout(r,150));
 const narrow=await c.evaluate(`(()=>{const button=document.querySelector('.playlist-locate').getBoundingClientRect();return {noOverflow:document.documentElement.scrollWidth<=innerWidth,rightVisible:button.right<=innerWidth,playWidth:document.querySelector('.playlist-play').getBoundingClientRect().width};})()`);
 assert(narrow.noOverflow&&narrow.rightVisible&&narrow.playWidth>40,JSON.stringify(narrow));
 await c.call('Emulation.clearDeviceMetricsOverride');
 await c.evaluate(`document.querySelector('#page').scrollTop=0`);
 const folder=new URL('../../../.cache/playlist-locate/',import.meta.url);mkdirSync(folder,{recursive:true});
 const shot=await c.call('Page.captureScreenshot',{format:'png'});writeFileSync(new URL('playlist-locator.png',folder),Buffer.from(shot.data,'base64'));
 console.log('LIVE_LAYOUT: 320px=no-overflow; locate=visible; PASS');
}finally{
 if(breakpoint)await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint});
 await c.call('Emulation.clearDeviceMetricsOverride').catch(()=>{});
 await c.evaluate(`window.__locateTest?.restore();delete window.__locateTest`).catch(()=>{});
 await c.call('Debugger.disable');c.close();
 console.log('LIVE_RESTORE: native-playback=untouched; displayed-player/recents=restored');
}
