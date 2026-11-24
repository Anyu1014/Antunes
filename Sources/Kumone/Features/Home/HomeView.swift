import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    /// Shared so the loaded page survives sidebar switches (no skeleton flash).
    static let shared = HomeViewModel()

    enum State {
        case idle, loading, loaded
        case error(String)
    }

    /// The personalized radar family — global playlist IDs whose content is
    /// generated per logged-in account (same list YesPlayMusic special-cases).
    static let radarPlaylistIDs = [
        3_136_952_023, // 私人雷达
        2_829_883_282, // 华语私人雷达
        2_829_816_518, // 欧美私人雷达
        2_829_896_389, // 日系私人雷达
    ]

    struct RadarPlaylist: Identifiable, Hashable {
        let id: Int
        let title: String
        let subtitle: String?
        let coverURL: String?
    }

    @Published var state: State = .idle
    /// 服务端 `/homepage/block/page` 归纳出的板块（推荐歌单 / 近期云村热播 / 排行榜 …）。
    /// 拿不到时为空，页面退回下面那套本地拼出来的板块。
    @Published var sections: [HomeFeedSection] = []
    @Published var recommendPlaylists: [PlaylistSummary] = []
    @Published var radarPlaylists: [RadarPlaylist] = []
    @Published var toplists: [ToplistItem] = []
    @Published var newAlbums: [AlbumSummary] = []
    @Published var topArtists: [ArtistSummary] = []
    @Published var dailyFirstCover: String?

    private(set) var loadedAccountID: Int?
    private var loadGeneration = 0
    private var didFinishLoad = false

    func load(accountID: Int?, force: Bool = false) async {
        guard !Task.isCancelled, accountID == AccountStore.shared.authenticatedAccountID else { return }
        if !force, loadedAccountID == accountID, didFinishLoad { return }
        didFinishLoad = false
        loadGeneration += 1
        let generation = loadGeneration
        if loadedAccountID != accountID {
            state = .loading
            recommendPlaylists = []
            radarPlaylists = []
            toplists = []
            newAlbums = []
            topArtists = []
            sections = []
            dailyFirstCover = nil
        }
        loadedAccountID = accountID
        if case .loaded = state {} else { state = .loading }
        func isCurrent() -> Bool {
            generation == loadGeneration && accountID == AccountStore.shared.authenticatedAccountID
                && !Task.isCancelled
        }

        async let blocksTask = try? MusicAPI.homepageBlocks()
        async let albumsTask = try? MusicAPI.newAlbums(limit: 20)
        async let artistsTask = try? MusicAPI.topArtists()
        async let dailyTask = accountID == nil ? nil : (try? await MusicAPI.dailyRecommendSongs())?.first?.album.picUrl

        let primary = HomeFeed.sections(from: await blocksTask ?? [])
        guard isCurrent() else { return }
        if !primary.isEmpty {
            sections = primary
            state = .loaded
        }

        let missing = Set(HomeFeedSlot.allCases).subtracting(primary.map(\.slot))
        async let playlistsTask = missing.contains(.recommendedPlaylists)
            ? await fetchRecommendPlaylists(loggedIn: accountID != nil) : []
        async let toplistsTask = missing.contains(.charts) ? (try? await MusicAPI.toplists()) : nil
        async let topSongsTask = missing.contains(.recentlyTrending) || missing.contains(.regionalHits)
            ? (try? await MusicAPI.hotChartSongs(limit: 24)) : nil
        async let tailoredTask = missing.contains(.tailoredRecommendation)
            ? (try? await MusicAPI.personalizedNewSongs(limit: 12)) : nil
        async let roamingTask = accountID != nil && missing.contains(.likedSongRoaming)
            ? (try? await MusicAPI.personalFM()) : nil
        async let mineTask = missing.contains(.personalPlaylists)
            ? await fetchOwnedPlaylists(uid: accountID) : []
        async let radarTask = missing.contains(.radarPlaylists) ? await fetchRadarPlaylists() : []
        async let similarTask = accountID != nil && missing.contains(.likedSongRecommendations)
            ? await fetchSimilarSongs() : []
        let (playlists, lists, albums, artists, topSongs, tailored, roaming, mine, radar, similar) =
            await (playlistsTask, toplistsTask, albumsTask, artistsTask,
                   topSongsTask, tailoredTask, roamingTask, mineTask, radarTask, similarTask)
        guard isCurrent() else { return }

        recommendPlaylists = playlists
        let hot = topSongs ?? []
        let fallbacks = HomeFeedFallbacks(
            recommendedPlaylists: playlists.prefix(12).map(HomeFeedPlaylist.init),
            charts: (lists ?? []).filter {
                Self.featuredToplistIDs.contains($0.id)
            }.prefix(12).map(HomeFeedPlaylist.init),
            radarPlaylists: radar.map(HomeFeedPlaylist.init),
            personalPlaylists: mine.prefix(12).map(HomeFeedPlaylist.init),
            recentlyTrending: Array(hot.prefix(12)),
            regionalHits: Array(hot.dropFirst(12).prefix(12)),
            tailored: tailored ?? [],
            roaming: roaming ?? [],
            similar: Array(similar.prefix(12))
        )
        sections = HomeFeed.filling(primary, with: fallbacks)
        toplists = (lists ?? []).filter { Self.featuredToplistIDs.contains($0.id) }
        newAlbums = albums ?? []
        topArtists = Array((artists ?? []).shuffled().prefix(6))
        radarPlaylists = radar
        state = playlists.isEmpty && newAlbums.isEmpty && sections.isEmpty
            ? .error(String(localized: "网络连接失败")) : .loaded
        let dailyCover = await dailyTask
        if isCurrent() {
            dailyFirstCover = dailyCover
            if case .loaded = state { didFinishLoad = true }
        }
    }

    /// 官方榜里挑出来放在首页的那几个。
    static let featuredToplistIDs: Set<Int> = [19_723_756, 3_779_629, 2_884_035, 3_778_678, 60198]

    /// 「根据你喜爱的歌曲推荐」的兜底：拿喜欢的歌当种子走心动模式。
    private func fetchSimilarSongs() async -> [Track] {
        guard let liked = AccountStore.shared.likedSongsPlaylist,
              let seed = AccountStore.shared.likedTrackIDs.first else { return [] }
        return (try? await MusicAPI.intelligenceList(songID: seed, playlistID: liked.id)) ?? []
    }

    /// 自己创建的歌单（「…的歌单」板块的兜底）。
    private func fetchOwnedPlaylists(uid: Int?) async -> [PlaylistSummary] {
        guard let uid else { return [] }
        let all = (try? await MusicAPI.userPlaylists(uid: uid, limit: 200)) ?? []
        return all.filter { $0.creator?.userId == uid && !$0.subscribed }
    }

    private func fetchRadarPlaylists() async -> [RadarPlaylist] {
        let briefs = await withTaskGroup(of: (Int, MusicAPI.PlaylistBrief.Body?).self) { group in
            for id in Self.radarPlaylistIDs {
                group.addTask {
                    (id, try? await MusicAPI.playlistBrief(id: id))
                }
            }
            var byID: [Int: MusicAPI.PlaylistBrief.Body] = [:]
            for await (id, brief) in group {
                if let brief { byID[id] = brief }
            }
            return byID
        }
        return Self.radarPlaylistIDs.compactMap { id in
            guard let brief = briefs[id] else { return nil }
            // Names arrive as "今天从《…》听起|私人雷达" — split into title/subtitle.
            let parts = (brief.name ?? "").components(separatedBy: "|")
            let title = parts.count > 1 ? parts.last! : (brief.name ?? String(localized: "雷达歌单"))
            let subtitle = parts.count > 1 ? parts.dropLast().joined(separator: "|") : nil
            return RadarPlaylist(id: id, title: title, subtitle: subtitle, coverURL: brief.coverImgUrl)
        }
    }

    private func fetchRecommendPlaylists(loggedIn: Bool) async -> [PlaylistSummary] {
        if loggedIn {
            async let recommend = try? MusicAPI.recommendResource()
            async let personalized = try? MusicAPI.personalizedPlaylists(limit: 30)
            let head = await recommend ?? []
            let tail = await personalized ?? []
            var seen = Set<Int>()
            return (head + tail).filter { seen.insert($0.id).inserted }
        }
        return (try? await MusicAPI.personalizedPlaylists(limit: 30)) ?? []
    }
}

