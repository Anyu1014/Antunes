import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import vm from 'node:vm';

const dir=process.argv[2]||resolve(import.meta.dirname,'../..');
const read=path=>readFileSync(resolve(dir,path),'utf8');
const app=read('android/app/src/main/assets/app.js');
assert.match(app, /listRow\('自定义个人简介','[a-zA-Z]+',openCustomProfileBio\)/, 'Android settings lack the custom profile bio editor');

const fixture={userId:11, nickname:'Fixture', signature:'来自网易云音乐'};
const ctx=vm.createContext({
  loggedIn:true, account:fixture, prefs:{}, playlists:[], sessionGeneration:4,
  e:value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c]),
  savePrefs(){}, write(key,contents){assert.equal(key,'preferences');ctx.saved=structuredClone(contents);},
  closeOverlay(){}, formSheet(title,body,verb,submit){ctx.editor={title,body,verb,submit};},
  header:()=>'', round:()=>'', listRow:()=>'', cover:()=>'', icon:()=>'', button:label=>label,
  newPlaylist(){}, openSearchFromLibrary(){}, setTimeout(){},
});
const slice=(start,end)=>app.slice(app.indexOf(start),app.indexOf(end));
vm.runInContext(slice('const accountOwner=', 'function resetAccountSession(')
  +slice('const profileBioKey=', '// “我的音乐”')
  +slice('const LIBRARY_ROWS=', '// 听歌排行')
  +slice('function openCustomProfileBio(', 'function confirmAction('),ctx);

assert((await ctx.libraryPage()).includes(fixture.signature));
ctx.openCustomProfileBio();
assert.equal(ctx.editor.verb,'保存');
assert.match(ctx.editor.body,/value=""/);
ctx.editor.submit(new Map([['bio','  <tag>本机简介 & "引号"</tag>  ']]));
let html=await ctx.libraryPage();
assert(html.includes('&lt;tag&gt;本机简介 &amp; &quot;引号&quot;&lt;/tag&gt;'));
assert(!html.includes('<tag>')&&!html.includes(fixture.signature));
assert.equal(fixture.signature,'来自网易云音乐','official profile stays untouched');
ctx.prefs=structuredClone(ctx.saved);
ctx.openCustomProfileBio();
assert.match(ctx.editor.body,/value="&lt;tag&gt;本机简介 &amp; &quot;引号&quot;&lt;\/tag&gt;"/);
const submitOld=ctx.editor.submit;
ctx.account={...fixture,userId:22,signature:'另一位用户的官方简介'};
assert((await ctx.libraryPage()).includes(ctx.account.signature));
assert.throws(()=>submitOld(new Map([['bio','不要写到另一账号']])), /账号已切换/);
ctx.account=fixture;
ctx.openCustomProfileBio();
ctx.editor.submit(new Map([['bio',' \t\n ']]));
assert.deepEqual(ctx.saved,{});
assert((await ctx.libraryPage()).includes(fixture.signature));
ctx.account={...fixture,signature:''};
assert((await ctx.libraryPage()).includes('Antunes，随心而听'));
ctx.loggedIn=false;
assert((await ctx.libraryPage()).includes('登录'));

const settings=read('Sources/Kumone/Features/Pages/SettingsView.swift');
const storage=read('Sources/Kumone/Core/Storage/SettingsManager.swift');
assert.match(settings,/Button\("自定义个人简介"\)/);
assert.match(settings,/guard account.authenticatedAccountID == userID else \{ return \}/);
assert.match(storage,/UserDefaults\.standard\.set\(customProfileBios, forKey: Keys\.customProfileBios\)/);
assert.match(storage,/bio\.trimmingCharacters\(in: \.whitespacesAndNewlines\)/);
assert.match(storage,/customProfileBios\.removeValue\(forKey: key\)/);
assert.match(storage,/return custom\.isEmpty \? profile\.signature : custom/);
for(const view of ['IOSMainWindow','SidebarView']){
  assert.match(read(`Sources/Kumone/Features/${view}.swift`),/settings\.displayedProfileBio\(for: profile\)/);
}
console.log('CUSTOM_PROFILE_BIO: Android default/override/escaping/persistence/account-isolation/clear PASS; iOS source contracts PASS');
