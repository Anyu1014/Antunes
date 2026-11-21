import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {currentLyric,escapeHTML,time} from '../../android/app/src/main/assets/core.mjs';
const source=readFileSync(process.argv[2]||new URL('../../android/app/src/main/assets/app.js',import.meta.url),'utf8');
const extract=(name,next)=>source.slice(source.indexOf(`function ${name}(`),source.indexOf(`function ${next}(`));
const nodes={'#np-strip':{innerHTML:''},'#seek':{dataset:{},parentElement:{style:{setProperty(){}}}},'#elapsed':{},'#remaining':{}};
const lines=[{at:5000,text:'第一行'},{at:10000,text:'第二行'},{at:20000,text:'第三行'}];
const context=vm.createContext({$:key=>nodes[key],lyrics:lines,prefs:{karaoke:false},currentLyric,e:escapeHTML,time,overlayKind:'nowPlaying',showLyric:false,activeLine:-2,player:{queue:[{duration:30000}],index:0,position:0,duration:30000}});
vm.runInContext(extract(source.includes('function lyricWords(')?'lyricWords':'renderStrip','renderLyrics')+extract('updateNowPlaying','openSleep'),context);
try{
 for(const position of [0,4999,5000,9999,10000,19999,20000,30000,6000]){
  context.player.position=position;
  vm.runInContext('updateNowPlaying()',context);
  const expected=lines[Math.max(0,currentLyric(lines,position))].text;
  const actual=nodes['#np-strip'].innerHTML.match(/<p class="on">(.*?)<\/p>/)?.[1];
  assert.equal(actual,expected,`position=${position}`);
  assert.equal(nodes['#seek'].value,String(position));
 }
 context.lyrics=[];context.activeLine=-2;vm.runInContext('updateNowPlaying()',context);
 assert.match(nodes['#np-strip'].innerHTML,/暂无歌词/);
 console.log('PASS: playback timestamps=0,4999,5000,9999,10000,19999,20000,30000,6000; strip=matching; seek=matching; empty=handled');
}catch(error){console.log(`FAIL: ${error.message.replaceAll('\n',' ')}`);process.exitCode=1;}