struct HomeView: View {
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var player: PlayerService
    @StateObject private var model = HomeViewModel.shared
    @AppStorage(HomeFeed.hiddenSectionsKey) private var hiddenHomeSections = ""

    var body: some View {
        GeometryReader { geometry in
            #if os(iOS)
            if model.loadedAccountID == account.authenticatedAccountID,
               case .loaded = model.state, HomeView.splitsLandscape(geometry.size) {
                // 横屏：两栏各是独立的 ScrollView，竖滑和横划都只作用于手指所在的
                // 半屏；文字用设计字号，只让卡片和间距适应半宽，不整体等比缩小。
                HStack(alignment: .top, spacing: 0) {
                    landscapeColumn(side: .left, width: geometry.size.width / 2)
                    landscapeColumn(side: .right, width: geometry.size.width / 2)
                }
            } else {
                ScrollView { stateBody(geometry.size) }
            }
            #else
            ScrollView { stateBody(geometry.size) }
            #endif
        }
        .navigationTitle("推荐")
        .task(id: account.authenticatedAccountID) {
            await model.load(accountID: account.authenticatedAccountID)
        }
    }

    @ViewBuilder
    private func stateBody(_ size: CGSize) -> some View {
        if model.loadedAccountID != account.authenticatedAccountID {
            loadingBody
        } else {
            switch model.state {
            case .idle, .loading:
                loadingBody
            case .error(let message):
                ErrorStateView(message: message) {
                    Task { await model.load(accountID: account.authenticatedAccountID, force: true) }
                }
                .frame(minHeight: 400)
            case .loaded:
                loadedBody(cardSize: singleColumnCardSize(size))
            }
        }
    }

