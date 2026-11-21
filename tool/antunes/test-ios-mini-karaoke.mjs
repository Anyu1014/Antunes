import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const source=readFileSync(process.argv[2]||new URL('../../Sources/Kumone/Features/Player/NowPlayingView.swift',import.meta.url),'utf8');
const mini=source.split('struct MiniLyricsView: View {')[1];
const renderer=source.split('struct LyricMainText: View {')[1].split('private struct IOSImmersiveLyricsColumn')[0];
try{
  assert.match(mini,/#if os\(iOS\)[\s\S]*?if isVisible, emphasized, let line, !line\.text\.isEmpty,\s*settings\.verbatimLyrics, line\.words\?\.isEmpty == false \{\s*LyricMainText\(/,'the three-line preview still uses plain text for the active line');
  assert.match(mini,/LyricMainText\(\s*line: line, isActive: true, size: 17, weight: \.bold,\s*verbatim: settings\.verbatimLyrics, alignment: \.center, singleLine: true/);
  assert.match(mini,/line\(previous, emphasized: false\)\s+line\(current, emphasized: true\)\s+line\(next, emphasized: false\)/);
  assert.match(renderer,/let alphas = Self\.alphas\(for: line, words: words, at: player\.livePlaybackTime\)/);
  assert.match(renderer,/if singleLine \{[\s\S]*?Text\(Self\.compactWipe\(line\.text, alphas: alphas\)\)[\s\S]*?\.lineLimit\(1\)[\s\S]*?\} else \{\s*LyricText\([\s\S]*?alphas: alphas/);
  assert.match(source,/isVisible: !showLyricsOnMobile && !showQueueOnMobile,\s+onOpen: showImmersiveLyrics/);
  assert.match(source,/IOSImmersiveLyricsColumn\(isVisible: showLyricsOnMobile\)/);
  console.log('PASS: only the visible active row uses shared timing; compact line stays single-line');
}catch(error){
  console.log('FAIL: '+error.message.split('\n')[0]);process.exitCode=1;
}
