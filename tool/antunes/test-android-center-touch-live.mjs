import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {connect} from './cdp.mjs';

const adb='/Users/y/toolchains/bin/adb',serial=process.env.ANDROID_SERIAL||'emulator-5554';
const shell=(...args)=>execFileSync(adb,['-s',serial,'shell',...args],{encoding:'utf8'});
const [w,h]=shell('wm','size').trim().split('\n').at(-1).match(/(\d+)x(\d+)/).slice(1).map(Number);
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const c=await connect();
try {
  await c.evaluate(`(()=>{
    for(let n=0;n<4&&document.querySelector('#overlay').children.length;n++)window.dispatchEvent(new Event('android-back'));
  })()`);
  for(const [name,selector] of [['library','#page'],['lyrics','.np-page.lyrics-mode']]){
    if(name==='lyrics'){
      await c.evaluate("document.querySelector('.mini-info').click()");
      for(let i=0;i<50;i++){
        if(await c.evaluate("!!document.querySelector('#np-visual .lyric-line')"))break;
        await sleep(100);
      }
    }else{
      assert(await c.evaluate("document.querySelector('#page').dataset.route==='library'"),'start on the Library tab');
    }
    // The page slides up; measure stable content rather than the opening animation.
    if(name==="lyrics")await sleep(500);

    assert(await c.evaluate(`(()=>{const n=document.querySelector('${selector}');if(!n||n.scrollHeight<=n.clientHeight+20)return false;n.scrollTop=0;return true;})()`),name+' requires scrollable content');
    await c.evaluate(`(()=>{
      const events=[];
      const probe=e=>{
        events.push({type:e.type,inside:!!document.querySelector('${selector}')?.contains(e.target),trusted:e.isTrusted,x:Math.round(e.clientX),y:Math.round(e.clientY),target:e.target.closest('[id]')?.id});
        if(e.type==='click'){e.preventDefault();e.stopImmediatePropagation();}
      };
      for(const type of ['pointerdown','click'])document.addEventListener(type,probe,true);
      window.__centerTouch={events,stop(){for(const type of ['pointerdown','click'])document.removeEventListener(type,probe,true);}};
    })()`);
    for(let repeat=0;repeat<3;repeat++)for(const y of [.41,.5,.59])for(const x of [.25,.5,.75]){
      shell('input','touchscreen','tap',String(Math.round(w*x)),String(Math.round(h*y)));
    }
    await sleep(220);
    const events=await c.evaluate('window.__centerTouch.events');
    for(const type of ['pointerdown','click']){
      const received=events.filter(e=>e.type===type&&e.inside&&e.trusted).length;
      assert.equal(received,27,`${name} ${type}: ${JSON.stringify(events.filter(e=>e.type===type))}`);
    }
    const read=()=>c.evaluate(`document.querySelector('${selector}').scrollTop`);
    let swipes=0;
    for(const x of [.28,.5,.72]){
      await c.evaluate(`document.querySelector('${selector}').scrollTop=0`);
      await sleep(100);
      const before=await read();
      const px=String(Math.round(w*x));
      shell('input','touchscreen','swipe',px,String(Math.round(h*.58)),px,String(Math.round(h*.42)),'380');
      await sleep(170);
      assert((await read())-before>20,`${name} swipe at ${x}`);
      swipes++;
    }
    await c.evaluate('window.__centerTouch.stop(); delete window.__centerTouch');
    console.log(`PASS: ${name} center 27/27 trusted taps; ${swipes}/3 swipes scrolled`);
  }
} finally {
  await c.evaluate('window.__centerTouch?.stop(); delete window.__centerTouch').catch(()=>{});
  c.close();
}
