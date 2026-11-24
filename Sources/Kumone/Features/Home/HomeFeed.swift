import Foundation

/// 首页「推荐」的九个板块。
///
/// 板块来自 `/homepage/block/page`，标题与顺序照服务端；这里只做一件事——
/// 把服务端给的 block 归纳成固定顺序的板块，并剔除「根据你听过的热门节目推荐」
/// （本项目不展示电台节目板块）。
enum HomeFeedSlot: String, CaseIterable {
    case recommendedPlaylists      // 推荐歌单
    case recentlyTrending          // 近期云村热播
    case tailoredRecommendation    // 根据…为你推荐
    case charts                    // 排行榜
    case personalPlaylists         // …的歌单
    case radarPlaylists            // 雷达歌单
    case regionalHits              // 最近的热门歌曲
    case likedSongRoaming          // 从你喜欢的歌开始漫游
    case likedSongRecommendations  // 根据你喜爱的歌曲推荐
}

enum HomeSupplement: String {
    case daily, privateFM, heartbeat, newAlbums, topArtists

    static let shortcuts: [Self] = [.daily, .privateFM, .heartbeat]
    static let shelves: [Self] = [.newAlbums, .topArtists]

    var title: String {
        switch self {
        case .daily: return String(localized: "每日推荐")
        case .privateFM: return String(localized: "私人漫游")
        case .heartbeat: return String(localized: "心动模式")
        case .newAlbums: return String(localized: "新碟上架")
        case .topArtists: return String(localized: "推荐歌手")
        }
    }
}

struct HomeFeedPlaylist: Identifiable, Hashable {
    let id: Int
    let name: String
    let coverURL: String?
    let playCount: Int
    let subtitle: String?
}

extension HomeFeedPlaylist {
    init(_ summary: PlaylistSummary) {
        self.init(id: summary.id,
                  name: summary.name,
                  coverURL: summary.coverURL,
                  playCount: summary.playCount,
                  subtitle: summary.copywriter)
    }

    init(_ toplist: ToplistItem) {
        self.init(id: toplist.id,
                  name: toplist.name,
                  coverURL: toplist.coverImgUrl,
                  playCount: toplist.playCount,
                  subtitle: toplist.updateFrequency)
    }

    init(_ radar: HomeViewModel.RadarPlaylist) {
        self.init(id: radar.id,
                  name: radar.title,
                  coverURL: radar.coverURL,
                  playCount: 0,
                  subtitle: radar.subtitle)
    }
}

struct HomeFeedSection: Identifiable {
    enum Content {
        case playlists([HomeFeedPlaylist])
        case songs([Track])
    }

    let slot: HomeFeedSlot
    let title: String
    let content: Content

    var id: String { slot.rawValue }

    var playlists: [HomeFeedPlaylist] {
        if case .playlists(let value) = content { return value }
        return []
    }

    var songs: [Track] {
        if case .songs(let value) = content { return value }
        return []
    }
}

enum HomeFeed {
    static let hiddenSectionsKey = "homeHiddenSections"

    /// 服务端的 block → 固定顺序的板块列表。同类板块只取第一个 block（与参考实现一致）。
    static func sections(from blocks: [MusicAPI.HomePageResponse.Block]) -> [HomeFeedSection] {
        var bySlot: [HomeFeedSlot: HomeFeedSection] = [:]
        for block in blocks {
            guard let slot = slot(for: block), bySlot[slot] == nil else { continue }
            var songIDs = Set<Int>()
            var playlistIDs = Set<Int>()
            let songs = block.resources.compactMap(\.song).filter { songIDs.insert($0.id).inserted }
            let playlists = block.resources.compactMap(playlist(from:)).filter { playlistIDs.insert($0.id).inserted }
            let content: HomeFeedSection.Content
            if !songs.isEmpty {
                content = .songs(songs)
            } else if !playlists.isEmpty {
                content = .playlists(playlists)
            } else {
                continue
            }
            bySlot[slot] = HomeFeedSection(slot: slot,
                                           title: block.title ?? defaultTitle(for: slot),
                                           content: content)
        }
        return HomeFeedSlot.allCases.compactMap { bySlot[$0] }
    }

    private static func playlist(from resource: MusicAPI.HomePageResponse.Creative.Resource) -> HomeFeedPlaylist? {
        let type = (resource.resourceType ?? "").lowercased()
        guard type == "list" || type == "playlist", resource.id > 0 else { return nil }
        let name = resource.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return HomeFeedPlaylist(
            id: resource.id,
            name: (name?.isEmpty == false ? name : nil) ?? String(localized: "歌单"),
            coverURL: resource.coverURL,
            playCount: resource.resourceExtInfo?.playCount ?? 0,
            subtitle: resource.subtitle
        )
    }

