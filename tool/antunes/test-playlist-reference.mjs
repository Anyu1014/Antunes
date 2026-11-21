import assert from 'node:assert/strict';
import {connect} from './cdp.mjs';
const c=await connect();
async function wait(expr){for(let i=0;i<200;i++){try{if(await c.evaluate(expr))return;}catch{}await new Promise(r=>setTimeout(r,100));}throw new Error('Timed out: '+expr);}
try{
 if(!await c.evaluate(`document.querySelector('#page').dataset.route==='home'`)){await c.evaluate(`document.querySelector('nav button[aria-label="推荐"]')?.click()`);}
 await wait(`document.querySelector('#page').dataset.route==='home'&&!!document.querySelector('.shelf .card.playlist')`);
 await c.evaluate(`document.querySelector('.shelf .card.playlist').click()`);await wait(`document.querySelector('#page').dataset.route==='playlist'&&!!document.querySelector('.playlist-summary')`);
 const data=await c.evaluate(`(()=>{const cover=document.querySelector('.playlist-cover').getBoundingClientRect(),info=document.querySelector('.playlist-summary-info').getBoundingClientRect(),buttons=[...document.querySelectorAll('.playlist-nav-button')],row=document.querySelector('.playlist-track'),img=row?.querySelector('.playlist-track-cover')?.getBoundingClientRect();return {cover:{x:cover.x,y:cover.y,width:cover.width,height:cover.height},info:{x:info.x,y:info.y},buttons:buttons.length,glass:buttons.every(x=>x.classList.contains('glass')),rows:document.querySelectorAll('.playlist-track').length,rowImage:!!img,play:!!document.querySelector('.playlist-play'),download:!!document.querySelector('[aria-label="下载全部"]'),search:!!document.querySelector('[aria-label="歌单内搜索"]'),plus:!!document.querySelector('[aria-label="收藏歌单"], [aria-label="取消收藏歌单"]'),horizontalOverflow:document.documentElement.scrollWidth>innerWidth};})()`);
 assert(data.cover.x>=15&&data.cover.x<=17);assert(data.info.x>data.cover.x+data.cover.width);assert(Math.abs(data.info.y-data.cover.y)<2);assert.equal(data.buttons,2);assert(data.glass&&data.rows>0&&data.rowImage&&data.play&&data.download&&data.search&&data.plus&&!data.horizontalOverflow,JSON.stringify(data));
 const before=await c.evaluate(`document.querySelectorAll('.playlist-track').length`);
 await c.evaluate(`document.querySelector('[aria-label="歌单内搜索"]').click()`);await wait(`!document.querySelector('#playlist-search').classList.contains('hidden')`);
 await c.evaluate(`(()=>{const i=document.querySelector('#playlist-search input');i.value='__no_such_song_fixture__';i.dispatchEvent(new Event('input',{bubbles:true}));})()`);
 assert.equal(await c.evaluate(`document.querySelectorAll('.playlist-track:not([hidden])').length`),0);
 await c.evaluate(`(()=>{const i=document.querySelector('#playlist-search input');i.value='';i.dispatchEvent(new Event('input',{bubbles:true}));document.querySelector('[aria-label="歌单内搜索"]').click();})()`);
 assert.equal(await c.evaluate(`document.querySelectorAll('.playlist-track:not([hidden])').length`),before);
 await c.evaluate(`document.querySelector('[aria-label="下载全部"]').click()`);await wait(`document.querySelector('#overlay')?.innerText.includes('下载全部')`);
 await c.evaluate(`([...document.querySelectorAll('#overlay button')].find(b=>b.innerText==='取消')).click()`);
 await c.evaluate(`document.querySelector('.playlist-track').dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true}))`);await wait(`!!document.querySelector('#overlay .menu-action')`);
 await c.evaluate(`document.querySelector('#overlay .sheet-header button').click()`);
 await c.evaluate(`document.querySelector('.playlist-duration').click()`);await wait(`!!document.querySelector('#overlay .menu-action')`);
 await c.evaluate(`document.querySelector('#overlay .sheet-header button').click()`);
 const glass=await c.evaluate(`(()=>{const root=document.documentElement,old=root.dataset.glass,buttons=[...document.querySelectorAll('.playlist-nav-button')],result={};for(const mode of ['off','clear','native']){root.dataset.glass=mode;result[mode]=buttons.map(b=>getComputedStyle(b).backdropFilter);}root.dataset.glass=old;return result;})()`);
 assert(glass.off.every(v=>v==='none'));assert(glass.clear.every(v=>v.includes('10px')));assert(glass.native.every(v=>v.includes('20px')));
 console.log(`PLAYLIST: cover=left; metadata=right; tracks=${before}; controls=back/search/play/download/add; search=filters; download=confirm-only; song-menu=longpress/duration; corner-glass=off/10px/20px; PASS`);
}finally{c.close();}
