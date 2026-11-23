import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const source=readFileSync(process.argv[2]||new URL('../../Sources/Kumone/Features/IOSMainWindow.swift',import.meta.url),'utf8');
const strip=source.split('private struct LyricStripPill: View {')[1];
assert(strip,'lyric strip missing');
const touchTarget=source.split('LyricStripPill(morphing: morphing)')[1]?.split('collapsedLyricButton(')[0];
assert(touchTarget,'lyric strip slot missing');
try{
  assert.match(strip.replace(/^\s*\/\/.*$/gm,''),/GeometryReader \{ geo in[\s\S]*?\btrack\s+\.allowsHitTesting\(false\)/,'offscreen lyric track still participates in hit testing');
  const modifiers=touchTarget.replace(/^\s*\/\/.*$/gm,'');
  assert.match(modifiers,/\.contentShape\(Rectangle\(\)\)\s+\.onTapGesture\s*\{[^\n]*\}\s+\.allowsHitTesting\(!folded && tabsExpanded\.wrappedValue\)\s+\.accessibilityHidden\(folded\)/,'tap target must be bounded and active only when it can fold the tabs');
  console.log('PASS: scrolling lyric track is non-interactive; fold gesture is bounded and conditional');
}catch(error){
  console.log('FAIL: '+error.message.split('\n')[0]);
  process.exitCode=1;
}
