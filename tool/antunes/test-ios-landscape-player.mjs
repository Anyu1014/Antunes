import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const source=readFileSync(process.argv[2]||new URL('../../Sources/Kumone/Features/Player/NowPlayingView.swift',import.meta.url),'utf8');
try{
  const landscape=source.split('private func landscapeImmersiveLayout(')[1].split('private var landscapeTransportRow')[0];
  const transport=source.split('private var landscapeTransportRow')[1].split('#endif')[0];
  assert.match(landscape,/artworkView[\s\S]*trackMetaView[\s\S]*NowPlayingScrubber\(\)[\s\S]*landscapeTransportRow[\s\S]*RegularCommentsPanel[\s\S]*lyricsScroll/,'wide player is not the reference split-layout');
  assert.doesNotMatch(landscape,/RegularColumnSwitch|landscapeUtilityRow/);
  assert.match(transport,/heart\.fill[\s\S]*backward\.fill[\s\S]*playPauseButton\(\)[\s\S]*forward\.fill[\s\S]*regularColumnPage = showsComments \? \.lyrics : \.comments/);
  assert.doesNotMatch(transport,/RoutePickerButton|SoundEffectsButton|cycleRepeatMode|cycleQueueOrder/);
  assert.match(source,/geo.size.width < 720 && geo.size.width <= geo.size.height/);
  console.log('PASS: iOS horizontal layout uses split cover and lyrics/comments with five ordered controls and no top toggle');
}catch(error){console.log('FAIL: '+error.message.split('\n')[0]);process.exitCode=1;}
