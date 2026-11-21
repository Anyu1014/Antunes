import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';
const c=await connect();
try {
 const r=await c.evaluate(`new Promise(resolve=>{
  const read=()=>{const s=[...document.querySelectorAll('.section')].find(s=>s.querySelector('h2')?.textContent==='推荐歌单');return s?{title:document.title,heading:s.querySelector('h2').getBoundingClientRect().left,cover:s.querySelector('.card').getBoundingClientRect().left,padding:getComputedStyle(s.querySelector('.shelf')).scrollPaddingInlineStart}:null;};
  const initial=read();if(initial){resolve(initial);return;}
  document.querySelector('nav button[aria-label="推荐"]').click();
  let n=0;const timer=setInterval(()=>{const result=read();if(result){clearInterval(timer);requestAnimationFrame(()=>requestAnimationFrame(()=>resolve(read())));}else if(++n>200){clearInterval(timer);resolve({error:'Home not active'});}},50);
 })`);
 assert.equal(r.title,'Antunes');assert(Math.abs(r.heading-r.cover)<1,JSON.stringify(r));assert.equal(r.padding,'24px');
 console.log(`ANDROID_LAYOUT: name=${r.title}; heading-left=${r.heading}px; first-cover-left=${r.cover}px; alignment=PASS; exit=0`);
} finally {c.close();}
