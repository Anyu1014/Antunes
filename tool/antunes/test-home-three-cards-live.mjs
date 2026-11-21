import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {connect} from './cdp.mjs';
const c=await connect();let breakpoint;
async function wait(expr){for(let n=0;n<200;n++){if(await c.evaluate(expr))return;await new Promise(r=>setTimeout(r,100));}throw new Error('Timed out: '+expr);}
async function swipe(rect,reverse=false){const a=reverse?rect.left:rect.right,b=reverse?rect.right:rect.left;await c.call('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:a,y:rect.y}]});for(let n=1;n<=12;n++){await c.call('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:a+(b-a)*n/12,y:rect.y}]});await new Promise(r=>setTimeout(r,20));}await c.call('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await new Promise(r=>setTimeout(r,500));}
try{
 await c.evaluate(`document.querySelector('.avatar-button')?.click()`);await new Promise(r=>setTimeout(r,150));
 await wait(`!!document.querySelector('nav button[aria-label="推荐"]')`);
 await c.call('Debugger.enable');const source=readFileSync(new URL('../../android/app/src/main/assets/app.js',import.meta.url),'utf8');
 const line=source.slice(0,source.indexOf("  const results=await cached('home-'")).split('\n').length-1;
 let hooked;const ready=new Promise(resolve=>hooked=resolve);
 c.onEvent(async ev=>{if(ev.method!=='Debugger.paused')return;try{const r=await c.call('Debugger.evaluateOnCallFrame',{callFrameId:ev.params.callFrames[0].callFrameId,returnByValue:true,expression:`(()=>{let saved;const originalLogged=loggedIn,keys=['home-true','home-false','radar'];window.__homeThreeTest={ready:()=>cache.has('home-'+originalLogged),save(){saved=keys.map(key=>[key,cache.has(key),cache.get(key)]);},async show(auth=false,partial=false){const icon='https://app.kumone.local/icon.png',items=Array.from({length:8},(_,i)=>({id:i+1,name:'Fixture '+(i+1),picUrl:icon,coverImgUrl:icon,artist:{name:'Artist'}}));loggedIn=auth;const data=[{result:items,recommend:items},{list:[{...items[0],id:19723756},{...items[1],id:3779629},{...items[2],id:2884035},{...items[3],id:3778678}]},{albums:items},{artists:items.slice(0,6)}];cache.set('home-'+auth,data.map((value,i)=>partial&&i===0?{status:'rejected',reason:new Error('fixture unavailable')}:{status:'fulfilled',value}));cache.set('radar',[]);await render();},async restore(){loggedIn=originalLogged;for(const [key,had,value] of saved||[])had?cache.set(key,value):cache.delete(key);await render();}};return true;})()`});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint});breakpoint=null;hooked();}finally{await c.call('Debugger.resume');}});
 breakpoint=(await c.call('Debugger.setBreakpointByUrl',{url:'https://app.kumone.local/app.js',lineNumber:line})).breakpointId;
 await c.call('Runtime.evaluate',{expression:`document.querySelector('nav button[aria-label="推荐"]').click()`});await ready;
 await wait(`window.__homeThreeTest?.ready()`);await c.evaluate(`__homeThreeTest.save();__homeThreeTest.show(false)`);
 for(const width of [320,390,430,768]){
  await c.call('Emulation.setDeviceMetricsOverride',{width,height:900,deviceScaleFactor:1,mobile:true});await new Promise(r=>setTimeout(r,100));
  const data=await c.evaluate(`['新碟上架','推荐歌手'].map(title=>{const section=[...document.querySelectorAll('.section')].find(s=>s.querySelector('h2')?.textContent===title),shelf=section.querySelector('.shelf');shelf.scrollLeft=0;const b=shelf.getBoundingClientRect(),style=getComputedStyle(shelf),left=b.left+parseFloat(style.paddingLeft),right=b.right-parseFloat(style.paddingRight),cards=[...shelf.querySelectorAll('.card')];return {title,count:cards.length,full:cards.filter(card=>{const r=card.getBoundingClientRect();return r.left>=left-1&&r.right<=right+1;}).length,width:cards[0].getBoundingClientRect().width,scrollable:shelf.scrollWidth>shelf.clientWidth,overflow:getComputedStyle(shelf).overflowX};})`);
  for(const row of data){assert.equal(row.full,3,JSON.stringify({width,...row}));assert(row.count>3&&row.scrollable&&row.overflow==='auto');}
 }
 console.log('LIVE_LAYOUT: 320/390/430/768px; albums/artists=3 full cards; remaining items retained; PASS');
 await c.call('Emulation.clearDeviceMetricsOverride');
 for(const title of ['新碟上架','推荐歌手']){
  await c.evaluate(`(()=>{const section=[...document.querySelectorAll('.section')].find(s=>s.querySelector('h2')?.textContent===${JSON.stringify(title)});section.scrollIntoView({block:'start',behavior:'instant'});section.querySelector('.shelf').scrollLeft=0;})()`);await new Promise(r=>setTimeout(r,100));
  const rect=await c.evaluate(`(()=>{const s=[...document.querySelectorAll('.section')].find(s=>s.querySelector('h2')?.textContent===${JSON.stringify(title)}).querySelector('.shelf'),b=s.getBoundingClientRect(),art=s.querySelector('.artwork').getBoundingClientRect();return {left:b.left+35,right:b.right-35,y:art.top+art.height/2};})()`);
  await swipe(rect);const left=await c.evaluate(`([...document.querySelectorAll('.section')].find(s=>s.querySelector('h2')?.textContent===${JSON.stringify(title)})).querySelector('.shelf').scrollLeft`);assert(left>30);
  await swipe(rect,true);const right=await c.evaluate(`([...document.querySelectorAll('.section')].find(s=>s.querySelector('h2')?.textContent===${JSON.stringify(title)})).querySelector('.shelf').scrollLeft`);assert(right<left-10);
  assert.equal(await c.evaluate(`document.querySelector('#page').dataset.route`),'home');
 }
 console.log('LIVE_SWIPE: album and artist shelves respond to left/right touch gestures; no accidental navigation; PASS');
 await c.evaluate(`__homeThreeTest.show(false,true)`);
 assert(await c.evaluate(`document.querySelector('.home-login-hint')?.textContent==='部分功能需登录后完全显示。'&&!document.querySelector('.status-error')`));
 await c.evaluate(`__homeThreeTest.show(true,true)`);
 assert(await c.evaluate(`!document.querySelector('.home-login-hint')&&document.querySelector('.status-error')?.textContent.includes('重新加载')`));
 console.log('LIVE_HINT: anonymous=login completeness; authenticated partial failure=retry retained; PASS');
 await c.evaluate(`__homeThreeTest.show(false)`);await c.evaluate(`([...document.querySelectorAll('.section')].find(s=>s.querySelector('h2')?.textContent==='新碟上架')).scrollIntoView({block:'start',behavior:'instant'})`);
 const folder=new URL('../../../.cache/home-three-cards/',import.meta.url);mkdirSync(folder,{recursive:true});const shot=await c.call('Page.captureScreenshot',{format:'png'});writeFileSync(new URL('home-three-after.png',folder),Buffer.from(shot.data,'base64'));
}finally{
 if(breakpoint)await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint});await c.call('Emulation.clearDeviceMetricsOverride').catch(()=>{});
 await c.evaluate(`(async()=>{if(window.__homeThreeTest){await __homeThreeTest.restore();delete window.__homeThreeTest;}})()`).catch(()=>{});
 await c.call('Debugger.disable');c.close();console.log('LIVE_RESTORE: authentication flag and cached home data restored; native account/preferences/playback untouched');
}
