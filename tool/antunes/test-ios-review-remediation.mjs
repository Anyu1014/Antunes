// Source contracts for the audited routes; functional tests live in KumoneCoreTests.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
const root = process.argv[2] || resolve(import.meta.dirname, '../..');
const read = path => readFileSync(resolve(root, 'Sources/Kumone', path), 'utf8');
const image = read('Core/Storage/ImageCache.swift');
const playlist = read('Core/Storage/PlaylistContent.swift');
const detail = read('Features/Detail/PlaylistDetailView.swift');
const offline = read('Core/Storage/OfflineMetadataStore.swift');
const downloads = read('Core/Storage/DownloadManager.swift');
const storage = read('Features/Pages/StorageSpaceView.swift');
const player = read('Core/Player/PlayerServiceIOS.swift');
const fm = player.slice(player.indexOf('private func fmAdvance()'), player.indexOf('private func advanceToNext('));
const window = read('Features/IOSMainWindow.swift');
const nav = read('Features/Navigation.swift');
const home = read('Features/Home/HomeView.swift');
const search = read('Features/Pages/SearchView.swift');
const preview = image.split('nonisolated func cachedPreview(for url: URL)')[1]?.split('/// Sizes used')[0];
const routes = window.slice(window.indexOf('private func openDestination('), window.indexOf('private func tabStack'));
const checks = [
  ['cover preview is memory-only and keeps cached artwork', preview && !/Data\(contentsOf:|diskSeed\(|Self\.preview\(/.test(preview) &&
    !image.includes('cover-diag.log') && playlist.includes('new.preservingCover(from: old)') &&
    playlist.includes('await warmLeadingArtwork') && !detail.includes('.task(id: model.tracks.count)')],
  ['lyric removal is account-scoped and follows audio success',
    /guard await cancelJobs\(ids, deletingTracks: trackIDs\) else \{ return false \}[\s\S]*?await metadata.removeLyrics\(trackIDs: trackIDs, scope: scope\)/.test(downloads) &&
    offline.includes('func clearLyrics(scope: String') && storage.includes('stored[scope, default: []]')],
  ['late FM fetch cannot change the current track',
    /await MusicAPI\.personalFM\(\)\s+guard isCurrent\(generation\)/.test(fm) &&
    /guard isCurrent\(generation\), !fmUpcoming\.isEmpty else \{ return \}/.test(fm)],
  ['custom bar owns clearance and routes to the visible stack',
    window.includes('.environment(\\.floatingChromeClearance, clearance)') &&
    nav.includes('if let floatingChromeClearance') && routes.includes('if usesIPadSidebar') &&
    routes.includes('binding(for: activeTab)') && window.includes('.ignoresSafeArea(.keyboard, edges: .bottom)')],
  ['home binds results and display to the authenticated account',
    home.includes('.task(id: account.authenticatedAccountID)') &&
    home.includes('generation == loadGeneration && accountID == AccountStore.shared.authenticatedAccountID') &&
    home.includes('model.loadedAccountID != account.authenticatedAccountID')],
  ['guest is not a playlist owner', detail.includes('guard let accountID = account.authenticatedAccountID else { return false }')],
  ['search reports failure separately and counts all four result types',
    search.includes('model.failedTabs.contains(model.tab)') &&
    /case \.all: return model\.songs\.isEmpty && model\.artists\.isEmpty\s*&& model\.albums\.isEmpty && model\.playlists\.isEmpty/.test(search)],
];
for (const [name, pass] of checks) console.log(`${pass ? 'PASS' : 'FAIL'}: ${name}`);
process.exitCode = checks.some(([, pass]) => !pass) ? 1 : 0;
