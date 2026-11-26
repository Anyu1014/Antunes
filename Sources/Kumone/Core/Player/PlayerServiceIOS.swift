#if os(iOS)
import Combine
import AVFoundation
import Foundation
import OSLog

enum RepeatMode: String, CaseIterable {
    case off, all, one

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

/// Where the current queue came from — used for scrobbling and UI affordances.
enum PlaySource: Codable, Equatable {
    case playlist(Int)
    case album(Int)
    case artist(Int)
    case daily
    case cloud
    case none

    var sourceID: Int {
        switch self {
        case .playlist(let id), .album(let id), .artist(let id): return id
        default: return 0
        }
    }
}

/// Where playback started from — listed under "Recently Played" in the Dock
/// menu, where picking one reloads it and starts playing again.
///
/// This is deliberately separate from `PlaySource`: heartbeat mode plays out
/// of the liked-songs playlist for scrobbling purposes, but as a *place* it is
/// its own thing, and the recents page has no source at all.
struct PlayContext: Codable, Hashable {
    enum Kind: String, Codable {
        /// Reloaded by id.
        case playlist, album, artist
        /// Fixed per-account entry points, each reloaded from its own API.
        case daily, cloud, recents, heartbeat, fm
    }

    let kind: Kind
    /// Zero for the fixed entry points, which have no id of their own.
    let id: Int
    let name: String

    static func playlist(id: Int, name: String) -> PlayContext {
        .init(kind: .playlist, id: id, name: name)
    }

    static func album(id: Int, name: String) -> PlayContext {
        .init(kind: .album, id: id, name: name)
    }

    static func artist(id: Int, name: String) -> PlayContext {
        .init(kind: .artist, id: id, name: name)
    }

    static var daily: PlayContext { .init(kind: .daily, id: 0, name: String(localized: "每日推荐")) }
    static var cloud: PlayContext { .init(kind: .cloud, id: 0, name: String(localized: "音乐云盘")) }
    static var recents: PlayContext { .init(kind: .recents, id: 0, name: String(localized: "最近播放")) }
    static var heartbeat: PlayContext { .init(kind: .heartbeat, id: 0, name: String(localized: "心动模式")) }
    static var fm: PlayContext { .init(kind: .fm, id: 0, name: String(localized: "私人漫游")) }

    /// Identity is the place, not its current title — a renamed playlist is
    /// still the same entry in the recents list.
    static func == (lhs: PlayContext, rhs: PlayContext) -> Bool {
        lhs.kind == rhs.kind && lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(id)
    }
}

enum RightPanel {
    case lyrics, queue
}

/// The playback engine: queue, shuffle/repeat, personal FM, URL resolution,
/// lyrics, scrobbling. Modeled on YesPlayMusic's Player class, backed by AVPlayer.
/// High-frequency playback position, isolated so per-tick updates only
/// re-render the scrubbers/lyrics that observe it — not every view holding
/// the PlayerService.
@MainActor
final class PlaybackClock: ObservableObject {
    @Published var progress: TimeInterval = 0
}

/// Which lyric line is current.
///
/// Every lyric view used to derive this itself, which meant observing the clock
/// and re-rendering on every tick just to discover the line hadn't changed —
/// and for the now-playing page, whose body is the whole immersive layout, that
/// was five full re-evaluations a second. Computing it once here and publishing
/// only on a change turns that into one re-render per lyric line.
@MainActor
final class LyricsCursor: ObservableObject {
    @Published var activeIndex: Int?
}

@MainActor
final class PlayerService: ObservableObject {
    static let shared = PlayerService()

    // MARK: - Observable state

    @Published private(set) var queue: [Track] = []
    @Published private(set) var shuffledQueue: [Track] = []
    @Published private(set) var playNextList: [Track] = []
    @Published private(set) var currentIndex = -1
    @Published private(set) var currentTrack: Track?
    private var playbackAccountID: Int?
    @Published private(set) var source: PlaySource = .none
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var servedQuality: String?
    @Published private(set) var isTrial = false
    let clock = PlaybackClock()
    let lyricsCursor = LyricsCursor()
    let sleepTimer = SleepTimer()
    /// Passthrough to the clock so existing `progress` reads/writes keep working.
    var progress: TimeInterval {
        get { clock.progress }
        set { clock.progress = newValue }
    }
    @Published var repeatMode: RepeatMode = .off {
        didSet { UserDefaults.standard.set(repeatMode.rawValue, forKey: "player.repeat") }
    }

    @Published private(set) var shuffleEnabled = false
    @Published var volume: Float = 1 {
        didSet {
            engine.volume = volume
            UserDefaults.standard.set(volume, forKey: "player.volume")
        }
    }

    @Published private(set) var isFMMode = false
    @Published private(set) var fmUpcoming: [Track] = []
    private var fmRequestID: UUID?
    /// Where playback was most recently started from, newest first —
    /// surfaced as "Recently Played" in the Dock menu.
    @Published private(set) var recentContexts: [PlayContext] = []
    @Published private(set) var lyrics: ParsedLyrics?
    @Published var activePanel: RightPanel?
    @Published var showNowPlaying = false

    /// The list the player is walking through (shuffled or ordered).
    var activeQueue: [Track] { shuffleEnabled ? shuffledQueue : queue }

    var playbackList: [PlaybackQueuePlan.ListEntry] {
        PlaybackQueuePlan.fullList(queue: activeQueue, currentIndex: currentIndex, current: currentTrack, inserted: playNextList)
    }

    var upcomingTracks: [Track] {
        guard !activeQueue.isEmpty, currentIndex >= 0 else { return playNextList }
        let rest = activeQueue.suffix(from: min(currentIndex + 1, activeQueue.count))
        return playNextList + Array(rest.prefix(200))
    }

    var hasCurrentTrack: Bool { currentTrack != nil }

    // MARK: - Engine

    private let engine = AVPlayer()

    // MARK: - FLAC（帧精确）播放器
    // AVFoundation 解码 FLAC 时 seek 不落在精确帧上（同一文件按 t 跳转后解出的采样
    // 与基准完全对不上，mp3 则逐采样一致），所以无损 / Hi-Res / 母带这一支不用
    // AVPlayer：先落一个本地文件，再用 AVAudioEngine 按帧播放与定位。
    private var flacPlayer: FLACFilePlayer?

    private var flacTimer: Timer?
    private var lastPlaybackCheckpoint = ContinuousClock.now

    /// Live playback position straight from the player, for smooth per-frame
    /// karaoke highlighting (the published `progress` is intentionally coarse).
    var livePlaybackTime: TimeInterval {
        if let flacPlayer { return flacPlayer.position }
        let t = engine.currentTime().seconds
        return t.isFinite ? t : progress
    }
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var audioResourceLoader: CachingAudioResourceLoader?
    private var pendingAudioResourceLoader: CachingAudioResourceLoader?
    private var audioCacheLease: UUID?
    private var statusObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var resolveGeneration = 0
    private var playbackIntent = UUID()

    @discardableResult
    func beginPlaybackIntent() -> UUID {
        playbackIntent = UUID()
        return playbackIntent
    }

    func isCurrentPlaybackIntent(_ intent: UUID) -> Bool { playbackIntent == intent }
    private var consecutiveFailures = 0
    /// Why the last playback URL request failed, when it failed in transit
    /// or the service refused it, rather than answering with no URL. Named
    /// in the 无法播放 toast, as on macOS (#209).
    private var lastResolveFailure: String?
    /// The code the service answered with when it gave no URL, named only
    /// when the song itself shows no reason it can't be played.
    private var lastRefusalCode: Int?
    private static let resolveLog = Logger(subsystem: "sb.moe.kumone", category: "playback")
    /// The resolve generation that already spent its one reload after a
    /// failed item, so a reload that fails too gives up instead of looping.
    private var itemRetryGeneration: Int?
    /// Set when a failure skips to the next song, so that skip keeps counting
    /// toward the stop after five in a row instead of resetting it.
    private var advancingAfterFailure = false
    private var scrobbled = false
    private var startScrobbled = false

