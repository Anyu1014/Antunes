import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';

const c=await connect();
try{
  await c.evaluate("if(!document.querySelector('#seek'))document.querySelector('.mini-info')?.click()");
  for(let n=0;n<25&&!await c.evaluate("!!document.querySelector('#seek')");n++)await new Promise(r=>setTimeout(r,100));
  const layout=await c.evaluate(`(()=>{
    const seek=document.querySelector('#seek'),track=seek.parentElement;
    const rail=getComputedStyle(track,'::before'),fill=getComputedStyle(track,'::after');
    const time=getComputedStyle(document.querySelector('.np-time'));
    return {rail:rail.height,railColor:rail.backgroundColor,fill:fill.height,fillColor:fill.backgroundColor,
            laneHeight:getComputedStyle(track).height,timeSize:time.fontSize,timeColor:time.color,gap:time.marginTop,
            type:seek.type,appearance:getComputedStyle(seek).appearance};
  })()`);
  console.log(JSON.stringify(layout));
  assert.deepEqual(layout,{rail:'4px',railColor:'rgba(255, 255, 255, 0.25)',fill:'4px',fillColor:'rgb(255, 255, 255)',
    laneHeight:'14px',timeSize:'10.5px',timeColor:'rgba(255, 255, 255, 0.55)',gap:'5px',type:'range',appearance:'none'});
  const preview=await c.evaluate(`(()=>{
    const seek=document.querySelector('#seek'),track=seek.parentElement;
    const saved={max:seek.max,value:seek.value,dragging:seek.dataset.dragging,style:track.getAttribute('style'),elapsed:document.querySelector('#elapsed').textContent};
    try{
      seek.max=120000;
      return [0,30000,60000,120000].map(at=>{
        seek.value=at;seek.dispatchEvent(new Event('input'));
        return [document.querySelector('#elapsed').textContent,getComputedStyle(track,'::after').width,track.clientWidth];
      });
    }finally{
      seek.max=saved.max;seek.value=saved.value;
      if(saved.dragging===undefined)delete seek.dataset.dragging;else seek.dataset.dragging=saved.dragging;
      if(saved.style===null)track.removeAttribute('style');else track.setAttribute('style',saved.style);
      document.querySelector('#elapsed').textContent=saved.elapsed;
    }
  })()`);
  assert.deepEqual(preview.map(p=>p[0]),['0:00','0:30','1:00','2:00']);
  for(const [i,[,width,total]] of preview.entries())assert(Math.abs(parseFloat(width)-Math.max(4,total*[0,.25,.5,1][i]))<1);
  assert.equal(await c.evaluate("document.querySelector('#seek').getAttribute('aria-label')"),'播放进度');
  console.log('PASS: iOS-style track/time labels; fill and time preview at 0/25/50/100%; native range retained');
}catch(error){
  console.log('FAIL: Android scrubber does not match iOS style or drag preview');
  if(error.code!=='ERR_ASSERTION')console.error(error.message);
  process.exitCode=1;
}finally{c.close();}
