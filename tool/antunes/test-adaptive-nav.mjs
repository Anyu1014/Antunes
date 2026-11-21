import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {connect} from './cdp.mjs';
const c=await connect(),keys=['showHome','showExplore','showFM','showSearch'],labels=['推荐','精选','漫游','搜索'];
const old=await c.evaluate(`JSON.parse(localStorage.getItem('preferences')||'{}')`);
const css=fileURLToPath(new URL('../../android/app/src/main/assets/app.css',import.meta.url));
async function wait(expr){for(let i=0;i<150;i++){try{if(await c.evaluate(expr))return;}catch{}await new Promise(r=>setTimeout(r,100));}throw new Error('Timed out: '+expr);}
try{
 await c.evaluate(`document.querySelector('nav button[aria-label="我的"]')?.click()`);await wait(`document.querySelector('#page h1')?.textContent==='我的'`);
 await c.evaluate(`document.querySelector('#page button[aria-label="设置"]').click()`);await wait(`!!document.querySelector('#overlay input[aria-label="推荐"]')`);
 let widths=[];
 for(const count of [5,4,3,2,1]){
  const mask=count-1;
  for(let i=0;i<4;i++)await c.evaluate(`(()=>{const x=document.querySelector('#overlay input[aria-label="${labels[i]}"]');x.checked=${i<mask};x.dispatchEvent(new Event('change',{bubbles:true}));})()`);
  const x=await c.evaluate(`(()=>{const n=document.querySelector('.tabs'),b=n?.getBoundingClientRect();return {count:document.querySelectorAll('.tabs .tab').length,width:b?.width||0,center:b?b.left+b.width/2:0,viewport:innerWidth,separate:!!document.querySelector('.search-tab'),searchInside:!!document.querySelector('.tabs button[aria-label="搜索"]')};})()`);
  if(count===1){assert.equal(x.count,0);assert.equal(x.width,0);}else{assert.equal(x.count,count);assert(Math.abs(x.center-x.viewport/2)<1,JSON.stringify(x));assert(!x.separate);assert.equal(x.searchInside,mask===4);if(widths.length)assert(x.width<widths.at(-1));widths.push(x.width);}
 }
 console.log('ADAPTIVE_NAV: counts=5/4/3/2/1; centered=yes; width=shrinks; search=inside; solo=hidden; PASS');
}finally{
 await c.evaluate(`(()=>{const p=JSON.parse(localStorage.getItem('preferences')||'{}'),old=${JSON.stringify(old)};for(const key of ${JSON.stringify(keys)}){if(Object.hasOwn(old,key))p[key]=old[key];else delete p[key];}localStorage.setItem('preferences',JSON.stringify(p));})()`);
 execFileSync('/usr/bin/touch',[css]);await wait(`document.querySelector('#page h1')?.textContent===${JSON.stringify(old.showHome===false?'我的':'推荐')}`);
 console.log('RESTORE: original section preferences restored; PASS');c.close();
}
