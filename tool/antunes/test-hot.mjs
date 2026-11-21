import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';
const c=await connect();
try {
 const scripts=[];c.onEvent(ev=>{if(ev.method==='Debugger.scriptParsed')scripts.push(ev.params);});await c.call('Debugger.enable');
 const app=scripts.filter(s=>s.url==='https://app.kumone.local/hot-app.js').at(-1);assert(app,'live hot source missing');
 const source=(await c.call('Debugger.getScriptSource',{scriptId:app.scriptId})).scriptSource;
 assert(!source.includes('setupPage'));assert(!source.includes('开始之前'));assert(!source.includes('status.configured'));
 const r=await c.evaluate(`({heading:document.querySelector('h1')?.textContent,gate:!!document.querySelector('#setup-form'),native:typeof KumoneNative,tabs:document.querySelectorAll('nav button').length,overflow:document.documentElement.scrollWidth>innerWidth})`);
 assert(['推荐','精选','漫游','我的','搜索','歌单','专辑','歌手','每日推荐','已下载','最近播放','音乐云盘','我的收藏'].includes(r.heading));assert.equal(r.gate,false);assert.equal(r.native,'object');const prefs=await c.evaluate(`JSON.parse(localStorage.getItem('preferences')||'{}')`);const {navigationTabs}=await import('../../android/app/src/main/assets/core.mjs');const expected=navigationTabs(prefs).length;assert.equal(r.tabs,expected===1?0:expected);assert.equal(r.overflow,false);
 console.log('SIMULATOR: live-source=updated; gate=absent; native-bridge=ready; tabs=settings-aware; exit=0');
} finally {c.close();}
