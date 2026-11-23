// Layout structure guard; keyboard coordinates still need an iPhone test.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(process.argv[2] || new URL(
    '../../Sources/Kumone/Features/IOSMainWindow.swift', import.meta.url), 'utf8');
const content = source.slice(source.indexOf('    private func customTabContent('),
                             source.indexOf('    private func bottomBar('));
const [pages, controls] = content.split('.overlay(alignment: .bottom) {');
const keyboard = '.ignoresSafeArea(.keyboard, edges: .bottom)';
assert(controls?.includes(keyboard),
       'bottom controls must ignore the keyboard in their own overlay');
assert(!pages.includes(keyboard), 'pages must keep keyboard avoidance');
const pinned = controls.slice(0, controls.indexOf(keyboard));
assert(pinned.includes('IOSMiniPlayerBar(presentation: .legacyOverlay'));
assert(pinned.includes('BottomBarSlot {'));
assert(pinned.includes('.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)'));
assert(pinned.includes('preference(key: InterfaceSizeKey.self, value: geo.size)'),
       'the horizontal layout must use the keyboard-independent height');
console.log('PASS: navigation and mini-player share a keyboard-independent bottom overlay');
