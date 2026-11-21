import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';

const c=await connect();
let breakpoint,savedStorage;
try{
  savedStorage=await c.evaluate("localStorage.getItem('preferences')");
  const saved=JSON.parse(savedStorage)||{};
  await c.evaluate(`localStorage.setItem('preferences', ${JSON.stringify(JSON.stringify({...saved,playerMode:'vinyl'}))})`);
  await c.call('Page.enable');
  await c.call('Page.reload',{ignoreCache:true});
  for(let n=0;n<50;n++){
    if(await c.evaluate("!!document.querySelector('.mini-info')").catch(()=>false))break;
    await new Promise(r=>setTimeout(r,100));
  }
  const persisted=JSON.parse(await c.evaluate("localStorage.getItem('preferences')"));
  const cleared=!Object.hasOwn(persisted,'playerMode')&&Object.entries(saved).every(([k,v])=>k==='playerMode'||JSON.stringify(v)===JSON.stringify(persisted[k]));
  const scripts=[];
  c.onEvent(ev=>{if(ev.method==='Debugger.scriptParsed')scripts.push(ev.params)});
  await c.call('Debugger.enable');
  const app=scripts.filter(s=>/^https:\/\/app\.kumone\.local\/(hot-)?app\.js$/.test(s.url)).at(-1);
  assert(app,'app script missing');
  const {scriptSource}=await c.call('Debugger.getScriptSource',{scriptId:app.scriptId});
  const line=scriptSource.split('\n').findIndex(s=>s.startsWith('function updateNowPlaying(force='));
  const ready=Promise.withResolvers();
  c.onEvent(async ev=>{
    if(ev.method!=='Debugger.paused')return;
    try{
      const result=await c.call('Debugger.evaluateOnCallFrame',{callFrameId:ev.params.callFrames[0].callFrameId,expression:`window.__fixedImmersiveCheck=()=>{
        const prior=prefs.playerMode,had=Object.hasOwn(prefs,'playerMode'),savedComments=loadNowComments;
        try{
          if(!player.queue[player.index])throw Error('need a loaded song');
          closeOverlay(true);openSettings();
          const settings=document.querySelector('.settings-sheet').textContent;
          loadNowComments=()=>{};
          const modes=['classic','concise','vinyl','immersive'].map(mode=>{
            prefs.playerMode=mode;openNowPlaying(true);
            const view=document.querySelector('.now-playing');
            return {legacy:mode,layout:view.className,lyrics:!!view.querySelector('.lyrics-mode'),controls:!!view.querySelector('.np-seek-track #seek')&&view.querySelectorAll('.np-bottom .glass').length===3};
          });
          return {hasPicker:settings.includes('播放页模式'),otherSettings:['主题','歌词对齐','玻璃样式','逐字歌词'].every(text=>settings.includes(text)),modes};
        }finally{
          if(had)prefs.playerMode=prior;else delete prefs.playerMode;
          closeOverlay(true);loadNowComments=savedComments;
        }
      };true`,returnByValue:true});
      if(result.exceptionDetails)throw Error(JSON.stringify(result.exceptionDetails));
      await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint});breakpoint=null;ready.resolve();
    }catch(error){ready.reject(error)}finally{await c.call('Debugger.resume')}
  });
  breakpoint=(await c.call('Debugger.setBreakpointByUrl',{url:app.url,lineNumber:line+1})).breakpointId;
  await c.evaluate("window.dispatchEvent(new CustomEvent('playback',{detail:{}}))");
  await Promise.race([ready.promise,new Promise((_,reject)=>{setTimeout(()=>reject(Error('breakpoint timeout')),5000).unref()})]);
  const result={cleared,...await c.evaluate('window.__fixedImmersiveCheck()')};
  console.log(JSON.stringify(result));
  assert.equal(result.hasPicker,false);
  assert.equal(result.otherSettings,true);
  assert.equal(result.cleared,true);
  assert(result.modes.every(r=>r.layout==='now-playing np-immersive'&&r.lyrics&&r.controls));
  console.log('PASS: no mode picker; all legacy inputs use immersive with lyrics and updated controls');
}catch(error){
  console.log('FAIL: Android mode picker or legacy layout still active');
  if(error.code!=='ERR_ASSERTION')console.error(error.message);
  process.exitCode=1;
}finally{
  if(breakpoint)await c.call('Debugger.removeBreakpoint',{breakpointId:breakpoint}).catch(()=>{});
  if(savedStorage!==undefined)await c.evaluate(savedStorage===null?"localStorage.removeItem('preferences')":`localStorage.setItem('preferences',${JSON.stringify(savedStorage)})`).catch(()=>{});
  await c.evaluate('delete window.__fixedImmersiveCheck').catch(()=>{});
  await c.call('Debugger.disable');c.close();
}
