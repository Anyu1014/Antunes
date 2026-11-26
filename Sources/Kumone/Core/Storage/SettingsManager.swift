import SwiftUI

/// 音质档位。
enum AudioQuality: String, CaseIterable, Identifiable {
    case standard
    case higher
    case exhigh
    case lossless
    case hires

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return String(localized: "标准")
        case .higher: return String(localized: "较高")
        case .exhigh: return String(localized: "极高")
        case .lossless: return String(localized: "无损")
        case .hires: return "Hi-Res"
        }
    }

    var badge: String {
        switch self {
        case .standard: return String(localized: "标准")
        case .higher, .exhigh: return String(localized: "极高")
        case .lossless: return String(localized: "无损")
        case .hires: return String(localized: "高解析")
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case auto, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return String(localized: "跟随系统")
        case .light: return String(localized: "浅色")
        case .dark: return String(localized: "深色")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// What to show above Japanese lyrics.
enum LyricsAnnotation: String, CaseIterable, Identifiable {
    case off
    case romaji
    case furigana

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return String(localized: "关闭")
        case .romaji: return String(localized: "罗马音")
        case .furigana: return String(localized: "汉字读音")
        }
    }
}

public enum NowPlayingMode: String, CaseIterable, Identifiable {
    case vinyl
    case classic
    case immersive
    case minimal

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .vinyl: return String(localized: "黑胶模式")
        case .classic: return String(localized: "经典模式")
        case .immersive: return String(localized: "沉浸模式")
        case .minimal: return String(localized: "简洁模式")
        }
    }
}

