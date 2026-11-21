import CryptoKit
import Foundation
import ImageIO

/// Small display data stays separate from audio bytes. A failed lyric refresh
/// never erases the last successful response or makes a complete song unplayable.
actor OfflineMetadataStore {
    static let shared = OfflineMetadataStore(directory: OfflineStore.shared.directory.appendingPathComponent("metadata"))
    nonisolated let directory: URL
    private var lastCleanup = Date.distantPast

    init(directory: URL) { self.directory = directory }

    static func key(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func folder(_ scope: String) -> URL { directory.appendingPathComponent(Self.key(scope), isDirectory: true) }

    func save(track: Track, scope: String) throws {
        try write(JSONEncoder().encode(track), to: folder(scope).appendingPathComponent("track-\(track.id).json"))
    }

    func track(id: Int, scope: String) -> Track? {
        guard let data = try? Data(contentsOf: folder(scope).appendingPathComponent("track-\(id).json")) else { return nil }
        return try? JSONDecoder().decode(Track.self, from: data)
    }

    func save(lyrics: LyricResponse, trackID: Int, scope: String) throws {
        try write(JSONEncoder().encode(lyrics), to: folder(scope).appendingPathComponent("lyrics-\(trackID).json"))
    }

    func lyrics(trackID: Int, scope: String) -> LyricResponse? {
        guard let data = try? Data(contentsOf: folder(scope).appendingPathComponent("lyrics-\(trackID).json")) else { return nil }
        return try? JSONDecoder().decode(LyricResponse.self, from: data)
    }

    func saveArtwork(_ data: Data, url: URL, scope: String) throws {
        guard data.count <= 12 * 1024 * 1024,
              let image = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceCreateImageAtIndex(image, 0, nil) != nil else {
            throw OfflineAudioError.invalidResource
        }
        try write(data, to: artworkURL(url, scope: scope))
    }

    func artwork(url: URL, scope: String) -> Data? { try? Data(contentsOf: artworkURL(url, scope: scope)) }

    func hasDisplayData(track: Track, scope: String) -> Bool {
        let hasLyrics = lyrics(trackID: track.id, scope: scope) != nil
        let hasArtwork = track.album.picUrl.flatMap(URL.init(string:)).map { artwork(url: $0, scope: scope) != nil } ?? true
        return hasLyrics && hasArtwork
    }

    /// 「存储空间」里的「歌词缓存」：所有账号目录下 lyrics-*.json 的总字节数。
    nonisolated func lyricsBytes(excluding downloaded: Set<Int> = []) -> Int64 {
        let fm = FileManager.default
        guard let scopes = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return 0 }
        var total: Int64 = 0
        for folder in scopes {
            guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey]) else { continue }
            for file in files where file.lastPathComponent.hasPrefix("lyrics-") {
                if let id = Int(file.deletingPathExtension().lastPathComponent.dropFirst("lyrics-".count)), downloaded.contains(id) { continue }
                total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }
        return total
    }

    /// 删除所有已缓存的歌词；下次播放或联网时会重新获取。
    /// 删除一首歌的本地歌词（下载被删除时连带清理）。
    nonisolated func removeLyrics(trackID: Int) {
        let fm = FileManager.default
        guard let scopes = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for folder in scopes {
            let file = folder.appendingPathComponent("lyrics-\(trackID).json")
            if fm.fileExists(atPath: file.path) { try? fm.removeItem(at: file) }
        }
    }

    func clearLyrics(excluding downloaded: Set<Int> = []) {
        let fm = FileManager.default
        guard let scopes = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for folder in scopes {
            guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.lastPathComponent.hasPrefix("lyrics-") {
                if let id = Int(file.deletingPathExtension().lastPathComponent.dropFirst("lyrics-".count)), downloaded.contains(id) { continue }
                try? fm.removeItem(at: file)
            }
        }
    }

    func fetchDisplayData(track: Track, scope: String) async {
        guard !Task.isCancelled else { return }
        do { try save(track: track, scope: scope) } catch { return }
        async let response = try? MusicAPI.lyric(id: track.id)
        async let cover = fetchArtwork(track: track)
        if let response = await response { try? save(lyrics: response, trackID: track.id, scope: scope) }
        if let (url, data) = await cover { try? saveArtwork(data, url: url, scope: scope) }
    }

    /// What a song the cache holds needs to show offline like a download: its
    /// record, its lyrics and its artwork. Artwork is fetched once.
    func keepPlaybackData(track: Track, lyrics: LyricResponse?, scope: String) async {
        try? save(track: track, scope: scope)
        if let lyrics { try? save(lyrics: lyrics, trackID: track.id, scope: scope) }
        guard let url = track.album.picUrl.flatMap(URL.init(string:)), artwork(url: url, scope: scope) == nil else { return }
        if let (url, data) = await fetchArtwork(track: track), !Task.isCancelled {
            try? saveArtwork(data, url: url, scope: scope)
        }
    }

    /// Keep display data for audio, pending downloads and the current queue.
    /// Recent writes get a short grace period for in-flight playback/download setup.
    func pruneUnused(audio: OfflineStore, protectedTracks: [String: Set<Int>], force: Bool = false) async throws {
        let now = Date()
        guard force || now.timeIntervalSince(lastCleanup) >= 300 else { return }
        let previousCleanup = lastCleanup
        lastCleanup = now
        do {
            var kept = try await audio.metadataTrackIDs()
            for (scope, ids) in protectedTracks { kept[scope, default: []].formUnion(ids) }
            var filesToKeep: [String: Set<String>] = [:]
            for (scope, ids) in kept {
                let key = Self.key(scope)
                for id in ids {
                    filesToKeep[key, default: []].formUnion(["track-\(id).json", "lyrics-\(id).json"])
                    if let cover = track(id: id, scope: scope)?.album.picUrl.flatMap(URL.init(string:)) {
                        filesToKeep[key, default: []].insert(artworkURL(cover, scope: scope).lastPathComponent)
                    }
                }
            }
            guard FileManager.default.fileExists(atPath: directory.path) else { return }
            let folders = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
            for folder in folders where (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                let protected = filesToKeep[folder.lastPathComponent] ?? []
                for file in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) {
                    let name = file.lastPathComponent
                    guard !protected.contains(name), ["track-", "lyrics-", "art-"].contains(where: name.hasPrefix),
                          let modified = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                          modified < now.addingTimeInterval(-60) else { continue }
                    try FileManager.default.removeItem(at: file)
                }
                if try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty { try FileManager.default.removeItem(at: folder) }
            }
        } catch {
            lastCleanup = previousCleanup
            throw error
        }
    }

    private func fetchArtwork(track: Track) async -> (URL, Data)? {
        guard let original = track.album.picUrl.flatMap(URL.init(string:)),
              let url = track.album.picUrl?.resizedImageURL(640),
              let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return (original, data)
    }

    private func artworkURL(_ url: URL, scope: String) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems?.filter { $0.name != "param" }
        components?.queryItems = queryItems
        if components?.queryItems?.isEmpty == true { components?.queryItems = nil }
        // http/https and thumbnail sizes refer to the same artwork.
        components?.scheme = "https"
        return folder(scope).appendingPathComponent("art-\(Self.key(components?.string ?? url.absoluteString))")
    }

    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        var directory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        #endif
    }
}
