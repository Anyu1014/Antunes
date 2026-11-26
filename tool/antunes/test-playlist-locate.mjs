import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import vm from 'node:vm';
const root=process.argv[2]||resolve(import.meta.dirname,'../..');
const read=p=>readFileSync(resolve(root,p),'utf8');
const source=read('android/app/src/main/assets/app.js');
const start=source.includes('function playlistLocateButton(')?'function playlistLocateButton(':'function playlistDetails(';
const code=source.slice(source.indexOf(start),source.indexOf('function filterPlaylist('));
const buttons=[];let scrolled=0,queryCleared=false,searchClosed=false,blurred=false;
const input={value:'hidden song',blur(){blurred=true;}};
const row={scrollIntoView(options){assert.equal(options.block,'center');scrolled++;}};
const context={loggedIn:false,prefs:{collectionCoverStyle:'classic'},player:{queue:[{id:2}],index:0},listTracks:[{id:1},{id:2}],selecting:false,picked:new Set(),
 e:String,cover:()=>'',count:String,icon:()=>'',playlistTrackRow:()=>'<div></div>',empty:()=>'',back(){},play(){},
 button:(label,fn,cls='',aria='')=>`<button class="${cls}" aria-label="${aria}">${label}</button>`,
 round:(icon,fn,aria,cls='')=>{buttons.push({aria,fn});return `<button class="${cls}" aria-label="${aria}"></button>`;},
 $:selector=>selector==='#playlist-search input'?input:selector==='#playlist-search'?{classList:{add(name){searchClosed=name==='hidden';}}}:selector==='.playlist-track[data-track-id="2"]'?row:null,
 filterPlaylist:value=>{queryCleared=value==='';},matchMedia:()=>({matches:false})};
vm.createContext(context);vm.runInContext(code,context);
const info={id:7,name:'Fixture',trackCount:2,playCount:0};
let html=context.playlistDetails(info,context.listTracks);
assert(html.includes('aria-label="定位当前歌曲"'),'current playlist member must have a locate button');
assert(html.indexOf('定位当前歌曲')>html.indexOf('收藏歌单'),'locate button must be the rightmost action');
buttons.find(b=>b.aria==='定位当前歌曲').fn();
assert.equal(scrolled,1);assert(queryCleared&&searchClosed&&blurred&&input.value==='');
context.player.queue=[{id:99}];html=context.playlistDetails(info,context.listTracks);assert(!html.includes('定位当前歌曲'));
context.player.queue=[];html=context.playlistDetails(info,context.listTracks);assert(!html.includes('定位当前歌曲'));
console.log('ANDROID: member=visible/rightmost; nonmember/empty=hidden; locate=clear-filter+center; PASS');
const ios=read('Sources/Kumone/Features/IOSMainWindow.swift');
const mini=ios.slice(ios.indexOf('struct IOSMiniPlayerBar:'),ios.indexOf('// MARK: - iOS Library View'));
assert(!mini.includes('carouselGesture')&&!mini.includes('neighbor(offset:')&&!mini.includes('dragOffset'));
assert(mini.includes('Button(action: showNowPlaying)')&&mini.includes('Button(action: player.previous)')&&mini.includes('Button(action: player.next)'));
assert(mini.includes('.simultaneousGesture(expandGesture)'));
console.log('IOS_STATIC: horizontal carousel removed; tap/upward-open and skip buttons retained; PASS');
const detail=read('Sources/Kumone/Features/Detail/PlaylistDetailView.swift');
assert(detail.includes('trackIDs.contains(id)')&&detail.includes('accessibilityLabel("定位当前歌曲")'));
assert(detail.includes('proxy.scrollTo(id, anchor: .center)'));
assert(detail.includes('model.filter = ""'));
assert(detail.includes('compactActionBar')&&detail.match(/currentTrackLocator/g).length>=3);
const tracks=read('Sources/Kumone/Features/Shared/TrackList.swift');assert(tracks.includes('.id(tracks[index].id)'));
console.log('IOS_STATIC: compact/tablet locator conditional; filter cleared; stable row ID centered; PASS');
