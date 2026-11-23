import {readFileSync} from 'node:fs';
import {connect} from './cdp.mjs';
const source=readFileSync(process.argv[2]||new URL('../../android/app/src/main/assets/app.js',import.meta.url),'utf8');
function section(a,b) {
  const start=source.indexOf(a), end=source.indexOf(b,start+1);
  if(start<0||end<=start)throw new Error('source block not found: '+a);
  return source.slice(start,end);
}
const builders=section('let lyricRows=[],','function lyricFrame(now)')+section('function renderChrome(){','async function control(');
const c=await connect();
try {
  const result=await c.evaluate(`(()=>{
    const stage=document.createElement('div');
    stage.innerHTML='<div id="page"></div><div id="chrome"></div>';
    document.body.append(stage);
    const hidden=document.body.classList.contains('chrome-hidden');
    try {
      const $=selector=>stage.querySelector(selector);
      const e=text=>String(text),cover=()=>'',bind=()=>'',round=()=>'',button=()=>'',icon=()=>'',syncPlayerEdge=()=>{};
      const loadLyrics=()=>{throw new Error('unexpected fetch')};
      const requestAnimationFrame=()=>{throw new Error('unexpected animation frame')};
      const lyricPosition=()=>player.position, fmLyricHost=()=>null;
      const navigationTabs=()=>[['library','我的','user']];
      const player={queue:[{id:42,name:'Fixture',artist:'Fixture',cover:''}],index:0,position:2100,playing:false};
      const lyrics=[{at:0,text:'第一排'},{at:2000,text:'正在显示的歌词'},{at:4000,text:'下一排'}];
      const history=[{}],prefs={},picked=new Set(),account=null,tab='library',selecting=false,lyricsBar=true,lyricID=42,lyricRAF=1,LYRIC_ROW_H=24;
      let route={kind:'messages'},tabsExpanded=false,chromeKey='';
      ${builders}
      renderChrome();
      const first=$('.lyric-track');
      const active=()=>$('.lyric-track .is-cur')?.textContent||'';
      const read=()=>({width:lyricBarW,text:active()});
      const before=read();
      lyricPaint();
      route={kind:'chat'};
      renderChrome();
      const chatHidden=document.body.classList.contains('chrome-hidden')&&!$('.lyric-track');
      route={kind:'messages'};
      renderChrome();
      lyricPaint();
      const last=$('.lyric-track');
      return {before,after:read(),chatHidden,newDOM:first!==last&&!!last,
        freshHighlight:!!last?.querySelector('.is-cur .lyric-word')?.style.getPropertyValue('--progress')};
    } finally{
      stage.remove();
      document.body.classList.toggle('chrome-hidden',hidden);
    }
  })()`);
  console.log('BEFORE_TEXT='+result.before.text);
  console.log('CHAT_CHROME_HIDDEN='+result.chatHidden);
  console.log('SAME_WIDTH='+String(result.before.width===result.after.width));
  console.log('FRESH_DOM='+result.newDOM);
  console.log('AFTER_TEXT='+(result.after.text||'<blank>'));
  console.log('FRESH_HIGHLIGHT='+result.freshHighlight);
  const passed=result.chatHidden&&result.newDOM&&result.before.width>0&&result.before.width===result.after.width&&result.before.text==='正在显示的歌词'&&result.after.text===result.before.text&&result.freshHighlight;
  console.log('CHAT_LYRIC_RESTORE='+(passed?'PASS':'FAIL'));
  process.exitCode=passed?0:1;
} finally {c.close();}
