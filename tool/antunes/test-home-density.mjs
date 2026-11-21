import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';
const c=await connect();
try {
 const r=await c.evaluate(`new Promise(resolve=>{
  const read=()=>{const s=[...document.querySelectorAll('.section')].find(s=>s.querySelector('h2')?.textContent==='推荐歌单');if(!s)return null;const shelf=s.querySelector('.shelf'),cards=[...shelf.querySelectorAll('.card')],right=Math.min(innerWidth,shelf.getBoundingClientRect().right),left=shelf.getBoundingClientRect().left;return {viewport:innerWidth,heading:s.querySelector('h2').getBoundingClientRect().left,cover:cards[0].getBoundingClientRect().left,width:cards[0].getBoundingClientRect().width,visible:cards.reduce((n,c)=>{const b=c.getBoundingClientRect();return n+Math.max(0,Math.min(b.right,right)-Math.max(b.left,left))/b.width;},0)};};
  const finish=()=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve(read())));
  if(read()){finish();return;}document.querySelector('nav button[aria-label="推荐"]').click();let n=0;const t=setInterval(()=>{if(read()){clearInterval(t);finish();}else if(++n>200){clearInterval(t);resolve(null);}},50);
 })`);
 assert(r,'Recommendation shelf missing');
 const ok=Math.abs(r.visible-2.5)<.03&&Math.abs(r.heading-r.cover)<1;
 console.log(`HOME_DENSITY: visible=${r.visible.toFixed(3)}; target=2.5; first-left=${r.cover}px; cover-width=${r.width}px; ${ok?'PASS':'FAIL'}`);
 if(!ok)process.exitCode=1;
} finally {c.close();}
