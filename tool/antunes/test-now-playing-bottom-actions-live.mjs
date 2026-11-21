import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';

const c=await connect();
try{
  await c.evaluate("if(!document.querySelector('#seek'))document.querySelector('.mini-info')?.click()");
  for(let n=0;n<25&&!await c.evaluate("!!document.querySelector('#seek')");n++)await new Promise(r=>setTimeout(r,100));
  const result=await c.evaluate(`(async()=>{
    const secondary=[...document.querySelectorAll('.np-bottom button')],transport=[...document.querySelectorAll('.np-controls button')],lyric=secondary[0];
    const root=document.documentElement,saved=root.dataset.glass;
    const midX=n=>{const r=n.getBoundingClientRect();return r.x+r.width/2;};
    const getState=()=>({
      lyrics:!!document.querySelector('.np-page.lyrics-mode'),cover:!!document.querySelector('.np-cover-wrap button'),pressed:lyric.getAttribute('aria-pressed'),
      color:getComputedStyle(lyric).color,filled:!!lyric.querySelector('path[fill-rule="evenodd"]')
    });
    const click=async()=>{lyric.click();await Promise.resolve();};
    try{
      const centers=secondary.map((n,i)=>Math.round(midX(n)-midX(transport[i])));
      const sizes=secondary.map(n=>[n.offsetWidth,n.offsetHeight,getComputedStyle(n).borderRadius]);
      const modes=['native','frost','clear','off'].map(mode=>{root.dataset.glass=mode;return getComputedStyle(lyric).backdropFilter;});
      const startedInLyrics=getState().lyrics;
      if(!startedInLyrics)await click();
      const open=getState();await click();const closed=getState();await click();const reopened=getState();
      if(!startedInLyrics)await click();
      return {centers,sizes,modes,open,closed,reopened};
    }finally{
      root.dataset.glass=saved;
    }
  })()`);
  console.log(JSON.stringify(result));
  assert.deepEqual(result.centers,[0,0,0]);
  assert.deepEqual(result.sizes,Array(3).fill([44,44,'50%']));
  assert.deepEqual(result.modes,['blur(20px) saturate(1.2)','blur(10px)','none','none']);
  assert.deepEqual(result.open,{lyrics:true,cover:false,pressed:'true',color:'rgb(236, 73, 73)',filled:true});
  assert.deepEqual(result.reopened,result.open);
  assert.deepEqual(result.closed,{lyrics:false,cover:true,pressed:'false',color:'rgba(255, 255, 255, 0.72)',filled:false});
  console.log('PASS: three circles align under transport; glass modes follow settings; lyrics toggle is red only in full lyrics');
}catch(error){
  console.log('FAIL: playback bottom actions do not match alignment, glass, or lyric state');
  if(error.code!=='ERR_ASSERTION')console.error(error.message);
  process.exitCode=1;
}finally{c.close();}
