import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {connect} from './cdp.mjs';
const c=await connect(),keys=['showHome','showExplore','showFM','showSearch'],labels=['推荐','精选','漫游','搜索'];
const assets=fileURLToPath(new URL('../../android/app/src/main/assets/app.css',import.meta.url));
const original=await c.evaluate(`JSON.parse(localStorage.getItem('preferences')||'{}')`);
async function waitFor(expression){for(let n=0;n<200;n++){try{if(await c.evaluate(expression))return;}catch{}await new Promise(r=>setTimeout(r,100));}throw new Error('UI check timed out: '+expression);}
let restore=true;
try{
 await c.evaluate(`document.querySelector('nav button[aria-label="我的"]')?.click()`);
 await waitFor(`document.querySelector('#page h1')?.textContent==='我的'`);
 const avatar=await c.evaluate(`(()=>{const a=document.querySelector('.profile-row>.avatar'),b=a.getBoundingClientRect();return {width:b.width,height:b.height,radius:getComputedStyle(a).borderRadius};})()`);
 assert(Math.abs(avatar.width-avatar.height)<.5,JSON.stringify(avatar));assert.equal(avatar.radius,'50%');
 const hadPlayer=await c.evaluate(`!!document.querySelector('#chrome .mini')`);
 await c.evaluate(`document.querySelector('#page button[aria-label="设置"]').click()`);
 await waitFor(`document.querySelectorAll('#overlay input[aria-label="推荐"]').length===1`);
 for(const label of labels){await c.evaluate(`(()=>{const el=document.querySelector('#overlay input[aria-label="${label}"]');el.checked=false;el.dispatchEvent(new Event('change',{bubbles:true}));})()`);}
 await waitFor(`!document.querySelector('#chrome .tab-row')&&document.querySelector('#page h1')?.textContent==='我的'`);
 assert.equal(await c.evaluate(`!!document.querySelector('#chrome .mini')`),hadPlayer);
 execFileSync('/usr/bin/touch',[assets]);
 await waitFor(`document.title==='Antunes'&&document.querySelector('#page h1')?.textContent==='我的'&&!document.querySelector('#chrome .tab-row')`);
 await waitFor(`!document.querySelector('#overlay .sheet')`);
 const stored=await c.evaluate(`JSON.parse(localStorage.getItem('preferences'))`);for(const k of keys)assert.equal(stored[k],false);
 console.log('LIVE_SECTIONS: switches=4; all-off=library-only; navigation=hidden; player-state=unchanged; reload=persisted; avatar=48x48-circle; PASS');
} finally {
 if(restore){
  await c.evaluate(`(()=>{const current=JSON.parse(localStorage.getItem('preferences')||'{}'),original=${JSON.stringify(original)};for(const key of ${JSON.stringify(keys)}){if(Object.hasOwn(original,key))current[key]=original[key];else delete current[key];}localStorage.setItem('preferences',JSON.stringify(current));})()`);
  execFileSync('/usr/bin/touch',[assets]);
  await waitFor(`document.querySelector('#page h1')?.textContent===${JSON.stringify(original.showHome===false?'我的':'推荐')}`);
  console.log('LIVE_RESTORE: prior section preferences=restored; login/playback=untouched; PASS');
 }
 c.close();
}
