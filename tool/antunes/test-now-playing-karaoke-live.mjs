import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';

const c=await connect();
let breakpoint;
try {
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
    try {
      const result=await c.call('Debugger.evaluateOnCallFrame',{callFrameId:ev.params.callFrames[0].callFrameId,expression:`window.__karaokeTest={
        async run(){
          const original={player,lyrics,translations,romaji,lyricID,lyricSync,showLyric,activeLine,lyricsBar,loadNowComments,karaoke:prefs.karaoke};
          const selected=player.queue[player.index];
          if(!selected)throw Error('需要一首已载入的歌曲');
          const click=async s=>{const n=document.querySelector(s);if(!n)throw Error('missing '+s);n.click();await Promise.resolve();};
          const words=s=>Array.from(document.querySelectorAll(s+' .lyric-word'),w=>Number.parseFloat(w.style.getPropertyValue('--progress')));
          const style=s=>{const w=document.querySelector(s+' .lyric-word');return !!w&&getComputedStyle(w).backgroundImage.startsWith('linear-gradient');};
          const fixture=[
            {at:1000,text:'甲乙',words:[{at:1000,duration:1000,text:'甲'},{at:2000,duration:1000,text:'乙'}]},
            {at:4000,text:'丙丁',words:[{at:4000,duration:1000,text:'丙'},{at:5000,duration:1000,text:'丁'}]}
          ];
          try {
            closeOverlay(true);player={...player,position:1500,playing:false,loading:false};lyrics=fixture;prefs.karaoke=true;translations=[];romaji=[];lyricID=selected.id;lyricsBar=false;loadNowComments=()=>{};
            await click('.mini-info');
            const defaultLyrics=!!document.querySelector('.np-page.lyrics-mode');
            const positions=[1500,2500,4250,1750];
            async function capture(full){
              const selector=full?'.lyric-line.active':'#np-strip p.on';
              const values=positions.map(position=>{player.position=position;updateNowPlaying();return words(selector);});
              return {values,gradient:style(selector)};
            }
            const toggle='.np-bottom [aria-label="歌词"]';
            if(!defaultLyrics)await click(toggle);
            const full=await capture(true);
            await click(toggle);
            const compact=await capture(false);
            await click(toggle);
            const returnProgress=words('.lyric-line.active');
            closeOverlay(true);await click('.mini-cover');const artworkOpensLyrics=!!document.querySelector('.np-page.lyrics-mode');
            if(artworkOpensLyrics)await click(toggle);
            lyrics=[{at:1000,text:'只有行时间'}];player.position=1500;activeLine=-2;updateNowPlaying(true);
            const plainText=document.querySelector('#np-strip p.on')?.textContent;
            // The 85% singing interval of a 2s line is 1.7s: 425ms at each of four characters.
            lyrics=[{at:1000,text:'只有行时'},{at:3000,text:'下句'}];player.position=1637.5;
            activeLine=-2;updateNowPlaying(true);
            const estimatedCompact=words('#np-strip p.on');
            await click(toggle);
            const estimatedFull=words('.lyric-line.active');
            prefs.karaoke=false;
            await click(toggle);
            const disabled=words('#np-strip p.on').length===0;
            return {defaultLyrics,artworkOpensLyrics,full,compact,returnProgress,plainText,estimatedCompact,estimatedFull,disabled};
          } finally {
            closeOverlay(true);({player,lyrics,translations,romaji,lyricID,lyricSync,showLyric,activeLine,lyricsBar,loadNowComments}=original);prefs.karaoke=original.karaoke;
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
  const result=await c.evaluate('window.__karaokeTest.run()');
  console.log(JSON.stringify(result));
  const expected=[[50,0],[100,50],[25,0],[75,0]];
  assert.deepEqual(result,{
    defaultLyrics:true,artworkOpensLyrics:true,full:{values:expected,gradient:true},compact:{values:expected,gradient:true},
    returnProgress:[75,0],plainText:'只有行时间',estimatedCompact:[100,50,0,0],estimatedFull:[100,50,0,0],disabled:true
  });
  console.log('PASS: both mini-player entry points open lyrics; timed and estimated word percentages, gradients, seek and off setting match');
} catch(error) {
  console.log('FAIL: default lyrics or synchronized word highlighting did not match');
  if(error.code!=='ERR_ASSERTION')console.error(error.message);
  process.exitCode=1;
} finally {
  if(breakpoint)await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint}).catch(()=>{});
  await c.evaluate('delete window.__karaokeTest').catch(()=>{});
  await c.call('Debugger.disable');c.close();
}