    // MARK: - Offline playback (downloads)

    /// The song that could not play because it is not on this device.
    @Published var offlineIssue: OfflinePlaybackIssue?
    /// Held while the player item reads a downloaded file, so the download
    /// cannot be deleted from under it.
    private var offlinePlaybackLease: OfflinePlaybackLease?
    private var offlineScan: Task<Void, Never>?
    private var offlineScanID = UUID()
    private var networkState = DownloadNetworkState.unknown
    private var networkObservation: AnyCancellable?
    private var offlineActivatedScope: String?
    /// Set by an automatic advance and consumed by `startPlaying`: a song that
    /// turns out to be missing offline is skipped rather than reported.
    private var pendingAutoAdvance = false
    private var currentWasAdvanced = false

    // MARK: - Queue prefetch (song cache)

    /// Fills the cache with the next few songs while the network is free.
    private let queuePrefetcher = QueuePrefetcher()
    private var prefetchObservations: Set<AnyCancellable> = []
    private var prefetchUpdateScheduled = false

    private init() {
        engine.actionAtItemEnd = .pause
        sleepTimer.onDeadlineReached = { [weak self] in
            self?.pause()
        }
        volume = UserDefaults.standard.object(forKey: "player.volume") as? Float ?? 0.8
        engine.volume = volume
        repeatMode = UserDefaults.standard.string(forKey: "player.repeat")
            .flatMap(RepeatMode.init) ?? .off

        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }

