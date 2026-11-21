import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';
const c=await connect();
async function wait(expr){for(let i=0;i<150;i++){if(await c.evaluate(expr))return;await new Promise(r=>setTimeout(r,100));}throw new Error('Timed out: '+expr);}
try{
 await c.evaluate(`document.querySelector('nav button[aria-label="我的"]').click()`);await wait(`document.querySelector('#page h1')?.textContent==='我的'`);
 const x=await c.evaluate(`(()=>{const n=document.querySelector('.tabs'),b=n.getBoundingClientRect(),a=n.querySelector('.tab.active'),icon=a.querySelector('svg');return {count:n.querySelectorAll('.tab').length,width:b.width,center:b.left+b.width/2,available:document.querySelector('.tab-row').getBoundingClientRect().width,viewport:innerWidth,color:getComputedStyle(a).color,fill:getComputedStyle(icon).fill,theme:document.documentElement.dataset.theme,userCircle:!!icon.querySelector('circle'),userBody:!!icon.querySelector('path'),separate:!!document.querySelector('.search-tab')};})()`);
 assert(Math.abs(x.width-Math.min(x.available,88+x.count*60))<1,JSON.stringify(x));assert(Math.abs(x.center-x.viewport/2)<1);assert.equal(x.color,x.theme==='dark'?'rgb(255, 255, 255)':'rgb(0, 0, 0)');assert.equal(x.fill,x.color);assert(x.userCircle&&x.userBody&&!x.separate);
 console.log(`NAV_REFERENCE: count=${x.count}; width=${x.width}px; center=${x.center.toFixed(2)}px; selected=${x.color}; user=filled; search=integrated; PASS`);
}finally{c.close();}
