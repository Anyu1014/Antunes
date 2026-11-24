import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';

const root = process.argv[2] || resolve(import.meta.dirname, '../..');
const read = path => readFileSync(resolve(root, 'Sources/Kumone', path), 'utf8');

// Project the platform guards surrounding the gray-track UI and preferences.
function platformSource(source, ios) {
    const active = [true];
    return source.split('\n').filter(line => {
        const directive = line.trim();
        if (directive.startsWith('#if ')) {
            const condition = directive.slice(4);
            active.push(condition === 'os(iOS)' ? ios : condition === 'os(macOS)' ? !ios : true);
        } else if (directive === '#else') {
            active[active.length - 1] = !active[active.length - 1];
        } else if (directive === '#endif') {
            active.pop();
        } else {
            return active.every(Boolean);
        }
        return false;
    }).join('\n');
}

const settings = read('Features/Pages/SettingsView.swift');
assert.doesNotMatch(platformSource(settings, true), /灰色歌曲解锁|AudioSourceID\.allCases/, 'iOS still exposes gray-track unlock');
assert.match(platformSource(settings, false), /灰色歌曲解锁/);
assert.match(platformSource(settings, false), /AudioSourceID\.allCases/);

const prefs = read('Core/Storage/SettingsManager.swift');
assert.match(platformSource(prefs, true), /var canResolveUnblockedTracks: Bool \{\s*false\s*\}/);
assert.match(platformSource(prefs, false), /enableUnblock && !enabledAudioSourceIDs\.isEmpty/);
const sync = read('Core/Sync/SyncedPreferences.swift');
assert.doesNotMatch(platformSource(sync, true), /Keys\.unblock|enabledAudioSourceIDs|enableUnblock/);
assert.match(platformSource(sync, false), /enableUnblock = value/);
assert.match(platformSource(sync, false), /Keys\.unblockSources: \.strings/);
assert.doesNotMatch(platformSource(read('Features/Player/PlayerBar.swift'), true), /unblockSource/);

const player = read('Core/Player/PlayerServiceIOS.swift');
assert.doesNotMatch(player, /UnblockService|resolveAndLoadUnblocked|unblockSource|\.unblock\(/);
const cacheAllowsUnblock = [...player.matchAll(/allowsUnblock:\s*(\w+)/g)].map(match => match[1]);
assert.deepEqual(cacheAllowsUnblock, ['false', 'false', 'false', 'false'], 'only original-source cache and prefetch are allowed');
for (const normalPath of [/MusicAPI\.songURLRetrying/, /acquireOfflineLease/, /source: \.origin/, /VIP 歌曲，当前为试听片段/, /CDNHost\.failover/, /guard let url = resolvedURL else \{\s*handleUnplayable\(track\)/]) {
    assert.match(player, normalPath);
}
console.log('IOS_GRAY_UNLOCK: UI=removed; resolution=official-only; cache/prefetch=official-only; policy=not synced on iOS; macOS=preserved; PASS');