    private func singleColumnCardSize(_ size: CGSize) -> CGFloat {
        #if os(iOS)
        return max(1, (size.width - 2 * Theme.Layout.contentInset - 32) / 3)
        #else
        return Theme.Layout.fittedShelfCardSize(availableWidth: size.width,
                                                leadingInset: Theme.Layout.contentInset)
        #endif
    }

    #if os(iOS)
    /// 横屏单栏：自己的滚动视图 + 半宽布局。卡片宽度按半宽重算，字号保持设计值，
    /// 所以文字不会再跟着卡片一起缩到一半。
    private func landscapeColumn(side: HomeColumn, width: CGFloat) -> some View {
        // 半栏里三张 feature 卡要「等比例缩小塞满左半」：内边距和间距同比收一半，
        // 剩下的宽度三等分（与安卓 --hs:0.5 的算法一致）。
        let inset = max(8, Theme.Layout.contentInset * 0.5)
        let gap: CGFloat = 10
        let featureWidth = max(96, (width - 2 * inset - 2 * gap) / 3)
        return ScrollView {
            loadedBody(cardSize: max(1, (width - 2 * Theme.Layout.contentInset - 32) / 3),
                       featureCardWidth: featureWidth,
                       featureGap: gap,
                       columns: side)
        }
        .frame(width: width)
        // 两栏各是独立 ScrollView：系统自动选的时候只给一半挂顶边模糊，
        // 另一半直接顶到屏幕上沿（右边看起来没有顶栏）。两栏都显式指定 soft。
        .compatSymmetricTopEdgeEffect()
    }
    #endif

