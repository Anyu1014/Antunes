import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';

const c=await connect();
let breakpoint;
try{
  const scripts=[];
  c.onEvent(ev=>{if(ev.method==='Debugger.scriptParsed')scripts.push(ev.params)});
  await c.call('Debugger.enable');
  const app=scripts.filter(s=>/^https:\/\/app\.kumone\.local\/(hot-)?app\.js$/.test(s.url)).at(-1);
  assert(app,'app script missing');
  const {scriptSource}=await c.call('Debugger.getScriptSource',{scriptId:app.scriptId});
  const line=scriptSource.split('\n').findIndex(s=>s.startsWith('function updateNowPlaying(force='));
  assert(line>=0,'updateNowPlaying missing');
  const ready=Promise.withResolvers();
  c.onEvent(async ev=>{
    if(ev.method!=='Debugger.paused')return;
    try{
      const result=await c.call('Debugger.evaluateOnCallFrame',{callFrameId:ev.params.callFrames[0].callFrameId,expression:`window.__lyricHighlightCheck=()=>{
        const saved={player,lyrics,translations,romaji,lyricID,showLyric,activeLine,loadNowComments};
        const track=player.queue[player.index];
        if(!track)throw Error('need one loaded song');
        try{
          lyrics=Array.from({length:5},(_,i)=>({at:i*2000,text:'测试',words:[{at:i*2000,duration:600,text:'测'},{at:i*2000+600,duration:600,text:'试'}]}));
          translations=[];romaji=[];lyricID=track.id;loadNowComments=()=>{};
          player={...player,position:0,duration:10000,playing:false};
          openNowPlaying(true);
          const samples=[1500,2150,3500,4150,6150,250,4150].map(position=>{
            player.position=position;updateNowPlaying();
            const lines=[...document.querySelectorAll('#np-visual .lyric-line')];
            const rows=lines.map(n=>{
              const words=[...n.querySelectorAll('.lyric-word')],style=getComputedStyle(words[0]);
              return {active:n.classList.contains('active'),gradient:style.backgroundImage!=='none',color:style.color,
                progress:words.map(w=>Number.parseFloat(w.style.getPropertyValue('--progress'))||0)};
            });
            return {position,rows};
          });
          toggleLyrics();
          player.position=250;updateNowPlaying();
          const compact=document.querySelector('#np-strip p.on .lyric-word');
          return {samples,strip:{progress:Number.parseFloat(compact.style.getPropertyValue('--progress')),gradient:getComputedStyle(compact).backgroundImage!=='none'}};
        }finally{
          closeOverlay(true);({player,lyrics,translations,romaji,lyricID,showLyric,activeLine,loadNowComments}=saved);
        }
      };true`,returnByValue:true});
      if(result.exceptionDetails)throw Error(JSON.stringify(result.exceptionDetails));
      await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint});breakpoint=null;ready.resolve();
    }catch(error){ready.reject(error)}finally{await c.call('Debugger.resume')}
  });
  breakpoint=(await c.call('Debugger.setBreakpointByUrl',{url:app.url,lineNumber:line+1})).breakpointId;
  await c.evaluate("window.dispatchEvent(new CustomEvent('playback',{detail:{}}))");
  await Promise.race([ready.promise,new Promise((_,reject)=>{setTimeout(()=>reject(Error('breakpoint timeout')),5000).unref()})]);
  const {samples,strip}=await c.evaluate('window.__lyricHighlightCheck()');
  console.log(JSON.stringify({samples:samples.map(({position,rows})=>({position,active:rows.findIndex(x=>x.active),painted:rows.flatMap((x,i)=>x.gradient?[i]:[]),oldFull:rows.some(x=>!x.active&&x.progress.includes(100))})),strip}));
  for(const {position,rows} of samples){
    const active=Math.floor(position/2000);
    assert.deepEqual(rows.map(x=>x.active),rows.map((_,i)=>i===active));
    for(const [i,row] of rows.entries()){
      assert.equal(row.gradient,i===active,`position=${position} row=${i} has wrong highlight`);
      if(i!==active)assert.match(row.color,/^rgba\(255, 255, 255, 0\.27/);
    }
  }
  assert(samples.some(s=>s.rows.some(r=>!r.active&&r.progress.includes(100))),'fixture did not leave completed inline progress on old rows');
  assert.equal(strip.gradient,true);
  assert(Math.abs(strip.progress-100*250/600)<0.001);
  console.log('PASS: only the current full lyric line is highlighted after transitions and seeks; compact wipe retained');
}catch(error){
  console.log('FAIL: '+error.message.split('\n')[0]);process.exitCode=1;
}finally{
  if(breakpoint)await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint}).catch(()=>{});
  await c.evaluate('delete window.__lyricHighlightCheck').catch(()=>{});
  await c.call('Debugger.disable');c.close();
}
