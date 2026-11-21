import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=process.argv[2]||fileURLToPath(new URL('../../',import.meta.url));
const settings=readFileSync(resolve(root,'Sources/Kumone/Core/Storage/SettingsManager.swift'),'utf8');
const ui=readFileSync(resolve(root,'Sources/Kumone/Features/Pages/SettingsView.swift'),'utf8');
try{
  assert.match(settings,/#if os\(iOS\)\s+(?:\/\/[^\n]+\n\s+)?let nowPlayingMode: NowPlayingMode = \.immersive\s+let landscapeNowPlayingStyle: LandscapeNowPlayingStyle = \.immersive\s+#else/,'iOS still accepts a saved playback layout');
  assert.match(settings,/#if os\(macOS\)\s+nowPlayingMode = defaults\.string\(forKey: Keys\.nowPlayingMode\)[^\n]*\s+landscapeNowPlayingStyle = defaults\.string\(forKey: Keys\.landscapeNowPlayingStyle\)[\s\S]*?\s+#endif/);
  assert.match(settings, /for key in \[Keys\.nowPlayingMode, Keys\.landscapeNowPlayingStyle\].*\{\s+defaults\.removeObject\(forKey: key\)/);
  const appearance=ui.slice(ui.indexOf('Section("外观")'),ui.indexOf('Toggle("点击封面打开专辑"'));
  assert.doesNotMatch(appearance,/Picker\("横屏播放页样式"|\$settings\.nowPlayingMode/);
  assert.match(appearance,/#if os\(macOS\)(?:(?!#else)[\s\S])*Picker\("播放页模式"(?:(?!#else)[\s\S])*#endif/);
  console.log('PASS: iOS portrait and wide layout fixed to immersive; macOS picker preserved');
}catch(error){console.log('FAIL: '+error.message.split('\n')[0]);process.exitCode=1;}