/// Layout used by the full-width now-playing page — iPhone landscape and
/// iPad — where `NowPlayingMode`'s compact layouts no longer apply. Kept
/// separate so a phone in portrait can stay on 黑胶 while landscape opens on
/// a lyrics-first page.
public enum LandscapeNowPlayingStyle: String, CaseIterable, Identifiable {
    /// Artwork and transport on the left, lyrics on the right (the original
    /// full-width page).
    case classic
    /// Lyrics fill the page, with a small header and a floating transport
    /// capsule at the bottom.
    case immersive

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .classic: return String(localized: "经典双栏")
        case .immersive: return String(localized: "沉浸歌词")
        }
    }
}

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    /// Internal rather than private: `AudioCache` reads its own limit straight
    /// from `UserDefaults` before any settings object exists, and must spell
    /// the key the same way.
    enum Keys {
        static let quality = "settings.audioQuality"
        static let downloadQuality = "settings.downloadQuality"
        /// One-time marker: 1.1 split play/download quality and defaults both to
        /// lossless, so the old untouched `exhigh` default is not carried over.
        static let qualitySplit = "settings.qualitySplitToLossless"
        static let appearance = "settings.appearance"
        static let showHome = "settings.showHome"
        static let showFM = "settings.showFM"
        static let showLibrary = "settings.showLibrary"
        static let showExplore = "settings.showExplore"
        static let showSearch = "settings.showSearch"
        static let showLikedInCreated = "settings.showLikedInCreatedPlaylists"
        static let searchOffMigrated = "settings.searchOffMigrated"
        static let showLikedInCreatedMigrated = "settings.showLikedInCreatedMigrated"
        static let nowPlayingMode = "settings.nowPlayingMode"
        static let landscapeNowPlayingStyle = "settings.landscapeNowPlayingStyle"
        static let openAlbumOnArtworkClick = "settings.openAlbumOnArtworkClick"
        static let showTranslation = "settings.showLyricsTranslation"
        static let showRomaji = "settings.showLyricsRomaji"  // migrated to `annotation`
        static let annotation = "settings.lyricsAnnotation"
        static let verbatimLyrics = "settings.verbatimLyrics"
        static let volume = "settings.volume"
        static let fmMode = "settings.fmMode"
        static let desktopLyrics = "settings.showDesktopLyrics"
        #if os(macOS)
        static let unblock = "settings.enableUnblock"
        static let unblockSources = "settings.enabledUnblockSources"
        static let menuBarPlayer = "settings.showMenuBarPlayer"
        static let automix = "settings.automixEnabled"
        static let automixTransitions = "settings.automixTransitions"
        static let automixOrder = "settings.automixOrder"
        static let automixStems = "settings.automixStems"
        static let loudnessCompensation = "settings.loudnessCompensation"
        static let audioCacheLimit = "settings.audioCacheLimit"
        static let outputDevice = "settings.outputDeviceUID"
        #endif
        static let desktopLyricsCentered = "settings.desktopLyricsCentered"
        static let mainWindowAmbientBackground = "settings.showMainWindowAmbientBackground"
        static let mainWindowAmbientBackgroundOffMigrated = "settings.mainWindowAmbientBackgroundOffMigrated"
        static let mainWindowAmbientBackgroundIntensity = "settings.mainWindowAmbientBackgroundIntensity"
        static let enableAudioCache = "settings.enableAudioCache"
        static let audioCacheSizeMB = "settings.audioCacheSizeMB"
        static let audioCacheAutomatic = "settings.audioCacheAutomatic"
        #if os(iOS)
        static let customProfileBios = "settings.customProfileBios"
        static let soundEffectPreset = "settings.soundEffectPreset"
        static let customEqualizerGains = "settings.customEqualizerGains"
        #endif
    }

    /// Quality used when streaming.
    @Published var audioQuality: AudioQuality {
        didSet { UserDefaults.standard.set(audioQuality.rawValue, forKey: Keys.quality) }
    }

    /// Quality used when saving a track. Independent of playback: a lossless
    /// archive is worth the space even when streaming at a lower level.
    @Published var downloadQuality: AudioQuality {
        didSet { UserDefaults.standard.set(downloadQuality.rawValue, forKey: Keys.downloadQuality) }
    }

    static let audioCacheSizeRangeMB = 100...10_000
    static let audioCacheSizeStepMB = 100

    /// Use locally stored audio files before resolving a remote source and
    /// retain completed remote playback for future requests.
    @Published var enableAudioCache: Bool {
        didSet { UserDefaults.standard.set(enableAudioCache, forKey: Keys.enableAudioCache) }
    }

    /// Size the song cache from the device's free space instead of
    /// `audioCacheSizeMB`; see `AutomaticCacheLimit`.
    @Published var audioCacheAutomatic: Bool {
        didSet { UserDefaults.standard.set(audioCacheAutomatic, forKey: Keys.audioCacheAutomatic) }
    }

    static func normalizedAudioCacheSizeMB(_ value: Int) -> Int {
        let boundedValue = min(
            max(value, audioCacheSizeRangeMB.lowerBound),
            audioCacheSizeRangeMB.upperBound
        )
        let distanceFromLowerBound = boundedValue - audioCacheSizeRangeMB.lowerBound
        return audioCacheSizeRangeMB.lowerBound
            + Int((Double(distanceFromLowerBound) / Double(audioCacheSizeStepMB)).rounded())
                * audioCacheSizeStepMB
    }

    @Published var audioCacheSizeMB: Int {
        didSet {
            let normalizedValue = Self.normalizedAudioCacheSizeMB(audioCacheSizeMB)
            guard normalizedValue == audioCacheSizeMB else {
                audioCacheSizeMB = normalizedValue
                return
            }
            UserDefaults.standard.set(audioCacheSizeMB, forKey: Keys.audioCacheSizeMB)
        }
    }

    @Published var showHome: Bool {
        didSet { UserDefaults.standard.set(showHome, forKey: Keys.showHome) }
    }

    @Published var showExplore: Bool {
        didSet { UserDefaults.standard.set(showExplore, forKey: Keys.showExplore) }
    }

    @Published var showSearch: Bool {
        didSet { UserDefaults.standard.set(showSearch, forKey: Keys.showSearch) }
    }

    /// 漫游板块。和其他板块一样可以在设置里关掉；全关时底栏退回「我的」。
    @Published var showFM: Bool {
        didSet { UserDefaults.standard.set(showFM, forKey: Keys.showFM) }
    }

    @Published var showLibrary: Bool {
        didSet { UserDefaults.standard.set(showLibrary, forKey: Keys.showLibrary) }
    }

    /// 「我喜欢的音乐」是否也算进「创建的歌单」（默认不算，与安卓端一致）。
    @Published var showLikedInCreated: Bool {
        didSet { UserDefaults.standard.set(showLikedInCreated, forKey: Keys.showLikedInCreated) }
    }

    var homeSectionVisibility: [Bool] { [showHome, showExplore, showFM, showSearch, showLibrary] }
    var onlyLibrarySection: Bool { !homeSectionVisibility.contains(true) }
    /// 其它四个板块是否全关。「我的」只有在它们全关时才允许关闭。
    var otherSectionsAllOff: Bool { !showHome && !showExplore && !showFM && !showSearch }
    var anySectionEnabled: Bool { showHome || showExplore || showFM || showSearch || showLibrary }

    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    #if os(iOS)
    // iOS 只保留沉浸布局，旧模式键会在启动时清除。
    let nowPlayingMode: NowPlayingMode = .immersive
    let landscapeNowPlayingStyle: LandscapeNowPlayingStyle = .immersive
    #else
    @Published var nowPlayingMode: NowPlayingMode {
        didSet { UserDefaults.standard.set(nowPlayingMode.rawValue, forKey: Keys.nowPlayingMode) }
    }

    @Published var landscapeNowPlayingStyle: LandscapeNowPlayingStyle {
        didSet {
            UserDefaults.standard.set(
                landscapeNowPlayingStyle.rawValue, forKey: Keys.landscapeNowPlayingStyle
            )
        }
    }

    #endif

    @Published var openAlbumOnArtworkClick: Bool {
        didSet { UserDefaults.standard.set(openAlbumOnArtworkClick, forKey: Keys.openAlbumOnArtworkClick) }
    }

    @Published var showLyricsTranslation: Bool {
        didSet { UserDefaults.standard.set(showLyricsTranslation, forKey: Keys.showTranslation) }
    }

    /// Check for updates on launch. When off, no update sheet appears
    /// automatically; the user can still check manually (#42).
    /// Reading shown for Japanese lyrics: a romaji line above, furigana over
    /// the kanji, or nothing.
    @Published var lyricsAnnotation: LyricsAnnotation {
        didSet { UserDefaults.standard.set(lyricsAnnotation.rawValue, forKey: Keys.annotation) }
    }

    /// Karaoke-style word-by-word highlighting: the service's own timing when the
    /// song has verbatim (yrc) lyrics, else the line's time spread across its
    /// characters.
    @Published var verbatimLyrics: Bool {
        didSet { UserDefaults.standard.set(verbatimLyrics, forKey: Keys.verbatimLyrics) }
    }

    #if os(macOS)
    /// Resolve gray tracks from third-party sources (unblock-style).
    @Published var enableUnblock: Bool {
        didSet { UserDefaults.standard.set(enableUnblock, forKey: Keys.unblock) }
    }

    /// Built-in third-party sources eligible for gray-track resolution.
    @Published var enabledAudioSourceIDs: Set<AudioSourceID> {
        didSet {
            UserDefaults.standard.set(
                enabledAudioSourceIDs.map(\.rawValue).sorted(),
                forKey: Keys.unblockSources
            )
        }
    }

    var canResolveUnblockedTracks: Bool {
        enableUnblock && !enabledAudioSourceIDs.isEmpty
    }
    #else
    var canResolveUnblockedTracks: Bool { false }
    #endif

    /// Floating desktop lyrics window (LyricsX-style).
    @Published var showDesktopLyrics: Bool {
        didSet { UserDefaults.standard.set(showDesktopLyrics, forKey: Keys.desktopLyrics) }
    }
    #if os(macOS)

    /// The AutoMix master switch. Off means no per-track analysis at all, and
    /// every sub-setting below is inert. Opt-in: AutoMix costs CPU (analysis),
    /// sometimes network (the order's candidates) and sometimes GPU (stems),
    /// so it does not turn itself on. macOS-only for now (spec §7).
    @Published var automixEnabled: Bool {
        didSet { UserDefaults.standard.set(automixEnabled, forKey: Keys.automix) }
    }

    /// Beat-matched / crossfaded hand-overs between queue tracks. Off still
    /// gives gapless playback, and off is *only* a statement about the seam:
    /// analysis still runs when another sub-setting below wants it.
    @Published var automixTransitionsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(automixTransitionsEnabled,
                                      forKey: Keys.automixTransitions)
        }
    }

    /// The `.autoMix` queue order — reorder the queue by how well the seams
    /// come out. It scores candidates, which means downloading tracks the
    /// listener has not asked for yet, so it is off by default even under an
    /// AutoMix that is on.
    @Published var automixOrderEnabled: Bool {
        didSet { UserDefaults.standard.set(automixOrderEnabled, forKey: Keys.automixOrder) }
    }

    /// Let a hand-over separate stems on the GPU. Real money in heat and
    /// battery, and it needs a model on disk, so it is opt-in on top of
    /// opt-in; without it every gesture plays its whole-mix form.
    @Published var automixStemsEnabled: Bool {
        didSet { UserDefaults.standard.set(automixStemsEnabled, forKey: Keys.automixStems) }
    }

    /// Even out mastering loudness differences between songs, so the next
    /// track does not arrive several dB louder. Needs AutoMix's per-track
    /// analysis, so it is inert while AutoMix is off.
    @Published var loudnessCompensationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(loudnessCompensationEnabled,
                                      forKey: Keys.loudnessCompensation)
        }
    }

    /// Audio cache LRU limit in bytes; 0 = unlimited. AudioCache reads the
    /// same defaults key at startup and receives changes from here.
    @Published var audioCacheLimit: Int64 {
        didSet {
            UserDefaults.standard.set(audioCacheLimit, forKey: Keys.audioCacheLimit)
            Task { await EngineAudioCache.shared.setLimitBytes(audioCacheLimit) }
        }
    }

    /// CoreAudio UID of the chosen output device; "" follows the system
    /// default. UID rather than the numeric AudioDeviceID, which is not
    /// stable across launches. Written by `AudioOutputController`.
    @Published var outputDeviceUID: String {
        didSet { UserDefaults.standard.set(outputDeviceUID, forKey: Keys.outputDevice) }
    }
    #endif

    /// Lock the desktop-lyrics capsule to the horizontal centre of the screen
    /// instead of the free-drag position (#48).
    @Published var desktopLyricsCentered: Bool {
        didSet { UserDefaults.standard.set(desktopLyricsCentered, forKey: Keys.desktopLyricsCentered) }
    }

    static let mainWindowAmbientBackgroundIntensityRange = 0.5...1.5

    #if os(macOS)
    /// Default song-cache ceiling, shared with `AudioCache` so the two cannot
    /// disagree about what "unset" means.
    nonisolated static let defaultAudioCacheLimit: Int64 = 2_147_483_648  // 2 GB
    #endif

    /// Artwork-tinted overlay on the main app interface.
    @Published var showMainWindowAmbientBackground: Bool {
        didSet {
            UserDefaults.standard.set(
                showMainWindowAmbientBackground,
                forKey: Keys.mainWindowAmbientBackground
            )
        }
    }

    /// Multiplier applied to the main interface's artwork tint.
    @Published var mainWindowAmbientBackgroundIntensity: Double {
        didSet {
            UserDefaults.standard.set(
                mainWindowAmbientBackgroundIntensity,
                forKey: Keys.mainWindowAmbientBackgroundIntensity
            )
        }
    }

    #if os(iOS)
    @Published private var customProfileBios: [String: String] {
        didSet { UserDefaults.standard.set(customProfileBios, forKey: Keys.customProfileBios) }
    }

    func customProfileBio(for userID: Int) -> String {
        customProfileBios[String(userID)] ?? ""
    }

    func setCustomProfileBio(_ bio: String, for userID: Int) {
        let key = String(userID)
        let custom = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        if custom.isEmpty {
            customProfileBios.removeValue(forKey: key)
        } else {
            customProfileBios[key] = custom
        }
    }

    func displayedProfileBio(for profile: UserProfile) -> String? {
        let custom = customProfileBio(for: profile.userId)
        return custom.isEmpty ? profile.signature : custom
    }

    @Published var soundEffectPreset: SoundEffectPreset {
        didSet {
            UserDefaults.standard.set(soundEffectPreset.rawValue, forKey: Keys.soundEffectPreset)
            publishSoundEffectParameters()
        }
    }

    @Published private(set) var customEqualizerGains: [Float] {
        didSet {
            let normalized = EqualizerConfiguration(gains: customEqualizerGains).gains
            guard normalized == customEqualizerGains else {
                customEqualizerGains = normalized
                return
            }
            UserDefaults.standard.set(
                normalized.map(Double.init), forKey: Keys.customEqualizerGains)
            if soundEffectPreset == .custom { publishSoundEffectParameters() }
        }
    }

    var customEqualizerConfiguration: EqualizerConfiguration {
        EqualizerConfiguration(gains: customEqualizerGains)
    }

    var isCustomEqualizerEnabled: Bool {
        soundEffectPreset == .custom
    }

    func selectSoundEffect(_ preset: SoundEffectPreset) {
        soundEffectPreset = preset
    }

    func setCustomEqualizerEnabled(_ isEnabled: Bool) {
        if isEnabled {
            soundEffectPreset = .custom
        } else if soundEffectPreset == .custom {
            soundEffectPreset = .original
        }
    }

    func updateCustomEqualizerGain(at index: Int, to value: Float) {
        guard customEqualizerGains.indices.contains(index) else { return }
        var gains = customEqualizerGains
        gains[index] = min(
            max(value, EqualizerConfiguration.gainRange.lowerBound),
            EqualizerConfiguration.gainRange.upperBound)
        customEqualizerGains = gains
        if soundEffectPreset != .custom { soundEffectPreset = .custom }
    }

    func resetCustomEqualizer() {
        customEqualizerGains = EqualizerConfiguration.flat.gains
        if soundEffectPreset != .custom { soundEffectPreset = .custom }
    }

    private func publishSoundEffectParameters() {
        SoundEffectParameterStore.publish(SoundEffectParameters(
            preset: soundEffectPreset,
            custom: customEqualizerConfiguration))
    }
    #endif

    private init() {
        let defaults = UserDefaults.standard
        audioQuality = .exhigh
        downloadQuality = .exhigh
        enableAudioCache = defaults.object(forKey: Keys.enableAudioCache) as? Bool ?? true
        // A size somebody chose stays chosen; the untouched default becomes automatic.
        audioCacheAutomatic = defaults.object(forKey: Keys.audioCacheAutomatic) as? Bool
            ?? (defaults.object(forKey: Keys.audioCacheSizeMB) as? Int).map { $0 == AudioCache.defaultMaximumSizeMB } ?? true
        let storedAudioCacheSizeMB = defaults.object(forKey: Keys.audioCacheSizeMB) as? Int
            ?? AudioCache.defaultMaximumSizeMB
        let normalizedAudioCacheSizeMB = Self.normalizedAudioCacheSizeMB(storedAudioCacheSizeMB)
        audioCacheSizeMB = normalizedAudioCacheSizeMB
        defaults.set(normalizedAudioCacheSizeMB, forKey: Keys.audioCacheSizeMB)
        // 先读到局部变量再赋值：`init` 里所有存储属性初始化完成之前不能读 self。
        let vHome = defaults.object(forKey: Keys.showHome) as? Bool ?? true
        let vFM = defaults.object(forKey: Keys.showFM) as? Bool ?? true
        let vLibrary = defaults.object(forKey: Keys.showLibrary) as? Bool ?? true
        let vExplore = defaults.object(forKey: Keys.showExplore) as? Bool ?? false
        showHome = vHome
        showFM = vFM
        showLibrary = vLibrary
        showExplore = vExplore
        // 搜索板块默认关闭：老版本默认是开且从未写过这个键，迁移一次；
        // 用户此前手动开过的（键已存在）保持不动。
        if defaults.object(forKey: Keys.searchOffMigrated) == nil {
            defaults.set(false, forKey: Keys.showSearch)
            defaults.set(true, forKey: Keys.searchOffMigrated)
        }
        let vSearch = defaults.object(forKey: Keys.showSearch) as? Bool ?? false
        showSearch = vSearch
        // 「我的」是兜底板块：只要还有别的板块开着，它就必须是开的（老数据里可能存成非法组合）。
        if !vLibrary && (vHome || vExplore || vFM || vSearch) { showLibrary = true }
        if defaults.object(forKey: Keys.showLikedInCreatedMigrated) == nil {
            defaults.set(false, forKey: Keys.showLikedInCreated)
            defaults.set(true, forKey: Keys.showLikedInCreatedMigrated)
        }
        showLikedInCreated = defaults.object(forKey: Keys.showLikedInCreated) as? Bool ?? false
        appearance = defaults.string(forKey: Keys.appearance).flatMap(AppAppearance.init) ?? .auto
        #if os(macOS)
        nowPlayingMode = defaults.string(forKey: Keys.nowPlayingMode).flatMap(NowPlayingMode.init) ?? .immersive
        landscapeNowPlayingStyle = defaults.string(forKey: Keys.landscapeNowPlayingStyle)
            .flatMap(LandscapeNowPlayingStyle.init) ?? .classic
        #else
        // 删除旧键本身就是一次性迁移：不存在时不写入。
        for key in [Keys.nowPlayingMode, Keys.landscapeNowPlayingStyle] where defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
        }
        #endif
        openAlbumOnArtworkClick = defaults.object(forKey: Keys.openAlbumOnArtworkClick) as? Bool ?? true
        showLyricsTranslation = defaults.object(forKey: Keys.showTranslation) as? Bool ?? true
        // Carry over the old on/off romaji toggle for anyone who had it on.
        lyricsAnnotation = defaults.string(forKey: Keys.annotation).flatMap(LyricsAnnotation.init)
            ?? (defaults.bool(forKey: Keys.showRomaji) ? .romaji : .off)
        verbatimLyrics = defaults.object(forKey: Keys.verbatimLyrics) as? Bool ?? true
        #if os(macOS)
        enableUnblock = defaults.object(forKey: Keys.unblock) as? Bool ?? true
        if let rawSourceIDs = defaults.stringArray(forKey: Keys.unblockSources) {
            enabledAudioSourceIDs = Set(rawSourceIDs.compactMap(AudioSourceID.init))
        } else {
            enabledAudioSourceIDs = Set(AudioSourceID.allCases)
        }
        #endif
        showDesktopLyrics = defaults.object(forKey: Keys.desktopLyrics) as? Bool ?? false
        #if os(macOS)
        automixEnabled = defaults.object(forKey: Keys.automix) as? Bool ?? false
        automixTransitionsEnabled =
            defaults.object(forKey: Keys.automixTransitions) as? Bool ?? true
        automixOrderEnabled = defaults.object(forKey: Keys.automixOrder) as? Bool ?? false
        automixStemsEnabled = defaults.object(forKey: Keys.automixStems) as? Bool ?? false
        loudnessCompensationEnabled =
            defaults.object(forKey: Keys.loudnessCompensation) as? Bool ?? true
        audioCacheLimit = (defaults.object(forKey: Keys.audioCacheLimit) as? Int64)
            ?? Self.defaultAudioCacheLimit
        outputDeviceUID = defaults.string(forKey: Keys.outputDevice) ?? ""
        #endif
        desktopLyricsCentered = defaults.object(forKey: Keys.desktopLyricsCentered) as? Bool ?? false
        // 主界面环境色默认关闭；老版本默认开启，这里做一次迁移把它关掉。
        if defaults.object(forKey: Keys.mainWindowAmbientBackgroundOffMigrated) == nil {
            defaults.set(false, forKey: Keys.mainWindowAmbientBackground)
            defaults.set(true, forKey: Keys.mainWindowAmbientBackgroundOffMigrated)
        }
        showMainWindowAmbientBackground = defaults.object(
            forKey: Keys.mainWindowAmbientBackground
        ) as? Bool ?? false
        let storedAmbientBackgroundIntensity = defaults.object(
            forKey: Keys.mainWindowAmbientBackgroundIntensity
        ) as? Double ?? 1
        mainWindowAmbientBackgroundIntensity = min(
            max(storedAmbientBackgroundIntensity, Self.mainWindowAmbientBackgroundIntensityRange.lowerBound),
            Self.mainWindowAmbientBackgroundIntensityRange.upperBound
        )
        #if os(iOS)
        customProfileBios = defaults.dictionary(forKey: Keys.customProfileBios) as? [String: String] ?? [:]
        soundEffectPreset = SoundEffectPreferences.preset(
            from: defaults, key: Keys.soundEffectPreset)
        customEqualizerGains = SoundEffectPreferences.customConfiguration(
            from: defaults, key: Keys.customEqualizerGains).gains
        publishSoundEffectParameters()
        #endif
    }
}