    /// block 与板块的对应关系：先按 blockCode，再按标题。
    private static func slot(for block: MusicAPI.HomePageResponse.Block) -> HomeFeedSlot? {
        let code = (block.blockCode ?? "").uppercased()
        let title = block.title ?? ""

        // 电台板块：本项目不展示。
        if code.contains("VOICELIST") || title.contains("热门节目推荐") { return nil }

        if code == "HOMEPAGE_BLOCK_PLAYLIST_RCMD" || title == "推荐歌单" { return .recommendedPlaylists }
        if title.contains("近期云村热播") || code == "HOMEPAGE_BLOCK_STYLE_RCMD" { return .recentlyTrending }
        if title.hasPrefix("根据") && title.hasSuffix("为你推荐") { return .tailoredRecommendation }
        if code.contains("TOPLIST") || code.contains("RANK") || title == "排行榜" { return .charts }
        if code == "HOMEPAGE_BLOCK_MGC_PLAYLIST" || title.contains("雷达歌单") { return .radarPlaylists }
        if title.contains("最近的热门歌曲") { return .regionalHits }
        if title.contains("从你喜欢的歌开始漫游") { return .likedSongRoaming }
        if title.contains("根据你喜爱的歌曲推荐") { return .likedSongRecommendations }
        if title.hasSuffix("的歌单") { return .personalPlaylists }
        return nil
    }

    static func defaultTitle(for slot: HomeFeedSlot) -> String {
        switch slot {
        case .recommendedPlaylists: return String(localized: "推荐歌单")
        case .recentlyTrending: return String(localized: "近期云村热播")
        case .tailoredRecommendation: return String(localized: "根据你的口味为你推荐")
        case .charts: return String(localized: "排行榜")
        case .personalPlaylists: return String(localized: "你的歌单")
        case .radarPlaylists: return String(localized: "雷达歌单")
        case .regionalHits: return String(localized: "最近的热门歌曲")
        case .likedSongRoaming: return String(localized: "从你喜欢的歌开始漫游")
        case .likedSongRecommendations: return String(localized: "根据你喜爱的歌曲推荐")
        }
    }
}

// MARK: - 补齐

/// 服务端没下发的板块用本地已经拿得到的数据补上，
/// 保证首页始终是同一套九个板块（参考实现的板块集合）。
struct HomeFeedFallbacks {
    var recommendedPlaylists: [HomeFeedPlaylist] = []
    var charts: [HomeFeedPlaylist] = []
    var radarPlaylists: [HomeFeedPlaylist] = []
    var personalPlaylists: [HomeFeedPlaylist] = []
    var recentlyTrending: [Track] = []
    var regionalHits: [Track] = []
    var tailored: [Track] = []
    var roaming: [Track] = []
    var similar: [Track] = []
}

extension HomeFeed {
    static func filling(_ sections: [HomeFeedSection],
                        with fallbacks: HomeFeedFallbacks) -> [HomeFeedSection] {
        var present = Set(sections.map(\.slot))
        var result = sections

        func add(_ slot: HomeFeedSlot, playlists: [HomeFeedPlaylist]) {
            guard !present.contains(slot), !playlists.isEmpty else { return }
            present.insert(slot)
            result.append(HomeFeedSection(slot: slot,
                                          title: defaultTitle(for: slot),
                                          content: .playlists(playlists)))
        }
        func add(_ slot: HomeFeedSlot, songs: [Track]) {
            guard !present.contains(slot), !songs.isEmpty else { return }
            present.insert(slot)
            result.append(HomeFeedSection(slot: slot,
                                          title: defaultTitle(for: slot),
                                          content: .songs(songs)))
        }

        add(.recommendedPlaylists, playlists: fallbacks.recommendedPlaylists)
        add(.recentlyTrending, songs: fallbacks.recentlyTrending)
        add(.tailoredRecommendation, songs: fallbacks.tailored)
        add(.charts, playlists: fallbacks.charts)
        add(.personalPlaylists, playlists: fallbacks.personalPlaylists)
        add(.radarPlaylists, playlists: fallbacks.radarPlaylists)
        add(.regionalHits, songs: fallbacks.regionalHits)
        add(.likedSongRoaming, songs: fallbacks.roaming)
        add(.likedSongRecommendations, songs: fallbacks.similar)

        return HomeFeedSlot.allCases.compactMap { slot in result.first { $0.slot == slot } }
    }
}
