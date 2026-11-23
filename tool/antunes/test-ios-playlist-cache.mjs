// Static source-contract regression; does not compile or run the iOS app.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
const root=process.argv[2]||resolve(import.meta.dirname,'../..');
const read=path=>readFileSync(resolve(root,path),'utf8');
const model=read('Sources/Kumone/Core/Storage/PlaylistContent.swift');
const store=read('Sources/Kumone/Core/Storage/PlaylistSnapshotStore.swift');
const view=read('Sources/Kumone/Features/Detail/PlaylistDetailView.swift');
const init=model.slice(model.indexOf('    init('),model.indexOf('    var canDownloadAll'));
assert(init.includes('cachedSnapshot(id: playlistID, scope: scope)'), 'cached playlist must seed the model before the first view frame');
assert(init.includes('loadedScope = scope')&&init.includes('isLoading = false'));
assert(store.includes('nonisolated func cachedSnapshot(')&&store.includes('NSCache<'));
assert(store.includes('memory.setObject('));
console.log('IOS_STATIC: snapshot seeds initial frame; scope-isolated memory cache; PASS');
assert(model.includes('if detail != saved.detail { detail = saved.detail }'));
assert(model.includes('if tracks != saved.detail.tracks { tracks = saved.detail.tracks }'));
assert(model.includes('if detail != loaded { detail = loaded }'));
assert(model.includes('if tracks != loadedTracks { tracks = loadedTracks }'));
assert(model.includes('if tracks != updated { tracks = updated }'));
console.log('IOS_STATIC: equal cached/network values do not republish; PASS');
assert(model.includes('isRefreshing = detail != nil'));
assert(view.includes('!model.isRefreshing && (model.isLoading || model.isLoadingMore)'));
for(const size of [384,512])assert(view.includes(`CachedAsyncImage(url: detail.coverImgUrl?.resizedImageURL(${size}), animated: false)`));
console.log('IOS_STATIC: cached refresh spinner suppressed; compact/tablet cover fade disabled; PASS');
const imageCache=read('Sources/Kumone/Core/Storage/ImageCache.swift');
const preview = imageCache.split('nonisolated func cachedPreview(for url: URL)')[1]
  ?.split('/// Sizes used by app surfaces')[0];
assert(preview && !/Data\(contentsOf:|diskImage\(|Self\.preview\(|diagnostics\(/.test(preview),
       'the synchronous preview must not do I/O or decode');
assert(!imageCache.includes('cover-diag.log'));
assert(model.includes('warmDiskThumbnails(missing)') && model.includes('cachedImage(for: $0) == nil'));
assert(model.includes('new.preservingCover(from: old)'));
assert(view.includes('preparesArtwork: true'));
assert.match(init, /if !preparesArtwork \{\s*tracks = saved\.detail\.tracks/);
assert.match(model, /if let artworkSize \{\s*await warmLeadingArtwork\(saved\.detail\.tracks/);
assert(!view.includes('.task(id: model.tracks.count)'));
console.log('IOS_STATIC: memory-only render path; bounded disk warming; cover survives partial refresh; PASS');
