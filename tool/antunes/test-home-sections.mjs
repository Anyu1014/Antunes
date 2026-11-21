import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import * as core from '../../android/app/src/main/assets/core.mjs';
if(typeof core.navigationTabs!=='function'){console.log('HOME_SECTIONS: visibility controls=missing; FAIL');process.exit(1);}
const keys=['showHome','showExplore','showFM','showSearch'];
assert.deepEqual(core.navigationTabs({}).map(t=>t[0]),['home','explore','fm','library','search']);
for(let mask=0;mask<16;mask++){
 const prefs=Object.fromEntries(keys.map((k,n)=>[k,!!(mask&(1<<n))]));const tabs=core.navigationTabs(prefs).map(t=>t[0]);
 assert(tabs.includes('library'));assert.equal(tabs.length,1+keys.filter(k=>prefs[k]).length);
 for(const [key,tab] of [['showHome','home'],['showExplore','explore'],['showFM','fm'],['showSearch','search']])assert.equal(tabs.includes(tab),prefs[key]);
 if(mask===0)assert.deepEqual(tabs,['library']);
}
console.log('HOME_SECTIONS: defaults=all-enabled; combinations=16/16; library=always; solo-library=no-navigation; PASS');

const source=readFileSync(new URL('../../android/app/src/main/assets/app.js',import.meta.url),'utf8');
const renderer=source.slice(source.indexOf('function renderChrome(){'),source.indexOf('async function control('));
for(let mask=0;mask<16;mask++)for(const hasTrack of [false,true]){
 const prefs=Object.fromEntries(keys.map((k,n)=>[k,!!(mask&(1<<n))]));
 const chrome={innerHTML:''},classes=new Map(),page={classList:{toggle:(key,on)=>classes.set(key,on)}};
 const context={prefs,navigationTabs:core.navigationTabs,player:{queue:hasTrack?[{name:'Fixture',artist:'Test',cover:''}]:[],index:0,playing:false},tab:'library',$:id=>id==='#chrome'?chrome:page,e:core.escapeHTML,icon:()=>'',cover:()=>'',round:()=>'<button></button>',button:(text,fn,cls='')=>'<button class="'+cls+'">'+text+'</button>',openNowPlaying(){},switchTab(){},control(){}};
 vm.runInNewContext(renderer+';renderChrome();',context);
 assert.equal(chrome.innerHTML.includes('<nav '),mask!==0);
 assert.equal(chrome.innerHTML.includes('class="mini glass"'),hasTrack);
 assert.equal(chrome.innerHTML.includes('search-tab'),false);
 assert.equal(chrome.innerHTML.includes('<span>搜索</span>'),mask!==0&&prefs.showSearch);
 if(mask!==0)assert(chrome.innerHTML.includes('--tab-count:'+core.navigationTabs(prefs).length));
 assert.equal(classes.get('library-only'),mask===0);
}
console.log('CHROME: combinations=32/32; solo-library=navigation-hidden; player=retained; PASS');
