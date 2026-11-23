import CryptoKit
import Foundation
import ImageIO
import SwiftUI

/// Two-tier (memory + disk) image cache with in-flight request coalescing.
actor ImageCache {
    static let shared = ImageCache()
    typealias CachedImageHandler = @MainActor @Sendable (PlatformImage) -> Void

    private nonisolated(unsafe) let memory = NSCache<NSString, PlatformImage>()
    nonisolated let directory: URL
    private let session: URLSession
    private let offlineArtwork: @Sendable (URL) async -> Data?
    private var generation: UInt64 = 0
    private struct Request {
        let generation: UInt64
        let task: Task<PlatformImage?, Never>
    }
    private var inflight: [String: Request] = [:]

    init(directory: URL = KumonePaths.imageCache, session: URLSession = .shared,
         offlineArtwork: @escaping @Sendable (URL) async -> Data? = { await ImageCache.loadOfflineArtwork(for: $0) }) {
        self.directory = directory
        self.session = session
        self.offlineArtwork = offlineArtwork
        #if os(macOS)
        // Small decoded covers for a large playlist can fit within the byte
        // budget; avoid evicting them after scrolling only a few hundred songs.
        memory.countLimit = 2_000
        #else
        memory.countLimit = 300
        #endif
        memory.totalCostLimit = 64 * 1024 * 1024
    }

    private static func loadOfflineArtwork(for url: URL) async -> Data? {
        guard let scope = await MainActor.run(body: { AccountStore.shared.offlineScope }) else { return nil }
        return await OfflineMetadataStore.shared.artwork(url: url, scope: scope)
    }

    /// Surface local pixels before waiting for a larger version. The returned
    /// image still prefers the requested resolution, including after reconnect.
    func image(for url: URL, onCachedImage: CachedImageHandler? = nil) async -> PlatformImage? {
        let memoryKey = url.absoluteString as NSString
        if let cached = memory.object(forKey: memoryKey) {
            return cached
        }
        let key = Self.cacheKey(for: url)
        let requestGeneration = generation
        // The exact file, decoded once: it is both the preview and the answer.
        let exact = onCachedImage == nil ? nil : diskImage(for: key, requestedURL: url)
        if let onCachedImage, let preview = exact ?? cachedVariant(for: url) {
            await onCachedImage(preview)
        }
        guard !Task.isCancelled else { return nil }
        // Delivering the preview hops to MainActor; another caller may have
        // completed the exact request while this actor was suspended.
        if let cached = memory.object(forKey: memoryKey) { return cached }
        if let existing = inflight[key] {
            let result = await existing.task.value
            return result ?? cachedVariant(for: url)
        }
        let task = Task<PlatformImage?, Never> { [self] in
            let fileURL = directory.appendingPathComponent(key)
            if let image = exact ?? diskImage(for: key, requestedURL: url) {
                return image
            }
            if let data = await offlineArtwork(url),
               let image = Self.decode(data, for: url) { return image }
            guard let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
                  let image = Self.decode(data, for: url) else { return nil }
            if generation == requestGeneration {
                if !FileManager.default.fileExists(atPath: directory.path) {
                    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                }
                try? data.write(to: fileURL, options: .atomic)
            }
            return image
        }
        inflight[key] = Request(generation: requestGeneration, task: task)
        let result = await task.value
        if inflight[key]?.generation == requestGeneration { inflight[key] = nil }
        if generation == requestGeneration, let result {
            remember(result, for: memoryKey)
        }
        // Do not store a smaller fallback under the requested size: a later
        // online request must still be able to fetch the full-resolution image.
        return result ?? cachedVariant(for: url)
    }

    private func remember(_ image: PlatformImage, for key: NSString) {
        memory.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
    }

    private func diskImage(for key: String, requestedURL: URL) -> PlatformImage? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(key)) else { return nil }
        return Self.decode(data, for: requestedURL)
    }

    private static func thumbnailLimit(for url: URL) -> Int? {
        guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "param" })?.value else { return nil }
        let dimensions = value.split(separator: "y", omittingEmptySubsequences: false)
        guard dimensions.count == 2, let width = Int(dimensions[0]), let height = Int(dimensions[1]),
              width > 0, height > 0 else { return nil }
        return max(width, height)
    }

    /// A CDN size hint is not a decode limit: offline artwork and older cache
    /// variants can contain the original cover. Decode thumbnails on this
    /// actor before SwiftUI displays them, with a bounded pixel allocation.
    private static func decode(_ data: Data, for url: URL, cap: Int? = nil) -> PlatformImage? {
        guard let declared = thumbnailLimit(for: url) else { return PlatformImage(data: data) }
        let limit = cap.map { min($0, declared) } ?? declared
        guard let source = CGImageSourceCreateWithData(data as CFData, [
            kCGImageSourceShouldCache: false,
        ] as CFDictionary), let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: limit,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary) else { return nil }
        return platformImage(image)
    }

    private static func platformImage(_ image: CGImage) -> PlatformImage {
        #if os(macOS)
        return PlatformImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        #else
        return PlatformImage(cgImage: image)
        #endif
    }

    private static func preview(_ image: PlatformImage, for url: URL) -> PlatformImage? {
        guard let limit = thumbnailLimit(for: url) else { return image }
        #if os(macOS)
        guard let pixels = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        #else
        guard let pixels = image.cgImage else { return nil }
        #endif
        guard max(pixels.width, pixels.height) > limit else { return image }
        let scale = Double(limit) / Double(max(pixels.width, pixels.height))
        let width = max(1, Int(Double(pixels.width) * scale))
        let height = max(1, Int(Double(pixels.height) * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(pixels, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let thumbnail = context.makeImage() else { return nil }
        #if os(macOS)
        return platformImage(thumbnail)
        #else
        return PlatformImage(cgImage: thumbnail, scale: 1, orientation: image.imageOrientation)
        #endif
    }

    private func cachedVariant(for url: URL) -> PlatformImage? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let otherItems = components.queryItems?.filter { $0.name != "param" } ?? []
        // Probe largest first without a disk scan.
        for size in [nil] + Self.knownSizes.map(Optional.some) {
            components.queryItems = otherItems + (size.map { [URLQueryItem(name: "param", value: "\($0)y\($0)")] } ?? [])
            if components.queryItems?.isEmpty == true { components.queryItems = nil }
            guard let candidate = components.url, candidate != url else { continue }
            if let image = memory.object(forKey: candidate.absoluteString as NSString),
               let preview = Self.preview(image, for: url) { return preview }
            let key = Self.cacheKey(for: candidate)
            if let image = diskImage(for: key, requestedURL: url) { return image }
        }
        return nil
    }

    func usage() throws -> CacheUsage {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        let bytes = files.reduce(Int64(0)) { total, file in
            total + Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return CacheUsage(bytes: bytes)
    }

    /// Existing views may finish loading their image, but requests started
    /// before the clear cannot refill either disk or memory caches afterwards.
    func clear() throws {
        generation += 1
        memory.removeAllObjects()
        if FileManager.default.fileExists(atPath: directory.path) {
            let info = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard info.isDirectory == true, info.isSymbolicLink != true else { throw OfflineAudioError.invalidResource }
            try FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Synchronous in-memory lookup — safe off the actor (`NSCache` is
    /// thread-safe). Returns nil unless the image is resident in memory; use
    /// `image(for:)` for disk/network loads.
    nonisolated func cachedImage(for url: URL) -> PlatformImage? {
        // Hashing is only necessary for disk filenames, not hot row lookups.
        memory.object(forKey: url.absoluteString as NSString)
    }

    /// Builds a request for another thumbnail size of the same cover.
    nonisolated static func variant(of url: URL, size: Int) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        // 没有 `param` 的原始封面（列表里常见）同样要能换到目标尺寸，否则预取
        // 静默失败、详情页那张大图永远是冷的。
        let otherItems = components.queryItems?.filter { $0.name != "param" } ?? []
        components.queryItems = otherItems + [URLQueryItem(name: "param", value: "\(size)y\(size)")]
        return components.url
    }

    func prefetch(_ url: URL?) async {
        guard let url, !Task.isCancelled else { return }
        _ = await image(for: url)
    }

    /// Prime saved thumbnails for the first rows without waiting for the network.
    func warmDiskThumbnails(_ urls: [URL]) {
        var seen: Set<URL> = []
        for url in urls {
            guard !Task.isCancelled else { return }
            let key = url.absoluteString as NSString
            guard seen.insert(url).inserted, memory.object(forKey: key) == nil,
                  let image = diskImage(for: Self.cacheKey(for: url), requestedURL: url) else { continue }
            remember(image, for: key)
        }
    }

    /// Rendering never reads disk, decodes an image, or writes diagnostics.
    nonisolated func cachedPreview(for url: URL) -> PlatformImage? {
        if let exact = cachedImage(for: url) { return exact }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let otherItems = components.queryItems?.filter { $0.name != "param" } ?? []
        for size in Self.knownSizes {
            components.queryItems = otherItems + [URLQueryItem(name: "param", value: "\(size)y\(size)")]
            if let candidate = components.url, candidate != url,
               let cached = cachedImage(for: candidate) { return cached }
        }
        return nil
    }

    /// Sizes used by app surfaces, including existing on-disk caches from
    /// before cross-size fallback.
    private static let knownSizes = [1024, 768, 640, 512, 384, 256, 160, 128, 120, 96, 80, 64, 48]

    private static func cacheKey(for url: URL) -> String {
        let digest = Insecure.MD5.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Keep pixels bound to their source. Playlist rows may explicitly keep the
/// previous pixels until the same song and album have a new image to display.
struct CachedImageState {
    struct Owner: Hashable {
        let trackID: Int
        let albumID: Int
    }

    struct Request: Hashable {
        let url: URL?
        let owner: Owner?
    }

    private var request: Request
    private var image: PlatformImage?
    private var previousImage: PlatformImage?

    init(url: URL? = nil, image: PlatformImage? = nil, owner: Owner? = nil) {
        self.request = Request(url: url, owner: owner)
        self.image = image
    }

    func image(for url: URL?) -> PlatformImage? {
        image(for: Request(url: url, owner: nil))
    }

    func image(for request: Request) -> PlatformImage? {
        guard request.url != nil, self.request == request else { return nil }
        return image
    }

    func retainedImage(for next: Request) -> PlatformImage? {
        guard next.url != nil, let owner = next.owner, request.owner == owner else { return nil }
        return image ?? previousImage
    }

    mutating func begin(_ next: Request, cached: PlatformImage?) {
        if request == next { return }
        let previous = retainedImage(for: next)
        self = CachedImageState(url: next.url, image: cached, owner: next.owner)
        if cached == nil { previousImage = previous }
    }

    mutating func finish(_ image: PlatformImage?, for url: URL) {
        finish(image, for: Request(url: url, owner: nil))
    }

    mutating func finish(_ image: PlatformImage?, for request: Request) {
        guard self.request == request else { return }
        self.image = image
        if image != nil { previousImage = nil }
    }
}

/// AsyncImage replacement backed by `ImageCache`, with a crossfade reveal.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    var animated: Bool = true
    let owner: CachedImageState.Owner?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var imageState: CachedImageState

    init(url: URL?, animated: Bool = true, owner: CachedImageState.Owner? = nil,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.animated = animated
        self.owner = owner
        self.placeholder = placeholder
        // Seed from the in-memory cache so a re-created view (e.g. the iOS 26
        // tab-bar accessory rebuilt on a tab switch, #46, or a playlist hero
        // that asks for a larger size than its list row cached) shows
        // already-decoded artwork immediately instead of flashing the
        // placeholder for the frames it takes to reach the cache actor.
        let seeded = url.flatMap { ImageCache.shared.cachedPreview(for: $0) }
        _imageState = State(initialValue: CachedImageState(url: url, image: seeded, owner: owner))
    }

    var body: some View {
        let request = CachedImageState.Request(url: url, owner: owner)
        ZStack {
            placeholder()
            // A reused row keeps its State. Resolve an already decoded cover
            // synchronously when the URL changes, before the new task runs.
            if let image = imageState.image(for: request)
                ?? url.flatMap({ ImageCache.shared.cachedPreview(for: $0) })
                ?? imageState.retainedImage(for: request) {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(animated ? .opacity.animation(.easeIn(duration: 0.22)) : .identity)
            }
        }
        .task(id: request) {
            guard !Task.isCancelled else { return }
            guard let url else {
                imageState = CachedImageState()
                return
            }
            // Synchronous memory hit first — no actor hop, no placeholder frame.
            // A cached variant is only a stand-in: it is shown at once and the
            // exact size still replaces it below.
            let exactHit = ImageCache.shared.cachedImage(for: url)
            imageState.begin(request, cached: exactHit ?? ImageCache.shared.cachedPreview(for: url))
            if let exactHit {
                if imageState.image(for: request) !== exactHit { imageState.finish(exactHit, for: request) }
                return
            }
            let cached = await ImageCache.shared.image(for: url) { preview in
                guard !Task.isCancelled else { return }
                if imageState.image(for: request) == nil { imageState.finish(preview, for: request) }
            }
            guard !Task.isCancelled, let cached else { return }
            imageState.finish(cached, for: request)
        }
    }
}

extension CachedAsyncImage where Placeholder == AnyView {
    /// Default placeholder: a quiet neutral fill with a music note.
    init(url: URL?, animated: Bool = true) {
        self.init(url: url, animated: animated) {
            AnyView(
                ZStack {
                    Rectangle().fill(.quaternary.opacity(0.5))
                    Image(systemName: "music.note")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.quaternary)
                }
            )
        }
    }
}
