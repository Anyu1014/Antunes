import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import vm from 'node:vm';
const root=process.argv[2]||resolve(import.meta.dirname,'../..');
const r=f=>readFileSync(resolve(root,f),'utf8'),app=r('android/app/src/main/assets/app.js');
const editor=app.slice(app.indexOf('function openPlaylistDescriptionEditor('),app.indexOf('function gradientCollectionHTML('));
assert.doesNotMatch(editor,/保存封面|保存简介|data-save-cover/,'editor must not have separate save buttons');
assert.match(editor,/\{title:'歌单编辑',onDone:finish\}/);
assert.match(app,/button\('完成',onDone\)/);
assert(!app.includes("||'添加简介'"), 'no-description owner action must be icon-only');
const slice=(a,b)=>app.slice(app.indexOf(a),app.indexOf(b,app.indexOf(a)));
const callbacks=[],calls=[],screens=[];
const Button=()=>({disabled:false,hidden:false,isConnected:true,handlers:{},addEventListener(k,f){this.handlers[k]=f;},setAttribute(){},scrollIntoView(){},classList:{toggle(){}}});
const input={...Button(),value:''},doneButton=Button(),pick=Button(),status=Button();
const remove=Button(),confirm=Button(),cancelDelete=Button(),confirmPanel={hidden:true};
let preview={replaceWith(image){preview.src=image.src;}};
const form={...Button(),querySelector(s){return ({textarea:input,'[data-pick-cover]':pick,'[role=status]':status,'.playlist-thumb':preview,'[data-delete-playlist]':remove,'[data-confirm-delete]':confirm,'[data-cancel-delete]':cancelDelete,'[data-delete-confirmation]':confirmPanel})[s];}};
let owner=7,deny=false,denyCover=false,cancel=false,afterDescription=null,holdCover=null,mode=false,wentBack=false,closed=false;
const ctx=vm.createContext({
  account:{userId:7},loggedIn:true,accountOwner:()=>owner,sessionGeneration:0,overlayKind:'playlistEditor',
  e:s=>String(s??'').replaceAll('<','&lt;'),icon:name=>name==='chevron'?'<svg data-chevron></svg>':'',count:String,cover:(_,cls)=>`<img class="${cls}">`,coverSize:()=>960,imageURL:s=>s,
  button:(label,fn,cls='',aria='')=>{callbacks.push(fn);return `<button class="${cls}" aria-label="${aria}">${label}</button>`;},
  round:()=>'<button></button>',back(){wentBack=true;},closeOverlay(){closed=true;},toast(){},render(){},play(){},selecting:false,liked:new Set(),downloaded:new Set(),player:{queue:[],index:0},listTracks:[],
  picked:new Set(),empty:()=>'',cache:new Map([[ 'playlist-4',{playlist:{id:4,tracks:[{id:91}]}} ]]),playlists:[{id:4}],
  route:{kind:'playlist',id:4},detail:{id:4},prefs:{collectionCoverStyle:'classic'},matchMedia:()=>({matches:mode}),
  showOverlay:(kind,html,opts)=>screens.push({kind,html,...opts}),$:selector=>selector.endsWith('.sheet-header button')?doneButton:form,document:{createElement:()=>({})},updatePlaylistPage(){},time:()=>'',navigate(){},
  api:async(path,data)=>{calls.push([path,{...data}]);if(deny)throw Error('fixture offline');if(path==='/playlist/desc/update')afterDescription?.();return {code:200};},
  native:async(op,data)=>{calls.push([op,data&&{...data}]);if(op==='pickPlaylistCover')return cancel?null:'QUJD';if(holdCover)await holdCover;if(denyCover)throw Error('fixture upload failed');return 'https://p1.music.126.net/new.jpg';}
});
vm.runInContext(slice('function trackRow(', 'function selectBar(')+slice('function playlistLocateButton(', 'function filterPlaylist('),ctx);
const own={id:4,name:'歌单',creator:{userId:7,nickname:'作者甲'},description:''};
const publicList={...own,creator:{userId:8,nickname:'作者乙'}};
for(const style of ['classic','gradient','gradientDimmed','gradientFlow']){
  mode=style==='gradientFlow';ctx.prefs={collectionCoverStyle:style,collectionCoverStyleLandscape:style};
  const html=ctx.playlistDetails(own,[]);
  assert.match(html,new RegExp('(?:playlist-creator|collection-by)"[^>]*>[\\s\\S]{0,350}作者甲[\\s\\S]{0,80}playlist-description-inline[^>]*><svg data-chevron></svg></button>'));
  assert.equal((html.match(/aria-label="打开歌单编辑"/g)||[]).length,1);
  assert.doesNotMatch(ctx.playlistDetails(publicList,[]),/添加简介|playlist-description-inline/);
  const filled=ctx.playlistDetails({...own,description:'已有简介'},[]);
  assert.match(filled,/已有简介/);assert.doesNotMatch(filled,/playlist-description-inline/);
}
ctx.openPlaylistDescriptionEditor(publicList);assert.equal(screens.length,0);
ctx.openPlaylistDescriptionEditor({...own,description:'\n原简介'});
assert.equal(screens.at(-1).kind,'playlistEditor','owner playlist must open in the editor popup');
assert.equal(screens.at(-1).title,'歌单编辑');
assert.match(app,/kind==='playlistEditor'\?' playlist-editor-sheet'/);
assert.match(app,/showOverlay\('playlistDescription',`<div class="pad playlist-description-full">/);
const css=r('android/app/src/main/assets/app.css');
assert.match(css,/\.sheet\.playlist-picker-sheet,\.sheet\.playlist-editor-sheet\{inset:0;margin:auto;/);
assert.match(css,/\.playlist-editor-sheet \.sheet-body\{[^}]*overflow-y:auto/);
assert.equal(input.value,'\n原简介');
assert.match(screens.at(-1).html,/更换封面[\s\S]*歌单简介[\s\S]*删除歌单/);
const finish=()=>screens.at(-1).onDone(),tick=()=>new Promise(r=>setImmediate(r));
await finish();assert(closed);assert.equal(calls.length,0,'unchanged editor closes without a write');
ctx.openPlaylistDescriptionEditor({...own,description:'\n原简介'});closed=false;
input.value='';await finish();
assert.deepEqual(calls.splice(0),[['/playlist/desc/update',{id:4,desc:''}]]);
assert(closed);assert.equal(ctx.cache.get('playlist-4').playlist.description,'');
ctx.openPlaylistDescriptionEditor(own);closed=false;
cancel=true;pick.handlers.click();await tick();assert.equal(preview.src,undefined);
cancel=false;pick.handlers.click();await tick();assert.equal(preview.src,'data:image/jpeg;base64,QUJD');
assert.deepEqual(calls.splice(0).map(([op])=>op),['pickPlaylistCover','pickPlaylistCover'],'selection must not upload');
input.value='新简介';deny=true;await finish();
assert.equal(status.textContent,'fixture offline');assert.equal(input.value,'新简介');assert(!closed);
assert.deepEqual(calls.splice(0).map(([op])=>op),['/playlist/desc/update']);
deny=false;denyCover=true;await finish();
assert.deepEqual(calls.splice(0),[['/playlist/desc/update',{id:4,desc:'新简介'}],['updatePlaylistCover',{id:4,jpeg:'QUJD'}]]);
assert.equal(ctx.cache.get('playlist-4').playlist.description,'新简介');
assert.equal(status.textContent,'fixture upload failed');assert(!closed);
assert.equal(preview.src,'data:image/jpeg;base64,QUJD');
denyCover=false;
let releaseCover;holdCover=new Promise(resolve=>{releaseCover=resolve;});
const saving=finish();await tick();await finish();
assert(doneButton.disabled);assert(!closed);
assert.deepEqual(calls.splice(0),[['updatePlaylistCover',{id:4,jpeg:'QUJD'}]],'retry only the failed field; ignore double tap');
releaseCover();await saving;holdCover=null;
assert(closed);assert.equal(ctx.detail.coverImgUrl,'https://p1.music.126.net/new.jpg');
assert.equal(ctx.cache.get('playlist-4').playlist.tracks[0].id,91);
ctx.openPlaylistDescriptionEditor({...own,description:'新简介'});closed=false;
pick.handlers.click();await tick();calls.length=0;
input.value='过长'.repeat(501);await finish();assert.match(status.textContent,/1000/);assert.equal(calls.length,0);assert(!closed);
input.value='失败后保留';owner=8;await finish();assert.equal(calls.length,0);
owner=7;afterDescription=()=>{owner=8;};await finish();afterDescription=null;
assert.deepEqual(calls.splice(0).map(([op])=>op),['/playlist/desc/update'],'account switch blocks cover upload');
assert(!closed);owner=7;
const count=calls.length;
confirm.handlers.click();await tick();assert.equal(calls.length,count,'hidden confirmation cannot delete');
remove.handlers.click();assert.equal(confirmPanel.hidden,false);assert.equal(calls.length,count);
cancelDelete.handlers.click();assert.equal(confirmPanel.hidden,true);assert.equal(input.value,'失败后保留');
remove.handlers.click();deny=true;confirm.handlers.click();await tick();
assert.equal(status.textContent,'fixture offline');assert(!closed&&!wentBack);assert(ctx.cache.has('playlist-4'));
deny=false;confirm.handlers.click();await tick();
assert.deepEqual(calls.pop(),['/playlist/remove',{ids:'[4]'}]);assert(closed&&wentBack);
assert(!ctx.cache.has('playlist-4'));assert.equal(ctx.playlists.length,0);
ctx.openPlaylistDescriptionEditor({...own,specialType:5});
assert(!screens.at(-1).html.includes('删除歌单'),'built-in Liked Songs must not offer deletion');
const ios=r('Sources/Kumone/Features/Detail/PlaylistDetailView.swift'),gradient=r('Sources/Kumone/Features/Detail/GradientCollectionPage.swift');
assert.match(ios,/Text\(creator\.nickname\)[\s\S]{0,440}if needsDescription \{\s*playlistEditorChevron/);
assert.match(gradient,/Text\(author\)\.lineLimit\(1\)[\s\S]{0,180}if !hasDescription, let editDescription \{\s*Button\(action: editDescription\) \{\s*Image\(systemName: "arrow.right"/);
assert.match(ios,/private var playlistEditorChevron:[\s\S]*?Image\(systemName: "chevron.right"\)[\s\S]*?\.accessibilityLabel\("打开歌单编辑"\)/);
assert.match(ios,/private func regularHeader[\s\S]*?Text\(creator\.nickname\)[\s\S]*?\.isEmpty \{\s*playlistEditorChevron/);
const iosSheet=ios.slice(ios.indexOf('private struct PlaylistDescriptionSheet:'));
assert.match(iosSheet,/PhotosPicker\(selection:/);
assert.doesNotMatch(iosSheet,/Button\("保存封面"\)|Button\("保存简介"\)/);
assert.match(iosSheet,/Button\("完成"\) \{ finish\(\) \}\.disabled\(busy\)/);
assert.match(iosSheet,/try await onSave\(description, nil\)[\s\S]*?original = description[\s\S]*?try await onSave\(nil, jpeg\)[\s\S]*?self\.jpeg = nil[\s\S]*?dismiss\(\)[\s\S]*?catch/);
assert.match(ios,/guard editable, let scope, let binding, owner == account\.authenticatedAccountID/);
assert.match(ios,/navigationTitle\(editable \? "歌单编辑" : "歌单简介"\)/);
assert.match(ios,/Button\("删除歌单", role: \.destructive\) \{ confirmDeletion = true \}/);
assert.match(ios,/\.confirmationDialog\("确认删除歌单？"[^\n]*\n\s*Button\("确认删除", role: \.destructive\) \{ deletePlaylist\(\) \}/);
const native=r('android/app/src/main/java/com/antunes/app/MusicApi.java'),api=r('Sources/Kumone/Core/API/MusicAPI.swift');
for(const source of [native,api]){
  assert.match(source,/"\/playlist\/desc\/update"/);assert.match(source,/"\/nos\/token\/alloc"[\s\S]*?\bPOST\b|\/nos\/token\/alloc[\s\S]*?uploadPlaylistCoverJPEG/);
  assert.match(source,/"\/playlist\/cover\/update"[\s\S]*?coverImgId/);
}
assert.match(native,/webEncrypted = path.equals\("\/nos\/token\/alloc"\) \|\| path.equals\("\/playlist\/cover\/update"\)/);
assert.match(api,/playlistCoverWebRequest\("\/nos\/token\/alloc"/);
assert.match(api,/playlistCoverWebRequest\("\/playlist\/cover\/update"/);
console.log('PLAYLIST_EDITOR: Done-only save, no-op, partial failure/retry, double tap, account guard, delete confirmation PASS');
