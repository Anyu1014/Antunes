import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';
const c=await connect();
const old=await c.evaluate(`JSON.parse(localStorage.getItem('preferences')||'{}')`);
async function wait(expr){for(let i=0;i<150;i++){if(await c.evaluate(expr))return;await new Promise(r=>setTimeout(r,100));}throw new Error('Timed out: '+expr);}
try{
 await c.evaluate(`document.querySelector('nav button[aria-label="我的"]')?.click()`);await wait(`document.querySelector('#page h1')?.textContent==='我的'`);
 await c.evaluate(`document.querySelector('#page button[aria-label="设置"]').click()`);await wait(`!!document.querySelector('select[aria-label="磨砂玻璃"]')`);
 const options=await c.evaluate(`[...document.querySelector('select[aria-label="磨砂玻璃"]').options].map(o=>o.textContent)`);assert.deepEqual(options,['关闭','高透磨砂','原生磨砂']);
 for(const [style,blur] of [['off','none'],['clear','10px'],['native','20px']]){
  await c.evaluate(`(()=>{const s=document.querySelector('select[aria-label="磨砂玻璃"]');s.value='${style}';s.dispatchEvent(new Event('change',{bubbles:true}));})()`);
  await wait(`document.documentElement.dataset.glass==='${style}'`);
  const values=await c.evaluate(`(()=>{const mock=document.createElement('div');mock.className='mini glass';mock.style.position='fixed';mock.style.left='-10000px';document.body.append(mock);const result=['.tabs'].map(q=>getComputedStyle(document.querySelector(q)).backdropFilter);result.push(getComputedStyle(mock).backdropFilter);mock.remove();return result;})()`);
  assert(values.every(v=>blur==='none'?v==='none':v.includes(blur)),JSON.stringify({style,values}));
  assert.equal(await c.evaluate(`JSON.parse(localStorage.getItem('preferences')).glassStyle`),style);
 }
 const top=await c.evaluate(`getComputedStyle(document.querySelector('.top-bar')).backdropFilter`);assert.equal(top,'none');
 console.log('GLASS: options=3; surfaces=nav/player; styles=off/10px/20px; persisted=yes; top-glass=none; PASS');
} finally {
 await c.evaluate(`(()=>{const p=JSON.parse(localStorage.getItem('preferences')||'{}'),old=${JSON.stringify(old)};if(Object.hasOwn(old,'glassStyle'))p.glassStyle=old.glassStyle;else delete p.glassStyle;localStorage.setItem('preferences',JSON.stringify(p));document.documentElement.dataset.glass=['off','clear','native'].includes(p.glassStyle)?p.glassStyle:'native';const s=document.querySelector('select[aria-label="磨砂玻璃"]');if(s)s.value=p.glassStyle||'native';})()`);
 console.log('RESTORE: original glass preference restored; other preferences untouched; PASS');c.close();
}
