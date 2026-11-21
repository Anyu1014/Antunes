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
      const result=await c.call('Debugger.evaluateOnCallFrame',{callFrameId:ev.params.callFrames[0].callFrameId,expression:`window.__lyricScrollTest={
        run(){
          const saved={player,lyrics,translations,romaji,lyricID,showLyric,activeLine,loadNowComments};
          const track=player.queue[player.index];
          if(!track)throw Error('Need one loaded track');
          try{
            lyrics=Array.from({length:30},(_,i)=>({at:i*1000,text:'测试歌词 '+i}));
            translations=[];romaji=[];lyricID=track.id;loadNowComments=()=>{};
            player={...player,position:0,duration:35000,playing:false};
            openNowPlaying(true);
            const sheet=document.querySelector('.now-playing');
            sheet.style.animation='none';sheet.scrollTop=0;
            const pager=document.querySelector('#np-pager'),page=document.querySelector('.np-page.lyrics-mode');
            const snapshot=()=>({
              line:Number(document.querySelector('.lyric-line.active')?.dataset.line),
              list:Math.round(page.scrollTop),sheet:Math.round(sheet.scrollTop),pager:Math.round(pager.scrollTop),
              x:Math.round(pager.scrollLeft),documentY:Math.round(window.scrollY),
              top:['.np-head','.np-seek','.np-controls'].map(s=>Math.round(document.querySelector(s).getBoundingClientRect().top))
            });
            return [0,15000,29000,34500,5000].map(position=>{player.position=position;updateNowPlaying(true);return snapshot()});
          }finally{
            closeOverlay(true);({player,lyrics,translations,romaji,lyricID,showLyric,activeLine,loadNowComments}=saved);
          }
        }
      };true`,returnByValue:true});
      if(result.exceptionDetails)throw Error(JSON.stringify(result.exceptionDetails));
      await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint});breakpoint=null;
      ready.resolve();
    }catch(e){ready.reject(e)}finally{await c.call('Debugger.resume')}
  });
  breakpoint=(await c.call('Debugger.setBreakpointByUrl',{url:app.url,lineNumber:line+1})).breakpointId;
  await c.evaluate("window.dispatchEvent(new CustomEvent('playback',{detail:{}}))");
  await Promise.race([ready.promise,new Promise((_,reject)=>{setTimeout(()=>reject(Error('breakpoint timeout')),5000).unref()})]);
  const samples=await c.evaluate('window.__lyricScrollTest.run()');
  console.log(JSON.stringify(samples));
  assert.deepEqual(samples.map(s=>s.line),[0,15,29,29,5]);
  assert(samples[2].list>samples[1].list&&samples[1].list>0&&samples[4].list<samples[1].list,'the lyrics list must still follow forwards and backwards');
  for(const s of samples){
    assert.equal(s.sheet,0,'outer player was scrolled');
    assert.equal(s.pager,0,'pager was scrolled vertically');
    assert.equal(s.x,0,'pager moved horizontally');
    assert.equal(s.documentY,0,'document was scrolled');
    assert.deepEqual(s.top,samples[0].top,'header/progress/controls moved');
  }
  console.log('PASS: lyric list follows through the final line and outro; outer player and controls stay fixed');
}catch(error){
  console.log('FAIL: '+error.message.split('\n')[0]);
  process.exitCode=1;
}finally{
  if(breakpoint)await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint}).catch(()=>{});
  await c.evaluate('delete window.__lyricScrollTest').catch(()=>{});
  await c.call('Debugger.disable');c.close();
}