        // Resume after interruptions (phone calls, WeChat voice messages, …).
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(), queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                self?.handleAudioInterruption(note)
            }
        }
        // Pause when the output route disappears (headphones unplugged).
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(), queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self,
                      let reasonValue = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                      reason == .oldDeviceUnavailable, self.isPlaying else { return }
                self.pause()
            }
        }
        #endif

        timeObserver = engine.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, !self.isScrubbing else { return }
                // FLAC 分支有自己的时钟；AVPlayer 没有 currentItem 时 time 会停在旧值，
                // 两个时钟同时写 progress 就是「进度条在两首歌之间闪」。
                guard self.flacPlayer == nil else { return }
                let seconds = time.seconds
                guard seconds.isFinite else { return }

                // 与原版一致：歌词每个 tick 都跟，进度条/锁屏按 0.45s 阈值发布。
                self.updateLyricsCursor(at: seconds)
                if abs(seconds - self.progress) > 0.45 {
                    self.progress = seconds
                    NowPlayingManager.shared.updateElapsed(seconds, rate: self.isPlaying ? 1 : 0)
                }
                if self.isPlaying, self.lastPlaybackCheckpoint.duration(to: .now) >= .seconds(20) {
                    self.persistState()
                }
            }
        }

        statusObservation = engine.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }

        NowPlayingManager.shared.attach(to: self, avPlayer: engine)


        offlineActivatedScope = AccountStore.shared.offlineScope
        networkObservation = DownloadManager.shared.$network.removeDuplicates().sink { [weak self] network in
            self?.networkState = network
        }
        observePrefetchInputs()
        // The cache keeps its default limit until something writes to it, and
        // trims to that on every release; a cache-only session must not lose
        // songs on the way.
        if SettingsManager.shared.enableAudioCache {
            Task { try? await AudioCache.shared.enforce(maximumSizeMB: await SettingsManager.shared.effectiveAudioCacheSizeMB()) }
        }
        restoreState()
    }

    /// Set while the user drags the seek bar so the time observer doesn't fight the thumb.
    var isScrubbing = false

    #if os(iOS)
    private var wasPlayingBeforeInterruption = false

    private func handleAudioInterruption(_ note: Notification) {
        guard let typeValue = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                // The system already silenced us; sync our state and UI.
                isPlaying = false
                NowPlayingManager.shared.updateElapsed(progress, rate: 0)
                persistState()
            }
        case .ended:
            let optionsValue = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            guard wasPlayingBeforeInterruption, options.contains(.shouldResume) else { return }
            wasPlayingBeforeInterruption = false
            try? AVAudioSession.sharedInstance().setActive(true)
            engine.play()
            isPlaying = true
            NowPlayingManager.shared.updateElapsed(progress, rate: 1)
        @unknown default:
            break
        }
    }
    #endif

    // MARK: - Entry points

    /// - Parameter context: the place these tracks came from. Supplying it
    ///   lists that place in the Dock menu's recently played section; callers
    ///   playing an ad-hoc selection (search results, a single track) omit it.
    func play(tracks: [Track], source: PlaySource, startAt track: Track? = nil,
              context: PlayContext? = nil) {
        beginPlaybackIntent()
        guard !tracks.isEmpty else { return }
        if let context { recordRecent(context) }
        isFMMode = false
        fmRequestID = nil
        if !fmUpcoming.isEmpty { fmUpcoming = [] }
        queue = tracks
        self.source = source
        playNextList.removeAll()
        let startTrack = track ?? tracks[0]
        if shuffleEnabled {
            reshuffle(keeping: startTrack)
            currentIndex = 0
        } else {
            currentIndex = tracks.firstIndex(where: { $0.id == startTrack.id }) ?? 0
        }
        startPlaying(activeQueue[currentIndex])
    }

    func playTrack(_ track: Track) {
        beginPlaybackIntent()
        if let idx = activeQueue.firstIndex(where: { $0.id == track.id }) {
            currentIndex = idx
            startPlaying(track)
        } else {
            play(tracks: [track], source: .none)
        }
    }

    /// Insert a track right after the current one.
    func addToPlayNext(_ track: Track, playNow: Bool = false) {
        playNextList.append(track)
        if playNow || currentTrack == nil {
            advanceToNext(userInitiated: true)
        } else {
            ToastCenter.shared.show(String(localized: "已添加到下一首播放"))
        }
    }

    func togglePlayPause() {
        beginPlaybackIntent()
        guard let track = currentTrack else { return }
        if isPlaying {
            pause()
            return
        } else if let flacPlayer {
            flacPlayer.play()
            isPlaying = true
            scrobbleStartIfNeeded()
        } else if engine.currentItem == nil {
            // Restored session: re-resolve the source.
            startPlaying(track, resumeAt: progress)
            return
        } else {
            engine.play()
            isPlaying = true
            scrobbleStartIfNeeded()
        }
        NowPlayingManager.shared.updateElapsed(progress, rate: isPlaying ? 1 : 0)
    }

    func pause() {
        beginPlaybackIntent()
        fmRequestID = nil
        engine.pause()
        flacPlayer?.pause()
        isPlaying = false
        AudioSpectrum.shared.reset()
        NowPlayingManager.shared.updateElapsed(progress, rate: 0)
        persistState()
    }

    func next() {
        beginPlaybackIntent()
        advanceToNext(userInitiated: true)
    }

    func previous() {
        beginPlaybackIntent()
        if isFMMode { return }
        if progress > 4 || activeQueue.isEmpty {
            seek(to: 0)
            return
        }
        var idx = currentIndex - 1
        if idx < 0 {
            guard repeatMode == .all else {
                seek(to: 0)
                return
            }
            idx = activeQueue.count - 1
        }
        currentIndex = idx
        startPlaying(activeQueue[idx])
    }

    /// Recomputes the current lyric line, publishing only on a change.
    /// 与进度条、锁屏共用同一个采样时刻，不再带提前量。
    private func updateLyricsCursor(at seconds: TimeInterval) {
        // 不再加 0.2 秒提前量：游标与进度条取同一个采样时刻，歌词与声音同刻换行。
        let index = lyrics?.activeIndex(at: seconds)
        if index != lyricsCursor.activeIndex {
            lyricsCursor.activeIndex = index
        }
    }

    func seek(to seconds: TimeInterval, completion: (@MainActor () -> Void)? = nil) {
        if let flacPlayer {
            flacPlayer.seek(to: seconds)
            progress = seconds
            updateLyricsCursor(at: seconds)
            NowPlayingManager.shared.updateElapsed(seconds, rate: isPlaying ? 1 : 0)
            persistState()
            if let completion {
                Task { @MainActor in completion() }
            }
            return
        }
        progress = seconds
        updateLyricsCursor(at: seconds)
        engine.seek(to: CMTime(seconds: seconds, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            guard let completion else { return }
            Task { @MainActor in completion() }
        }
        NowPlayingManager.shared.updateElapsed(seconds, rate: isPlaying ? 1 : 0)
        persistState()
    }

    func toggleShuffle() {
        guard !isFMMode else { return }
        shuffleEnabled.toggle()
        guard let current = currentTrack else { return }
        if shuffleEnabled {
            reshuffle(keeping: current)
            currentIndex = 0
        } else {
            currentIndex = queue.firstIndex(where: { $0.id == current.id }) ?? 0
        }
    }

    func cycleRepeatMode() {
        guard !isFMMode else { return }
        repeatMode = repeatMode.next
    }

    /// Single-button mode cycle for the iOS minimal transport row:
    /// sequential → loop all → loop one → shuffle → sequential.
    func cyclePlaybackMode() {
        guard !isFMMode else { return }
        if shuffleEnabled {
            toggleShuffle()
            repeatMode = .off
        } else {
            switch repeatMode {
            case .off:
                repeatMode = .all
            case .all:
                repeatMode = .one
            case .one:
                repeatMode = .off
                toggleShuffle()
            }
        }
    }

    /// Jump to a track in the upcoming list (queue panel click).
    func jumpTo(_ track: Track) {
        if let nextIdx = playNextList.firstIndex(where: { $0.id == track.id }) {
            playNextList.removeSubrange(0...nextIdx)
            startPlaying(track)
            return
        }
        if let idx = activeQueue.firstIndex(where: { $0.id == track.id }) {
            currentIndex = idx
            startPlaying(track)
        }
    }

    func removeFromUpcoming(_ track: Track) {
        if let idx = playNextList.firstIndex(where: { $0.id == track.id }) {
            playNextList.remove(at: idx)
            return
        }
        if let idx = queue.firstIndex(where: { $0.id == track.id }), idx != currentIndex || shuffleEnabled {
            queue.remove(at: idx)
        }
        if let idx = shuffledQueue.firstIndex(where: { $0.id == track.id }) {
            shuffledQueue.remove(at: idx)
        }
    }

    func jumpToPlaylistEntry(_ entry: PlaybackQueuePlan.ListEntry) {
        guard !entry.isCurrent else { return }
        switch entry.id {
        case .detachedCurrent: return
        case .inserted(let index):
            jumpToUpcoming(at: index, matching: entry.track.id)
        case .queue(let index):
            let queue = activeQueue
            guard queue.indices.contains(index), queue[index].id == entry.track.id else { return }
            beginPlaybackIntent()
            if index > currentIndex { playNextList.removeAll() }
            currentIndex = index
            startPlaying(queue[index])
        }
    }

    /// Queue rows carry their occurrence, so a repeated song selects the row
    /// the listener clicked rather than its first occurrence.
    func jumpToUpcoming(at index: Int, matching trackID: Int) {
        guard let selected = upcomingCandidate(at: index, matching: trackID) else { return }
        switch selected.origin {
        case .inserted(let offset):
            playNextList.removeSubrange(0...offset)
        case .queue(let offset):
            if !playNextList.isEmpty { playNextList.removeAll() }
            currentIndex = offset
        case .fm: return
        }
        startPlaying(selected.track)
    }

    /// Removes the row itself: a repeated song leaves the occurrence the
    /// listener chose, not its first one, so the current index stays put.
    func removeUpcoming(at index: Int, matching trackID: Int) {
        guard let selected = upcomingCandidate(at: index, matching: trackID) else { return }
        switch selected.origin {
        case .inserted(let offset): playNextList.remove(at: offset)
        case .queue(let offset): removeQueueRow(at: offset, trackID: selected.track.id)
        case .fm: return
        }
    }

    /// The row sits after the current index in the active order; the other
    /// order drops one copy of the same song so both stay the same length.
    private func removeQueueRow(at offset: Int, trackID: Int) {
        if shuffleEnabled {
            shuffledQueue.remove(at: offset)
            if let idx = queue.firstIndex(where: { $0.id == trackID }) { queue.remove(at: idx) }
        } else {
            queue.remove(at: offset)
            if let idx = shuffledQueue.firstIndex(where: { $0.id == trackID }) { shuffledQueue.remove(at: idx) }
        }
    }

    /// The row at `index` of `upcomingTracks`, if it still shows `trackID`.
    private func upcomingCandidate(at index: Int, matching trackID: Int) -> PlaybackQueueCandidate? {
        let candidates = PlaybackQueuePlan.next(queue: activeQueue, currentIndex: currentIndex, inserted: playNextList,
                                                fm: [], isFM: false, repeatAll: false, limit: max(0, index + 1))
        guard candidates.indices.contains(index), candidates[index].track.id == trackID else { return nil }
        return candidates[index]
    }

    // MARK: - Personal FM

    func startFM() {
        beginPlaybackIntent()
        guard fmRequestID == nil, !isFMMode || !isPlaying else { return }
        recordRecent(.fm)
        isFMMode = true
        shuffleEnabled = false
        repeatMode = .off
        queue = []
        shuffledQueue = []
        playNextList = []
        currentIndex = -1
        source = .none
        Task { await fmAdvance() }
    }

    func fmNext() {
        beginPlaybackIntent()
        guard isFMMode else { return }
        Task { await fmAdvance() }
    }

    func fmTrash() {
        beginPlaybackIntent()
        guard isFMMode, let track = currentTrack else { return }
        let scope = offlineAccountScope
        Task {
            await fmAdvance()
            guard scope == offlineAccountScope else { return }
            try? await MusicAPI.fmTrash(id: track.id)
        }
    }

    private func fmAdvance() async {
        guard isFMMode, fmRequestID == nil else { return }
        if usesOfflineQueue {
            advanceOffline()
            return
        }
        let request = UUID()
        fmRequestID = request
        let scope = offlineAccountScope
        let generation = resolveGeneration
        defer { if fmRequestID == request { fmRequestID = nil } }

        func isCurrent(_ generation: Int) -> Bool {
            fmRequestID == request && isFMMode && scope == offlineAccountScope
                && generation == resolveGeneration && !Task.isCancelled
        }
        if fmUpcoming.isEmpty {
            for attempt in 0..<3 {
                guard isCurrent(generation) else { return }
                let tracks = try? await MusicAPI.personalFM()
                guard isCurrent(generation) else { return }
                if let tracks, !tracks.isEmpty {
                    fmUpcoming = tracks
                    break
                }
                if attempt == 2 {
                    ToastCenter.shared.show(String(localized: "获取私人漫游数据失败"))
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
        guard isCurrent(generation), !fmUpcoming.isEmpty else { return }
        let track = fmUpcoming.removeFirst()
        pendingAutoAdvance = true
        startPlaying(track)
        fmRequestID = nil
        if fmUpcoming.isEmpty {
            let playingGeneration = resolveGeneration
            let more = try? await MusicAPI.personalFM()
            guard fmRequestID == nil, isFMMode, scope == offlineAccountScope, !Task.isCancelled,
                  playingGeneration == resolveGeneration, fmUpcoming.isEmpty, let more else { return }
            fmUpcoming.append(contentsOf: more)
        }
    }

    // MARK: - Advancing

    private func advanceToNext(userInitiated: Bool) {
        if usesOfflineQueue, !nextCandidates().isEmpty {
            pendingAutoAdvance = !userInitiated
            advanceOffline()
            return
        }
        if isFMMode {
            Task { await fmAdvance() }
            return
        }
        if !playNextList.isEmpty {
            let track = playNextList.removeFirst()
            pendingAutoAdvance = !userInitiated
            startPlaying(track)
            return
        }
        guard !activeQueue.isEmpty else { return }
        var idx = currentIndex + 1
        if idx >= activeQueue.count {
            guard repeatMode == .all else {
                if userInitiated {
                    ToastCenter.shared.show(String(localized: "已经是最后一首了"))
                } else {
                    isPlaying = false
                    NowPlayingManager.shared.updateElapsed(progress, rate: 0)
                }
                return
            }
            idx = 0
        }
        currentIndex = idx
        pendingAutoAdvance = !userInitiated
        startPlaying(activeQueue[idx])
    }

    private func handleItemEnded() {
        scrobbleIfNeeded(completed: true)

        if sleepTimer.consumeEndOfCurrentTrack() {
            progress = duration
            updateLyricsCursor(at: duration)
            pause()
            engine.replaceCurrentItem(with: nil)
            releaseCurrentPlaybackResources()
            return
        }

        guard isPlaying else { return }

        if repeatMode == .one, !isFMMode {
            scrobbled = false
            seek(to: 0)
            engine.play()
            isPlaying = true
            return
        }
        advanceToNext(userInitiated: false)
    }

    // MARK: - Source resolution

    /// 播放中改音质：按当前位置重新解析并装载，队列/歌词/进度都不丢。
    func reloadCurrentTrackForQualityChange() {
        guard let track = currentTrack else { return }
        startPlaying(track, resumeAt: progress)
    }

    private func startPlaying(_ track: Track,
                              localLease: OfflinePlaybackLease? = nil, resumeAt: TimeInterval = 0) {
        offlineScan?.cancel()
        offlineScan = nil
        offlineScanID = UUID()
        offlineIssue = nil
        currentWasAdvanced = pendingAutoAdvance
        pendingAutoAdvance = false
        pendingAudioResourceLoader?.cancel()
        pendingAudioResourceLoader = nil
        scrobbleIfNeeded(completed: false)
        currentTrack = track
        playbackAccountID = AccountStore.shared.profile?.userId
        progress = resumeAt
        duration = track.duration
        servedQuality = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        isTrial = false
        lyrics = nil
        scrobbled = false
        startScrobbled = false
        isPlaying = true
        lyricsCursor.activeIndex = nil
        // Before the URL is even resolved: holds the bars still rather than
        // letting them fall back to the decorative animation for the moment it
        // takes to find out whether this source can be tapped.
        AudioSpectrum.shared.beginPreparing()
        resolveGeneration += 1
        let generation = resolveGeneration
        if advancingAfterFailure {
            advancingAfterFailure = false
        } else {
            consecutiveFailures = 0
        }

        NowPlayingManager.shared.updateMetadata(for: track, duration: track.duration)
        persistState()

        Task {
            await resolveAndLoad(track, generation: generation, localLease: localLease, resumeAt: resumeAt)
        }
        Task {
            await loadLyrics(for: track, generation: generation)
        }
    }

    /// - Parameter skipsLocalCopies: set when the downloaded or cached copy
    ///   just failed to play, so the reload fetches the song again instead
    ///   of the same file.
    private func resolveAndLoad(_ track: Track, generation: Int,
                                localLease: OfflinePlaybackLease? = nil,
                                skipsLocalCopies: Bool = false,
                                resumeAt: TimeInterval = 0) async {
        let quality = SettingsManager.shared.audioQuality.normalized.apiLevel
        let cacheEnabled = SettingsManager.shared.enableAudioCache && !skipsLocalCopies
        lastResolveFailure = nil
        lastRefusalCode = nil

        // A downloaded copy beats the network, and is all there is without one.
        if !skipsLocalCopies, let lease = await acquireOfflineLease(for: track, generation: generation, reusing: localLease) {
            await playOfflineFile(lease, for: track, generation: generation, resumeAt: resumeAt)
            return
        }
        guard generation == resolveGeneration else { return }

        if cacheEnabled {
            do {
                if let cached = try await AudioCache.shared.entry(
                    for: track.id,
                    requestedQuality: quality,
                    allowsUnblock: false
                ) {
                    guard generation == resolveGeneration else { return }
                    let lease = await AudioCache.shared.retain(cached)
                    guard generation == resolveGeneration else {
                        releaseAudioCacheLease(lease)
                        return
                    }
                    servedQuality = cached.metadata.servedQuality
                    await installResolvedAsset(
                        AVURLAsset(url: cached.fileURL),
                        for: track,
                        generation: generation,
                        durationMS: nil,
                        cacheLease: lease,
                        resumeAt: resumeAt
                    )
                    return
                }
            } catch {
                print("Audio cache lookup failed: \(error)")
            }
        }

        // Without a network, the cache is the last place to look.
        if usesOfflineQueue {
            if cacheEnabled, await loadFallbackCache(for: track, generation: generation, resumeAt: resumeAt) { return }
            guard generation == resolveGeneration else { return }
            unavailableOffline(track, generation: generation)
            return
        }

        // ── 以下与最初版本（34737e1）逐字一致：取地址 → 直连 AVURLAsset → 装 item ──
        let settingsQuality = SettingsManager.shared.audioQuality.normalized.apiLevel
        var data = try? await MusicAPI.songURL(ids: [track.id], level: settingsQuality).first
        if data?.url == nil, settingsQuality != AudioQuality.standard.apiLevel {
            data = try? await MusicAPI.songURL(ids: [track.id], level: AudioQuality.standard.apiLevel).first
        }
        guard generation == resolveGeneration else { return }

        var resolvedURL: URL?
        if let urlString = data?.url {
            resolvedURL = URL(string: urlString.replacingOccurrences(of: "http://", with: "https://"))
        }

        guard generation == resolveGeneration else { return }

        guard let url = resolvedURL else {
            consecutiveFailures += 1
            let reason = track.playability(privilege: nil,
                                           isLoggedIn: AccountStore.shared.isLoggedIn,
                                           vipType: AccountStore.shared.vipType).reason
            ToastCenter.shared.show(String(localized: "《\(track.name)》无法播放\(reason.map { "：\($0)" } ?? "")"))
            guard isPlaying else {
                engine.replaceCurrentItem(with: nil)
                return
            }
            if consecutiveFailures < 5 {
                advanceToNext(userInitiated: false)
            } else {
                isPlaying = false
            }
            return
        }

        consecutiveFailures = 0
        servedQuality = data?.level
        if data?.freeTrialInfo != nil {
            isTrial = true
            ToastCenter.shared.show(String(localized: "VIP 歌曲，当前为试听片段"))
        }

        // 无损 / Hi-Res / 母带：换帧精确引擎（见 flacPlayer 的注释）。
        if data?.type?.lowercased() == "flac" {
            await installFLACSource(url, for: track, generation: generation,
                                    durationMS: data?.time, resumeAt: resumeAt)
            return
        }

        let asset = AVURLAsset(url: url)
        let assetTrack = await loadAudioTrack(from: asset, timeout: 2)
        guard generation == resolveGeneration else { return }

        stopFLAC()
        let item = AVPlayerItem(asset: asset)
        if let assetTrack, let mix = AudioSpectrum.shared.makeAudioMix(for: assetTrack) {
            item.audioMix = mix
        } else {
            AudioSpectrum.shared.markUntappable()
        }

        if let old = endObserver {
            NotificationCenter.default.removeObserver(old)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleItemEnded()
            }
        }
        engine.replaceCurrentItem(with: item)
        if isPlaying {
            engine.play()
            scrobbleStartIfNeeded()
        }

        if let time = data?.time, time > 0 {
            duration = TimeInterval(time) / 1000
            NowPlayingManager.shared.updateMetadata(for: track, duration: duration)
        }
    }

    // MARK: - FLAC source

    private func installFLACSource(_ url: URL, for track: Track, generation: Int,
                                   durationMS: Int?, resumeAt: TimeInterval) async {
        let remote = CDNHost.preferred(for: url)
        do {
            let local = try await FLACFileStore.localCopy(of: remote, trackID: track.id)
            guard generation == resolveGeneration else { return }
            // 同一时刻只允许一路音源：先把 AVPlayer 那条彻底停掉，
            // 否则 mp3 还在播、FLAC 又起，就成了两首歌叠在一起。
            engine.pause()
            engine.replaceCurrentItem(with: nil)
            stopFLAC()
            let player = FLACFilePlayer()
            try player.load(url: local, startAt: resumeAt, autoplay: false)
            player.onEnded = { [weak self] in self?.handleItemEnded() }
            player.setVolume(volume)
            flacPlayer = player
            if let ms = durationMS, ms > 0 {
                duration = TimeInterval(ms) / 1000
                NowPlayingManager.shared.updateMetadata(for: track, duration: duration)
            }
            if isPlaying {
                player.play()
                scrobbleStartIfNeeded()
            }
            startFLACTimer()
        } catch {
            print("FLAC load failed: \(error)")
            handleUnplayable(track)
        }
    }

    /// FLAC 分支的 0.2s 采样：歌词每 tick 跟，进度条/锁屏按 0.45s 阈值发布，
    /// 与 AVPlayer 那条观察器保持同一节奏。
    private func startFLACTimer() {
        flacTimer?.invalidate()
        flacTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.flacPlayer, !self.isScrubbing else { return }
                let seconds = player.position
                guard seconds.isFinite else { return }
                self.updateLyricsCursor(at: seconds)
                if abs(seconds - self.progress) > 0.45 {
                    self.progress = seconds
                    NowPlayingManager.shared.updateElapsed(seconds, rate: self.isPlaying ? 1 : 0)
                }
                if self.isPlaying, self.lastPlaybackCheckpoint.duration(to: .now) >= .seconds(20) {
                    self.lastPlaybackCheckpoint = .now
                    self.persistState()
                }
            }
        }
    }

    private func stopFLAC() {
        flacTimer?.invalidate()
        flacTimer = nil
        flacPlayer?.stop()
        flacPlayer = nil
    }

    private func handleUnplayable(_ track: Track) {
        consecutiveFailures += 1
        let reason = lastResolveFailure
            ?? track.playability(privilege: nil,
                                 isLoggedIn: AccountStore.shared.isLoggedIn,
                                 vipType: AccountStore.shared.vipType).reason
            ?? lastRefusalCode.map { String(localized: "网易云未给出播放地址（\($0)）") }
        ToastCenter.shared.show(String(localized: "《\(track.name)》无法播放\(reason.map { "：\($0)" } ?? "")"))
        guard isPlaying else {
            engine.replaceCurrentItem(with: nil)
            releaseCurrentPlaybackResources()
            return
        }
        if consecutiveFailures < 5 {
            advancingAfterFailure = true
            advanceToNext(userInitiated: false)
        } else {
            isPlaying = false
        }
    }

    /// 装载新的网络音源前，先把 FLAC 那条通道停掉（两路音源不能并存）。
    private func loadResolvedURL(
        _ track: Track,
        url: URL,
        durationMS: Int?,
        generation: Int,
        resumeAt: TimeInterval = 0
    ) async {
        // Skip a CDN host that just failed to connect (see CDNHost).
        let remote = CDNHost.preferred(for: url)

        // 直接交给 AVPlayer 取字节：中间那层自建字节范围加载器会在拖动时
        // 重排 Range、换到孪生 CDN 再拼接，AVPlayer 的时钟就和实际播出的帧脱钩，
        // 表现为「进度条到位、声音没到位」（高档位文件大时才明显）。缓存仍然
        // 服务于已下载 / 整首缓存的条目（loadFallbackCache 走本地文件）。
        let asset = AVURLAsset(url: remote)

        await installResolvedAsset(
            asset,
            for: track,
            generation: generation,
            durationMS: durationMS,
            remoteURL: remote,
            resourceLoader: nil,
            resumeAt: resumeAt
        )
    }

    private func loadFallbackCache(
        for track: Track,
        generation: Int,
        resumeAt: TimeInterval = 0
    ) async -> Bool {
        do {
            guard let cached = try await AudioCache.shared.fallbackEntry(
                for: track.id,
                allowsUnblock: false
            ) else { return false }
            guard generation == resolveGeneration else { return true }
            let lease = await AudioCache.shared.retain(cached)
            guard generation == resolveGeneration else {
                releaseAudioCacheLease(lease)
                return true
            }
            servedQuality = cached.metadata.servedQuality
            await installResolvedAsset(
                AVURLAsset(url: cached.fileURL),
                for: track,
                generation: generation,
                durationMS: nil,
                cacheLease: lease,
                resumeAt: resumeAt
            )
            return true
        } catch {
            print("Audio cache fallback lookup failed: \(error)")
            return false
        }
    }

    private func installResolvedAsset(
        _ asset: AVURLAsset,
        for track: Track,
        generation: Int,
        durationMS: Int?,
        remoteURL: URL? = nil,
        resourceLoader: CachingAudioResourceLoader? = nil,
        cacheLease: UUID? = nil,
        offlineLease: OfflinePlaybackLease? = nil,
        resumeAt: TimeInterval = 0
    ) async {
        // Resolve the audio track before the item goes live: an audio mix attached
        // after playback starts is silently ignored. The one tap now drives both
        // the spectrum and iOS equalizer, so local/cache/offline assets take the
        // same path as remote streams. Unsupported sources still play untouched.
        let assetTrack = await loadAudioTrack(from: asset, timeout: 2)
        guard generation == resolveGeneration,
              resourceLoader.map({ pendingAudioResourceLoader === $0 }) ?? true else {
            resourceLoader?.cancel()
            if let cacheLease {
                releaseAudioCacheLease(cacheLease)
            }
            if let offlineLease { Task { try? await OfflineStore.shared.release(offlineLease) } }
            return
        }

        let item = AVPlayerItem(asset: asset)
        if let assetTrack,
           let mix = AudioSpectrum.shared.makeAudioMix(for: assetTrack) {
            item.audioMix = mix
        } else {
            AudioSpectrum.shared.markUntappable()
        }

        itemStatusObservation?.invalidate()
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            switch item.status {
            case .readyToPlay:
                Task { @MainActor in
                    self?.itemBecameReady(generation: generation)
                }
            case .failed:
                let error = item.error
                Task { @MainActor in
                    self?.handleItemFailure(
                        track: track,
                        generation: generation,
                        remoteURL: remoteURL,
                        durationMS: durationMS,
                        error: error
                    )
                }
            default:
                break
            }
        }

        if let old = endObserver {
            NotificationCenter.default.removeObserver(old)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleItemEnded()
            }
        }
        let previousResourceLoader = audioResourceLoader
        let previousCacheLease = audioCacheLease
        let previousOfflineLease = offlinePlaybackLease
        if resourceLoader != nil {
            pendingAudioResourceLoader = nil
        }
        audioResourceLoader = resourceLoader
        audioCacheLease = cacheLease
        offlinePlaybackLease = offlineLease
        engine.replaceCurrentItem(with: item)
        previousResourceLoader?.cancel()
        if let previousCacheLease {
            releaseAudioCacheLease(previousCacheLease)
        }
        if let previousOfflineLease { Task { try? await OfflineStore.shared.release(previousOfflineLease) } }
        if resumeAt > 0 {
            // The item's own length when known; the published duration may
            // still belong to the previous song or be unknown.
            let length = durationMS.map { TimeInterval($0) / 1000 } ?? duration
            let time = CMTime(seconds: length > 0.1 ? min(resumeAt, length - 0.1) : resumeAt, preferredTimescale: 600)
            _ = await engine.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            guard generation == resolveGeneration else { return }
        }
        if isPlaying {
            engine.play()
            scrobbleStartIfNeeded()
        }
        previousResourceLoader?.cancel()
        if let previousCacheLease {
            releaseAudioCacheLease(previousCacheLease)
        }
        if let previousOfflineLease { Task { try? await OfflineStore.shared.release(previousOfflineLease) } }

        if let durationMS, durationMS > 0 {
            duration = TimeInterval(durationMS) / 1000
            NowPlayingManager.shared.updateMetadata(for: track, duration: duration)
        }
    }

    /// The song is playing for real: the failure streak is over.
    private func itemBecameReady(generation: Int) {
        guard generation == resolveGeneration else { return }
        consecutiveFailures = 0
    }

    /// An upstream stream or a cached file failed. The song gets one reload,
    /// resuming where it stopped: on the CDN twin when the host could not be
    /// reached (the caching loader already swaps hosts itself, so this covers
    /// streams that bypass it), otherwise from a freshly resolved URL, since a
    /// signature may have expired, the network changed, or the local file
    /// was bad. With no network at all, or when the reload fails for lack of
    /// one, a downloaded copy takes over; any other second failure skips.
    private func handleItemFailure(
        track: Track,
        generation: Int,
        remoteURL: URL?,
        durationMS: Int?,
        error: Error?
    ) {
        guard generation == resolveGeneration, currentTrack?.id == track.id else { return }

        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        engine.replaceCurrentItem(with: nil)
        releaseCurrentPlaybackResources()
        let connectivity = error.map(ConnectivityFailure.matches) ?? false

        guard itemRetryGeneration != generation else {
            if connectivity {
                handleConnectivityItemFailure(track: track, generation: generation)
                return
            }
            handleUnplayable(track)
            return
        }
        itemRetryGeneration = generation
        let twin = remoteURL.flatMap { url in
            error.flatMap { CDNHost.failover(from: url, after: $0) }
        }
        // No network at all: the downloaded copy is the only way on.
        if twin == nil, connectivity, usesOfflineQueue {
            handleConnectivityItemFailure(track: track, generation: generation)
            return
        }
        AudioSpectrum.shared.beginPreparing()
        let resumeAt = progress > 1 ? progress : 0
        Task {
            if let twin {
                await loadResolvedURL(track, url: twin, durationMS: durationMS, generation: generation, resumeAt: resumeAt)
            } else {
                await resolveAndLoad(track, generation: generation, skipsLocalCopies: remoteURL == nil, resumeAt: resumeAt)
            }
        }
    }

    private func releaseAudioCacheLease(_ leaseID: UUID) {
        Task {
            do {
                try await AudioCache.shared.release(leaseID)
            } catch {
                print("Audio cache could not release its playback lease: \(error)")
            }
        }
    }

    private func releaseCurrentPlaybackResources() {
        stopFLAC()
        let resourceLoader = audioResourceLoader
        let cacheLease = audioCacheLease
        audioResourceLoader = nil
        audioCacheLease = nil
        resourceLoader?.cancel()
        if let cacheLease {
            releaseAudioCacheLease(cacheLease)
        }
        releaseOfflineLease()
    }

    /// Resolves the asset's audio track, giving up after `timeout` so a slow or
    /// uncooperative source delays playback no longer than it would today.
    private func loadAudioTrack(from asset: AVURLAsset, timeout: TimeInterval) async -> AVAssetTrack? {
        await withTaskGroup(of: AVAssetTrack?.self) { group in
            group.addTask {
                try? await asset.loadTracks(withMediaType: .audio).first
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func loadLyrics(for track: Track, generation: Int) async {
        let scope = offlineAccountScope
        if let scope, let saved = await OfflineMetadataStore.shared.lyrics(trackID: track.id, scope: scope) {
            guard generation == resolveGeneration else { return }
            lyrics = LyricsParser.parse(saved)
            updateLyricsCursor(at: progress)
        }
        guard !usesOfflineQueue else { return }
        let response = try? await MusicAPI.lyric(id: track.id)
        guard generation == resolveGeneration, let response else { return }
        lyrics = LyricsParser.parse(response)
        updateLyricsCursor(at: progress)
        // 歌词文本很小：听过就缓存，不依赖「歌曲缓存」开关或是否已下载。
        if let scope {
            await OfflineMetadataStore.shared.keepPlaybackData(track: track, lyrics: response, scope: scope)
        }
    }

    // MARK: - Offline playback

    /// Downloads belong to one account; see `activateAccount`.
    private var offlineAccountScope: String? { AccountStore.shared.offlineScope }
    private var usesOfflineQueue: Bool { networkState.isKnown && !networkState.connected }

    private func nextCandidates() -> [PlaybackQueueCandidate] {
        PlaybackQueuePlan.next(queue: activeQueue, currentIndex: currentIndex, inserted: playNextList,
                               fm: fmUpcoming, isFM: isFMMode, repeatAll: repeatMode == .all)
    }

    /// Everything the prefetch window depends on. `@Published` fires before
    /// the value lands, so the update itself waits for the next turn.
    private func observePrefetchInputs() {
        let player: [AnyPublisher<Void, Never>] = [
            $queue.map { _ in }.eraseToAnyPublisher(), $shuffledQueue.map { _ in }.eraseToAnyPublisher(),
            $shuffleEnabled.map { _ in }.eraseToAnyPublisher(), $playNextList.map { _ in }.eraseToAnyPublisher(),
            $currentIndex.map { _ in }.eraseToAnyPublisher(), $currentTrack.map { _ in }.eraseToAnyPublisher(),
            $fmUpcoming.map { _ in }.eraseToAnyPublisher(), $isFMMode.map { _ in }.eraseToAnyPublisher(),
            $repeatMode.map { _ in }.eraseToAnyPublisher(), $isPlaying.map { _ in }.eraseToAnyPublisher(),
            $isBuffering.map { _ in }.eraseToAnyPublisher(),
        ]
        let environment: [AnyPublisher<Void, Never>] = [
            DownloadManager.shared.$network.map { _ in }.eraseToAnyPublisher(),
            DownloadManager.shared.$jobs.map { _ in }.eraseToAnyPublisher(),
            SettingsManager.shared.$enableAudioCache.map { _ in }.eraseToAnyPublisher(),
            SettingsManager.shared.$audioQuality.map { _ in }.eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).map { _ in }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(player + environment)
            .sink { [weak self] _ in self?.scheduleUpdatePrefetch() }
            .store(in: &prefetchObservations)
    }

    private func scheduleUpdatePrefetch() {
        guard !prefetchUpdateScheduled else { return }
        prefetchUpdateScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.prefetchUpdateScheduled = false
            self.updatePrefetch()
        }
    }

    private func updatePrefetch() {
        guard isPlaying, !isBuffering, SettingsManager.shared.enableAudioCache, let current = currentTrack,
              QueuePrefetcher.permits(network: networkState, lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
        else { queuePrefetcher.update(nil); return }
        let upcoming = PrefetchLimits().window(nextCandidates().map(\.track))
        guard !upcoming.isEmpty else { queuePrefetcher.update(nil); return }
        let scope = offlineAccountScope
        let pending = Set(DownloadManager.shared.pendingJobs.filter { $0.accountScope == scope }.map(\.track.id))
        queuePrefetcher.update(.init(scope: scope, currentTrackID: current.id, tracks: upcoming,
                                     quality: SettingsManager.shared.audioQuality.rawValue,
                                     allowsUnblock: false,
                                     pendingDownloadTrackIDs: pending))
    }

    /// A downloaded copy of the track. Online it must match the chosen quality
    /// or better; offline, any quality will do.
    private func acquireOfflineLease(for track: Track, generation: Int, reusing lease: OfflinePlaybackLease? = nil,
                                     anyQuality: Bool = false) async -> OfflinePlaybackLease? {
        let scope = offlineAccountScope
        var lease = lease
        if lease == nil, let scope {
            // 本地优先：只要机器上有这首的下载，就用它，哪怕档位和设置里的不一致
            // （下载音质与播放音质已经分开设置，用户下过的内容不该被白放着）。
            lease = try? await OfflineStore.shared.acquire(accountScope: scope, trackID: track.id,
                preferredQuality: SettingsManager.shared.audioQuality.rawValue,
                allowLowerQuality: true)
        }
        guard let lease else { return nil }
        guard generation == resolveGeneration, scope == offlineAccountScope,
              lease.descriptor.identity.accountScope == scope else {
            try? await OfflineStore.shared.release(lease)
            return nil
        }
        return lease
    }

    private func playOfflineFile(_ lease: OfflinePlaybackLease, for track: Track, generation: Int,
                                 resumeAt: TimeInterval = 0) async {
        servedQuality = lease.descriptor.identity.quality
        await installResolvedAsset(AVURLAsset(url: lease.url), for: track, generation: generation,
                                       durationMS: Int(lease.descriptor.duration * 1000),
                                       offlineLease: lease, resumeAt: resumeAt)
    }

    /// The stream died for lack of network. A download of the same song picks
    /// up where it stopped; otherwise the song is reported or skipped.
    private func handleConnectivityItemFailure(track: Track, generation: Int) {
        guard generation == resolveGeneration, currentTrack?.id == track.id else { return }
        let position = max(progress, livePlaybackTime)
        resolveGeneration += 1
        let recovery = resolveGeneration
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        engine.replaceCurrentItem(with: nil)
        releaseCurrentPlaybackResources()
        Task {
            if let lease = await acquireOfflineLease(for: track, generation: recovery, anyQuality: true) {
                await playOfflineFile(lease, for: track, generation: recovery, resumeAt: position)
                return
            }
            guard recovery == resolveGeneration else { return }
            unavailableOffline(track, generation: recovery, autoAdvance: currentWasAdvanced && position < 0.5)
        }
    }

    private func releaseOfflineLease() {
        guard let lease = offlinePlaybackLease else { return }
        offlinePlaybackLease = nil
        Task { try? await OfflineStore.shared.release(lease) }
    }

    private func unavailableOffline(_ track: Track, generation: Int, autoAdvance: Bool? = nil) {
        guard generation == resolveGeneration else { return }
        if autoAdvance ?? currentWasAdvanced {
            advanceOffline(initialSkipped: 1, excludingFailedCurrent: true)
            return
        }
        engine.replaceCurrentItem(with: nil)
        releaseCurrentPlaybackResources()
        isPlaying = false
        isBuffering = false
        offlineIssue = .init(kind: .missingTrack, trackName: track.name)
        NowPlayingManager.shared.updateElapsed(progress, rate: 0)
    }

    func playNextAvailableOffline() {
        offlineIssue = nil
        advanceOffline()
    }

    /// Walks the upcoming list for the first song that is on this device.
    private func advanceOffline(initialSkipped: Int = 0, excludingFailedCurrent: Bool = false) {
        offlineScan?.cancel()
        let requestID = UUID()
        offlineScanID = requestID
        resolveGeneration += 1
        let generation = resolveGeneration
        let scope = offlineAccountScope
        var candidates = nextCandidates()
        if excludingFailedCurrent { candidates.removeAll { $0.origin == .queue(currentIndex) } }
        engine.replaceCurrentItem(with: nil)
        releaseCurrentPlaybackResources()
        isPlaying = false
        offlineScan = Task { [weak self] in
            guard let self, !Task.isCancelled, self.offlineScanID == requestID else { return }
            let selected = try? await OfflineQueueSelector.firstAvailable(candidates, scope: scope,
                quality: SettingsManager.shared.audioQuality.rawValue, store: .shared,
                isCached: { await self.isCachedForOffline($0) })
            guard !Task.isCancelled, self.offlineScanID == requestID, self.resolveGeneration == generation,
                  self.offlineAccountScope == scope else {
                if let lease = selected?.lease { try? await OfflineStore.shared.release(lease) }
                return
            }
            self.offlineScan = nil
            guard let selected else {
                self.pendingAutoAdvance = false
                self.offlineIssue = .init(kind: .emptyQueue, trackName: nil)
                self.isBuffering = false
                NowPlayingManager.shared.updateElapsed(self.progress, rate: 0)
                return
            }
            // The queue may have been edited while the scan ran.
            guard self.stillHolds(selected.candidate) else {
                if let lease = selected.lease { try? await OfflineStore.shared.release(lease) }
                self.advanceOffline(initialSkipped: initialSkipped, excludingFailedCurrent: excludingFailedCurrent)
                return
            }
            switch selected.candidate.origin {
            case .inserted(let index): self.playNextList.removeSubrange(0...index)
            case .queue(let index):
                if !self.playNextList.isEmpty { self.playNextList.removeAll() }
                self.currentIndex = index
            case .fm(let index): self.fmUpcoming.removeSubrange(0...index)
            }
            let skipped = initialSkipped + selected.skipped
            self.pendingAutoAdvance = true
            self.startPlaying(selected.candidate.track, localLease: selected.lease)
            if skipped > 0 { ToastCenter.shared.show(String(localized: "已跳过 \(skipped) 首未下载歌曲")) }
        }
    }

    /// Whether the song cache can play the track without the network.
    private func isCachedForOffline(_ trackID: Int) async -> Bool {
        guard SettingsManager.shared.enableAudioCache else { return false }
        return (try? await AudioCache.shared.fallbackEntry(for: trackID, allowsUnblock: false)) != nil
    }

    private func stillHolds(_ candidate: PlaybackQueueCandidate) -> Bool {
        switch candidate.origin {
        case .inserted(let index): return playNextList.indices.contains(index) && playNextList[index].id == candidate.track.id
        case .queue(let index): return activeQueue.indices.contains(index) && activeQueue[index].id == candidate.track.id
        case .fm(let index): return fmUpcoming.indices.contains(index) && fmUpcoming[index].id == candidate.track.id
        }
    }

    /// Downloads belong to one account. Audio leased under the previous
    /// account stops, and the offline queue scan starts over.
    func activateAccount(scope: String?) {
        guard offlineActivatedScope != scope else { return }
        offlineActivatedScope = scope
        fmRequestID = nil
        if !fmUpcoming.isEmpty { fmUpcoming = [] }
        offlineScan?.cancel()
        offlineScan = nil
        offlineScanID = UUID()
        offlineIssue = nil
        scheduleUpdatePrefetch()
        guard offlinePlaybackLease != nil else { return }
        resolveGeneration += 1
        engine.replaceCurrentItem(with: nil)
        releaseCurrentPlaybackResources()
        isPlaying = false
        NowPlayingManager.shared.updateElapsed(progress, rate: 0)
    }

    // MARK: - Scrobble

    private func scrobbleStartIfNeeded() {
        guard let track = currentTrack, !startScrobbled else { return }
        startScrobbled = true
        let trackID = track.id
        let sourceID = source.sourceID
        Task.detached {
            await MusicAPI.scrobbleStart(trackID: trackID, sourceID: sourceID)
        }
    }

    private func scrobbleIfNeeded(completed: Bool) {
        guard let track = currentTrack, !scrobbled, progress > 1 else { return }
        scrobbled = true
        let seconds = completed ? Int(duration) : Int(progress)
        let sourceID = source.sourceID
        Task.detached {
            await MusicAPI.scrobbleFinish(trackID: track.id, sourceID: sourceID, seconds: seconds)
        }
    }

    // MARK: - Shuffle helpers

    private func reshuffle(keeping first: Track) {
        var rest = queue
        if let index = rest.firstIndex(where: { $0.id == first.id }) { rest.remove(at: index) }
        rest.shuffle()
        shuffledQueue = [first] + rest
    }

    // MARK: - Persistence

    private static let recentContextsLimit = 6

    private func recordRecent(_ context: PlayContext) {
        recentContexts.removeAll { $0 == context }
        recentContexts.insert(context, at: 0)
        if recentContexts.count > Self.recentContextsLimit {
            recentContexts.removeLast(recentContexts.count - Self.recentContextsLimit)
        }
    }

    /// Reloads a place from the recents list and starts playing it again.
    func play(context: PlayContext) {
        beginPlaybackIntent()
        // Personal FM is a stream, not a fixed list — restart it in place.
        guard context.kind != .fm else { return startFM() }
        Task {
            do {
                guard let resolved = try await resolve(context) else { return }
                play(tracks: resolved.tracks, source: resolved.source, context: context)
            } catch {
                ToastCenter.shared.show(error.localizedDescription)
            }
        }
    }

    func resolve(_ context: PlayContext) async throws -> (tracks: [Track], source: PlaySource)? {
        try await OfflineContextResolver.resolve(context, offline: usesOfflineQueue) { try await resolveOnline(context) }
    }

    private func resolveOnline(_ context: PlayContext) async throws -> (tracks: [Track], source: PlaySource)? {
        switch context.kind {
        case .fm:
            return nil
        case .album:
            return (try await MusicAPI.album(id: context.id).songs, .album(context.id))
        case .artist:
            return (try await MusicAPI.artist(id: context.id).hotSongs, .artist(context.id))
        case .daily:
            return (try await MusicAPI.dailyRecommendSongs(), .daily)
        case .cloud:
            let songs = try await MusicAPI.cloudSongs().data?.compactMap(\.simpleSong) ?? []
            return (songs, .cloud)
        case .recents:
            guard AccountStore.shared.isLoggedIn else { return nil }
            return (try await MusicAPI.recentSongs().map(\.song), .none)
        case .heartbeat:
            // Regenerated from a fresh seed, the same way the Home card does it.
            guard let liked = AccountStore.shared.likedSongsPlaylist,
                  let seed = AccountStore.shared.likedTrackIDs.randomElement() else { return nil }
            let tracks = try await MusicAPI.intelligenceList(songID: seed, playlistID: liked.id)
            return (tracks, .playlist(liked.id))
        case .playlist:
            let response = try await MusicAPI.playlistDetail(id: context.id)
            var tracks = response.playlist.tracks
            // /v6/playlist/detail only carries the first page of tracks.
            let remaining = response.playlist.trackIds.map(\.id).dropFirst(tracks.count)
            for chunk in stride(from: 0, to: remaining.count, by: 500)
                .map({ Array(remaining.dropFirst($0).prefix(500)) }) {
                guard let more = try? await MusicAPI.songDetails(ids: chunk) else { break }
                tracks += more.songs
            }
            return (tracks, .playlist(context.id))
        }
    }

    var playbackSession: PlaybackSession? {
        guard let currentTrack else { return nil }
        return PlaybackSession(accountID: playbackAccountID, queue: queue, orderedQueue: activeQueue,
                               currentIndex: currentIndex, currentTrack: currentTrack, playNext: playNextList,
                               source: source, repeatMode: repeatMode.rawValue, shuffled: shuffleEnabled,
                               automaticOrder: false, isFM: isFMMode, progress: progress)
    }

    func resume(_ session: PlaybackSession) throws {
        let accountID = AccountStore.shared.authenticatedAccountID
        try session.validateAccess(accountID: accountID)
        scrobbleIfNeeded(completed: false)
        pause()
        applyPlaybackSession(session)
        startPlaying(session.currentTrack, resumeAt: session.progress)
    }

    private func applyPlaybackSession(_ session: PlaybackSession) {
        // Materialize a Mac AutoMix order on iOS, which has no AutoMix engine.
        queue = session.automaticOrder ? session.orderedQueue : session.queue
        shuffledQueue = session.shuffled ? session.orderedQueue : []
        shuffleEnabled = session.shuffled
        currentIndex = session.currentIndex
        currentTrack = session.currentTrack
        playbackAccountID = session.accountID
        playNextList = session.playNext
        source = session.source
        if let mode = RepeatMode(rawValue: session.repeatMode) { repeatMode = mode }
        isFMMode = session.isFM
        fmRequestID = nil
        fmUpcoming = []
        progress = session.progress
        duration = session.currentTrack.duration
        scrobbled = true
    }

    func checkpointPlayback() { persistState() }

    func suspendForAccountChange() {
        resolveGeneration += 1
        scrobbled = true
        pause()
        pendingAudioResourceLoader?.cancel()
        pendingAudioResourceLoader = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        engine.replaceCurrentItem(with: nil)
        releaseCurrentPlaybackResources()
    }

    private func persistState() {
        lastPlaybackCheckpoint = .now
        let state = PlaybackState(session: playbackSession, recentContexts: recentContexts)
        PlaybackStateStorage.save(state, to: Self.stateFileURL)
    }

    private func restoreState() {
        guard let data = try? Data(contentsOf: Self.stateFileURL),
              let state = try? JSONDecoder().decode(PlaybackState.self, from: data)
        else { return }
        // Recents outlive the queue: restore them before bailing out on an
        // empty queue, or the next played track persists an empty list over
        // them and the Dock menu loses its history for good.
        recentContexts = Array((state.recentContexts ?? []).prefix(Self.recentContextsLimit))
        if let session = state.session {
            do {
                try session.validate()
                applyPlaybackSession(session)
                NowPlayingManager.shared.updateMetadata(for: session.currentTrack, duration: duration)
                // 冷启动就把上次那首的歌词读进内存（命中离线缓存则立刻可显示），
                // 不必等用户按播放才出现歌词。进度已由 applyPlaybackSession 从
                // session.progress 恢复。
                Task {
                    await loadLyrics(for: session.currentTrack, generation: resolveGeneration)
                }
            } catch { ToastCenter.shared.show(error.localizedDescription) }
            return
        }
        guard let legacy = state.legacy, !legacy.queue.isEmpty else { return }
        queue = legacy.queue
        shuffleEnabled = legacy.shuffle
        if shuffleEnabled {
            shuffledQueue = queue.shuffled()
        }
        if let id = legacy.currentID,
           let idx = activeQueue.firstIndex(where: { $0.id == id }) {
            currentIndex = idx
            currentTrack = activeQueue[idx]
            duration = activeQueue[idx].duration
            NowPlayingManager.shared.updateMetadata(for: activeQueue[idx], duration: duration)
            Task {
                await loadLyrics(for: activeQueue[idx], generation: resolveGeneration)
            }
        }
    }

    private static var stateFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kumone", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("player-state.json")
    }
}
#endif