    /// 横屏且宽 >= 540 时推荐页分左右两栏（左：feature 三卡 / 推荐歌单 /
    /// 雷达歌单；右：排行榜 / 新碟上架 / 推荐歌手），两栏各自独立滚动。
    static func splitsLandscape(_ size: CGSize) -> Bool {
        size.width > size.height && size.width >= 540
    }

    private var loadingBody: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.sectionSpacing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonView(cornerRadius: Theme.Radius.large)
                            .frame(width: 230, height: 132)
                    }
                }
            }
            SkeletonShelf()
            SkeletonShelf()
        }
        .padding(Theme.Layout.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func showsHomeSection(_ key: String) -> Bool {
        !hiddenHomeSections.split(separator: ",").contains(Substring(key))
    }

    private func loadedBody(cardSize: CGFloat,
                            featureCardWidth: CGFloat = FeatureCard.designWidth,
                            featureGap: CGFloat = 16,
                            columns: HomeColumn = .all) -> some View {
        #if os(iOS)
        let albumRowHeight = cardSize + 50
        let artistSize = cardSize
        let artistRowHeight = cardSize + 40
        #else
        let albumRowHeight = Theme.Layout.coverShelfHeight
        let artistSize: CGFloat = 128
        let artistRowHeight = Theme.Layout.artistShelfHeight
        #endif
        let visibleSections = model.sections.filter { showsHomeSection($0.slot.rawValue) }
        let showsFeatureCards = HomeSupplement.shortcuts.contains {
            showsHomeSection($0.rawValue)
        }
        return LazyVStack(alignment: .leading, spacing: Theme.Layout.sectionSpacing) {
            // Anonymous users go straight to recommended playlists;
            // the login entry lives in the sidebar / 我的 tab only.
            if account.isLoggedIn, columns != .right, showsFeatureCards {
                featureCards(width: featureCardWidth, gap: featureGap)
                    .padding(.top, 8)
            }

            if !model.sections.isEmpty {
                // 板块顺序、标题都以服务端下发的为准（参考实现的九个板块，
                // 不含「根据你听过的热门节目推荐」）。横屏分栏时按序号分到左右两栏。
                ForEach(Array(visibleSections.enumerated()), id: \.element.id) { index, section in
                    if columns == .all || (columns == .left) == (index % 2 == 0) {
                        sectionShelf(section)
                    }
                }
            } else {
                // 服务端没给板块（未登录或接口失败）时，退回本地拼的这套。
                if columns != .right, showsHomeSection(HomeFeedSlot.recommendedPlaylists.rawValue), !model.recommendPlaylists.isEmpty {
                    Shelf(title: "推荐歌单", rowHeight: Theme.Layout.coverShelfHeight) {
                        ForEach(Array(model.recommendPlaylists.prefix(12).enumerated()), id: \.element.id) { index, playlist in
                            playlistCard(playlist)
                                .staggeredAppearance(index: index, id: "home-rec-\(playlist.id)")
                        }
                    }
                }

                if columns != .right, showsHomeSection(HomeFeedSlot.radarPlaylists.rawValue), !model.radarPlaylists.isEmpty {
                    Shelf(title: "雷达歌单", rowHeight: Theme.Layout.coverShelfHeight) {
                        ForEach(model.radarPlaylists) { radar in
                            NavigationLink(value: Destination.radarPlaylist(radar.id)) {
                                CoverCardBody(
                                    coverURL: radar.coverURL?.resizedImageURL(384),
                                    title: radar.title,
                                    subtitle: radar.subtitle,
                                    titleLineLimit: Theme.Layout.shelfTitleLineLimit
                                ) {
                                    playPlaylist(radar.id)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if columns != .left, showsHomeSection(HomeFeedSlot.charts.rawValue), !model.toplists.isEmpty {
                    Shelf(title: "排行榜", seeAll: nil, rowHeight: Theme.Layout.coverShelfHeight) {
                        ForEach(model.toplists) { toplist in
                            NavigationLink(value: Destination.playlist(toplist.id)) {
                                toplistCard(toplist)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

            }

            // 新碟上架 / 推荐歌手：不在参考实现的九板块里，本项目保留，固定排在它们之后。
            if columns != .left, showsHomeSection(HomeSupplement.newAlbums.rawValue), !model.newAlbums.isEmpty {
                Shelf(title: "新碟上架", rowHeight: albumRowHeight) {
                    ForEach(model.newAlbums) { album in
                        albumCard(album, size: cardSize)
                    }
                }
            }

            if columns != .left, showsHomeSection(HomeSupplement.topArtists.rawValue), !model.topArtists.isEmpty {
                Shelf(title: "推荐歌手", rowHeight: artistRowHeight) {
                    ForEach(model.topArtists) { artist in
                        artistCard(artist, size: artistSize)
                    }
                }
            }

            if columns == .all, !account.isLoggedIn {
                Text("部分功能需登录后完全显示。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Theme.Layout.contentInset)
            }

            // 横屏分栏时只给右栏加底部让位，避免整块内容被悬浮播放条压住。
            if columns != .left { PlayerClearanceSpacer() }
        }
        .padding(.top, Theme.Layout.pageTopPadding)
        .padding(.bottom, Theme.Layout.contentInset - 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Server sections

    /// 一个服务端板块。歌单走封面卡，歌曲走「封面 + 歌名 + 歌手」的小卡。
    @ViewBuilder
    private func sectionShelf(_ section: HomeFeedSection) -> some View {
        switch section.content {
        case .playlists(let playlists):
            Shelf(title: LocalizedStringKey(section.title),
                  rowHeight: Theme.Layout.coverShelfHeight) {
                ForEach(playlists) { playlist in
                    NavigationLink(value: section.slot == .radarPlaylists
                                   ? Destination.radarPlaylist(playlist.id) : .playlist(playlist.id)) {
                        CoverCardBody(
                            coverURL: playlist.coverURL?.resizedImageURL(384),
                            title: playlist.name,
                            subtitle: playlist.subtitle,
                            playCount: playlist.playCount,
                            titleLineLimit: Theme.Layout.shelfTitleLineLimit
                        ) {
                            playPlaylist(playlist.id)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        case .songs(let songs):
            Shelf(title: LocalizedStringKey(section.title),
                  rowHeight: Theme.Layout.cardSize + 46) {
                ForEach(songs) { track in
                    songCard(track, in: section)
                }
            }
        }
    }

    /// 歌曲卡：点一下就从这首歌开始播整个板块。
    private func songCard(_ track: Track, in section: HomeFeedSection) -> some View {
        Button {
            player.play(tracks: section.songs, source: .none, startAt: track)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                CachedAsyncImage(url: track.album.picUrl?.resizedImageURL(384))
                    .frame(width: Theme.Layout.cardSize, height: Theme.Layout.cardSize)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.standard,
                                                style: .continuous))
                Text(track.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(track.artistNames)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: Theme.Layout.cardSize, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(track.name) \(track.artistNames)"))
    }

    // MARK: - Feature cards

    private func featureCards(width: CGFloat, gap: CGFloat = 16) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: gap) {
                Color.clear.frame(width: max(0, Theme.Layout.contentInset - 16), height: 1)
                if showsHomeSection(HomeSupplement.daily.rawValue) {
                    NavigationLink(value: Destination.daily) {
                        FeatureCard(
                            title: "每日推荐",
                            subtitle: "根据你的口味生成",
                            icon: "calendar",
                            coverURL: model.dailyFirstCover?.resizedImageURL(512),
                            showsDate: true,
                            width: width
                        )
                    }
                    .buttonStyle(.plain)
                }

                if showsHomeSection(HomeSupplement.privateFM.rawValue) {
                    Button {
                        player.startFM()
                    } label: {
                        FeatureCard(
                            title: "私人漫游",
                            subtitle: "从喜欢的歌开始漫游",
                            icon: "wave.3.right.circle.fill",
                            gradient: [Color(red: 0.16, green: 0.20, blue: 0.42),
                                       Color(red: 0.36, green: 0.24, blue: 0.62)],
                            width: width
                        )
                    }
                    .buttonStyle(.interactiveCard)
                }

                if showsHomeSection(HomeSupplement.heartbeat.rawValue) {
                    Button {
                        startHeartbeatMode()
                    } label: {
                        FeatureCard(
                            title: "心动模式",
                            subtitle: "你的红心歌曲和相似推荐",
                            icon: "heart.circle.fill",
                            gradient: [Color(red: 0.85, green: 0.19, blue: 0.41),
                                       Color(red: 0.98, green: 0.42, blue: 0.34)],
                            width: width
                        )
                    }
                    .buttonStyle(.interactiveCard)
                }
                Color.clear.frame(width: max(0, Theme.Layout.contentInset - 16), height: 1)
            }
            .padding(.vertical, 6)
        }
        .compatScrollClipDisabled()
        .shelfEdgeClip()
    }

    private func startHeartbeatMode() {
        guard let likedList = account.likedSongsPlaylist else { return }
        Task {
            guard let seed = account.likedTrackIDs.randomElement() else {
                ToastCenter.shared.show(String(localized: "先收藏一些喜欢的歌曲吧"))
                return
            }
            do {
                let tracks = try await MusicAPI.intelligenceList(songID: seed, playlistID: likedList.id)
                guard !tracks.isEmpty else {
                    ToastCenter.shared.show(String(localized: "心动模式暂时不可用"))
                    return
                }
                player.play(tracks: tracks, source: .playlist(likedList.id),
                            context: .heartbeat)
                ToastCenter.shared.show(String(localized: "已开启心动模式"))
            } catch {
                ToastCenter.shared.show(error.localizedDescription)
            }
        }
    }

    // MARK: - Cards

    private func playlistCard(_ playlist: PlaylistSummary) -> some View {
        NavigationLink(value: Destination.playlist(playlist.id)) {
            CoverCardBody(
                coverURL: playlist.coverURL?.resizedImageURL(384),
                title: playlist.name,
                subtitle: playlist.copywriter,
                playCount: playlist.playCount,
                titleLineLimit: Theme.Layout.shelfTitleLineLimit
            ) {
                playPlaylist(playlist.id)
            }
        }
        .buttonStyle(.plain)
    }

    private func albumCard(_ album: AlbumSummary, size: CGFloat) -> some View {
        NavigationLink(value: Destination.album(album.id)) {
            CoverCardBody(
                coverURL: album.picUrl?.resizedImageURL(384),
                title: album.name,
                subtitle: album.artistName,
                size: size,
                titleLineLimit: Theme.Layout.shelfTitleLineLimit
            ) {
                Task {
                    if let detail = try? await MusicAPI.album(id: album.id) {
                        player.play(tracks: detail.songs, source: .album(album.id),
                                    context: .album(id: album.id, name: album.name))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func artistCard(_ artist: ArtistSummary, size: CGFloat) -> some View {
        NavigationLink(value: Destination.artist(artist.id)) {
            VStack(spacing: 10) {
                CachedAsyncImage(url: artist.picUrl?.resizedImageURL(256))
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
                Text(artist.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            #if os(iOS)
            .frame(width: size)
            #else
            .frame(width: 140)
            #endif
        }
        .buttonStyle(.plain)
    }

    private func toplistCard(_ toplist: ToplistItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: toplist.coverImgUrl?.resizedImageURL(384))
                    .frame(width: Theme.Layout.cardSize, height: Theme.Layout.cardSize)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous))
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous))
                Text(toplist.updateFrequency ?? "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(8)
            }
            .frame(width: Theme.Layout.cardSize, height: Theme.Layout.cardSize)
            Text(toplist.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(width: Theme.Layout.cardSize, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func playPlaylist(_ id: Int) {
        let intent = player.beginPlaybackIntent()
        let owner = account.authenticatedAccountID
        Task {
            guard let detail = try? await MusicAPI.playlistDetail(id: id) else { return }
            guard player.isCurrentPlaybackIntent(intent), owner == account.authenticatedAccountID else { return }
            var tracks = detail.playlist.tracks
            if tracks.isEmpty {
                let ids = detail.playlist.trackIds.map(\.id)
                tracks = (try? await MusicAPI.songDetails(ids: Array(ids.prefix(500))))?.songs ?? []
            }
            guard player.isCurrentPlaybackIntent(intent), owner == account.authenticatedAccountID else { return }
            player.play(tracks: tracks, source: .playlist(id),
                        context: .playlist(id: id, name: detail.playlist.name))
        }
    }
}

// MARK: - Two-column landscape

/// 推荐页横屏分栏时该栏要渲染哪些板块。
enum HomeColumn: Equatable {
    case left, right, all
}

// MARK: - Feature card

struct FeatureCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    var coverURL: URL?
    var gradient: [Color] = [Color(red: 0.75, green: 0.16, blue: 0.22),
                             Color(red: 0.95, green: 0.35, blue: 0.28)]
    var showsDate = false
    /// 卡片宽度。推荐页横屏时传入半栏内可分到的宽度，其余场合保持 230pt；
    /// 高度、内边距、圆角按 `width/230` 同比缩放，字号只按 `textK` 小幅收，
    /// 保证半屏里文字仍然读得清。
    var width: CGFloat = FeatureCard.designWidth

    static let designWidth: CGFloat = 230
    private static let designHeight: CGFloat = 132
    private var k: CGFloat { width / FeatureCard.designWidth }
    private var height: CGFloat { FeatureCard.designHeight * k }
    private var cornerRadius: CGFloat { Theme.Radius.large * min(1, k) }
    /// 字号缩放：卡片变小的时候文字只跟着收一点点（下限 0.8），
    /// 否则半屏里 15pt 标题会变成 9pt 看不清。
    private var textK: CGFloat { max(0.9, k) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let coverURL {
                CachedAsyncImage(url: coverURL)
                    .frame(width: width, height: height)
                LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.68)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.white.opacity(0.18), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 220)
            }

            VStack(alignment: .leading, spacing: 3 * k) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 22 * textK, weight: .medium))
                        .foregroundStyle(.white)
                    if showsDate {
                        Text("\(Calendar.current.component(.day, from: .now))")
                            .font(.system(size: 10 * textK, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(y: 3 * k)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Text(title)
                    .font(.system(size: 15 * textK, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11 * textK))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(14 * k)
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}

/// Card body without its own Button wrapper (for use inside NavigationLink).
struct CoverCardBody: View {
    let coverURL: URL?
    let title: String
    var subtitle: String?
    var playCount: Int = 0
    var size: CGFloat = Theme.Layout.cardSize
    var titleLineLimit = 2
    var onPlay: (() -> Void)?

    @State private var isHovering = false
    @Environment(\.flexibleCardWidth) private var flexibleWidth

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artwork
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                )
                .overlay(alignment: .topTrailing) {
                    if playCount > 0 {
                        PlayCountBadge(count: playCount)
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let onPlay {
                        PlayOverlayButton(visible: isHovering, action: onPlay)
                            .padding(8)
                    }
                }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(titleLineLimit)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
                .frame(maxWidth: flexibleWidth ? .infinity : size, alignment: .leading)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: flexibleWidth ? .infinity : size, alignment: .leading)
            }
        }
        .frame(maxWidth: flexibleWidth ? .infinity : size, alignment: .leading)
        .contentShape(Rectangle())
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
    }

    @ViewBuilder
    private var artwork: some View {
        if flexibleWidth {
            CachedAsyncImage(url: coverURL)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
        } else {
            CachedAsyncImage(url: coverURL)
                .frame(width: size, height: size)
        }
    }
}
