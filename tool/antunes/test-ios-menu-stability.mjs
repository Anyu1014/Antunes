import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=process.argv[2]||fileURLToPath(new URL('../../',import.meta.url));
const read=path=>readFileSync(resolve(root,'Sources/Kumone',path),'utf8');
const now=read('Features/Player/NowPlayingView.swift');
const sound=read('Features/Player/SoundEffectsView.swift');
const download=read('Features/Pages/DownloadedMusicView.swift').split('struct TrackDownloadActions: View {')[1].split('struct DownloadCollectionButton: View {')[0];
const manager=read('Core/Storage/DownloadManager.swift');

try{
  for(const label of now.split('.accessibilityIdentifier("immersiveMoreMenu")').slice(0,-1)){
    assert.match(label.slice(label.lastIndexOf('Image(systemName: "ellipsis")')),/\.buttonStyle\(\.plain\)/,'Now Playing menu anchor still uses animated press feedback');
  }
  assert.equal(now.split('.accessibilityIdentifier("immersiveMoreMenu")').length,3);
  assert.match(sound.split('enum SoundEffectsSection')[0],/\.buttonStyle\(\.plain\)/);
  assert.doesNotMatch(download,/@ObservedObject private var downloads/);
  assert.match(download,/DownloadManager\.shared\.trackState\(for: track\.id\)/);
  assert.match(download,/let job = state\.value\.menuJob/);
  assert.match(manager,/\bmenuJob: jobsByTrackID\[state\.trackID\]\.map \{ \.init\(id: \$0\.id, status: \$0\.status\) \}/);
  assert.match(manager,/if new != value \{ value = new \}/);
  for(const title of ['移除下载','暂停下载','取消下载','继续下载','下载']){
    assert(download.includes('actionLabel("'+title+'"'),'missing action: '+title);
  }
  console.log('PASS: three menu anchors are stable; track menu observes its own job; download actions retained');
}catch(error){
  console.log('FAIL: '+error.message.split('\n')[0]);
  process.exitCode=1;
}
