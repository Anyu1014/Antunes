import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';

const c=await connect(), sleep=ms=>new Promise(r=>setTimeout(r,ms));
const metrics=(width,height)=>c.call('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:true});
const tap=async selector=>{
  const p=await c.evaluate(`(()=>{const r=document.querySelector(${JSON.stringify(selector)})?.getBoundingClientRect();return r&&{x:r.x+r.width/2,y:r.y+r.height/2};})()`);
  assert(p&&p.x>0&&p.y>0,selector);
  await c.call('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[p]});
  await c.call('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
};
try{
  await metrics(412,915);await sleep(150);
  await c.evaluate("if(!document.querySelector('.now-playing'))document.querySelector('.mini-info')?.click()");
  await sleep(400);
  assert(await c.evaluate("!!document.querySelector('.np-page.lyrics-mode')"),'portrait lyrics should open');
  await tap('.np-bottom [aria-label="歌词"]');await sleep(420);
  assert(await c.evaluate("!!document.querySelector('.np-cover-wrap')"),'fixture should start in portrait cover mode');
  const layout=()=>c.evaluate(`(()=>{
    const q=s=>document.querySelector(s),visible=n=>!!n?.getClientRects().length;
    const l=q('.np-land-track')?.getBoundingClientRect(),r=q('#np-pager')?.getBoundingClientRect();
    const controls=[...document.querySelectorAll('.np-land-controls button')];
    return {controls:controls.map(b=>b.dataset.transport),coverOnLeft:!!l&&!!r&&l.right<r.left,
      lyrics:!!q('.np-page.lyrics-mode'),noDots:!visible(q('#np-dots')),noPortraitControls:!visible(q('.np-controls'))&&!visible(q('.np-bottom')),
      within:controls.every(b=>{const r=b.getBoundingClientRect();return r.left>=0&&r.right<=innerWidth&&r.top>=0&&r.bottom<=innerHeight;})};
  })()`);
  const expected={controls:['like','previous','toggle','next','comments'],coverOnLeft:true,lyrics:true,noDots:true,noPortraitControls:true,within:true};
  await metrics(900,400);await sleep(420);
  const normal=await layout();
  console.log('LANDSCAPE: '+JSON.stringify(normal));assert.deepEqual(normal,expected);
  const toggle='.np-land-controls [data-transport=comments]';
  const page=()=>c.evaluate(`(()=>{const b=document.querySelector('${toggle}'),p=document.querySelector('#np-pager');return {page:Math.round(p.scrollLeft/p.clientWidth),pressed:b.getAttribute('aria-pressed'),label:b.getAttribute('aria-label')};})()`);
  await tap(toggle);await sleep(440);
  assert.deepEqual(await page(),{page:1,pressed:'true',label:'显示歌词'});
  await tap(toggle);await sleep(440);
  assert.deepEqual(await page(),{page:0,pressed:'false',label:'显示评论'});
  await metrics(667,375);await sleep(300);
  assert.deepEqual(await layout(),expected);
  await metrics(412,915);await sleep(300);
  assert(await c.evaluate("!document.querySelector('.np-land-controls').getClientRects().length&&document.querySelector('.np-bottom').getClientRects().length===1"));
  console.log('PASS: landscape five controls and round-trip comments toggle; narrow landscape fits; portrait controls unchanged');
}catch(error){
  console.log('FAIL: '+error.message.split('\n')[0]);
  process.exitCode=1;
}finally{
  await c.call('Emulation.clearDeviceMetricsOverride').catch(()=>{});
  c.close();
}
