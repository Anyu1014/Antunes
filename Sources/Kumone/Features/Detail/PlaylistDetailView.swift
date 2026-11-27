import SwiftUI
#if os(iOS)
import ImageIO
import PhotosUI
import UniformTypeIdentifiers
import UIKit
#endif


struct PlaylistDetailView: View {
    let playlistID: Int
    var isLikedList = false
    var recommendationContext: RecommendationContext?

    @StateObject private var model: PlaylistContent
    @ObservedObject private var downloads = DownloadManager.shared
    // This page only sends playback commands; individual rows observe playback.
    private let player = PlayerService.shared
    @EnvironmentObject private var account: AccountStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// 吸顶条是否已经顶到导航栏下缘。
    @State private var headerStuck = false
    @State private var showFullDescription = false
    #if os(iOS)
    @Environment(\.dismiss) private var dismissPlaylist
    @Environment(\.miniPlayerFrame) private var miniPlayerFrame
    @Environment(\.floatingChromeClearance) private var floatingChromeClearance
    @State private var playlistWasDeleted = false
    /// 页面可用尺寸：横屏时顶部信息要按「小播放器右边缘」收窄，需要真实窗口宽度。
    @State private var containerSize: CGSize = .zero
    private var coverPreference = CollectionCoverPreference()
    @State private var showSearch = false
    @State private var searchFocused = false
    @State private var locateTrackID: Int?
    @State private var locateRequest = 0
    /// 歌单多选：和安卓端一样的「选择」模式。
    @State private var isSelecting = false
    @State private var selectedIDs: Set<Int> = []
    @State private var addSelectionToPlaylist = false
    #endif

    init(playlistID: Int, isLikedList: Bool = false, recommendationContext: RecommendationContext? = nil) {
        self.playlistID = playlistID
        self.isLikedList = isLikedList
        self.recommendationContext = recommendationContext
        #if os(iOS)
        _model = StateObject(wrappedValue: PlaylistContent(playlistID: playlistID, preparesArtwork: true))
        #else
        _model = StateObject(wrappedValue: PlaylistContent(playlistID: playlistID))
        #endif
    }

    private var isOwnPlaylist: Bool {
        guard let accountID = account.authenticatedAccountID else { return false }
        return model.detail?.creator?.userId == accountID
    }

    private var isCompact: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone || horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    /// 横屏时歌曲列表从右半区开始（左半区留给顶部信息）。
    private var heroInset: CGFloat {
        #if os(iOS)
        guard isCompact, containerSize.width > containerSize.height,
              containerSize.width >= 540 else { return 0 }
        return 12 + min(336, max(218, (containerSize.width - 24) * 0.38))
        #else
        return 0
        #endif
    }

    /// 横屏时顶部信息（封面/标题/作者/播放量/简介/播放全部）只占小播放器右边缘以内。
    /// 播放器宽度与 `IOSMainWindow` 里 playerWidth 同一条公式，两侧各 12pt 内边距。
    private var heroMaxWidth: CGFloat {
        #if os(iOS)
        guard isCompact, containerSize.width > containerSize.height,
              containerSize.width >= 540 else { return .infinity }
        return 12 + min(336, max(218, (containerSize.width - 24) * 0.38))
        #else
        return .infinity
        #endif
    }

    /// The account's own 我喜欢的音乐, whose 更多 menu also offers sorting.
    private var isOwnLikedSongs: Bool {
        model.detail?.specialType == 5 && isOwnPlaylist
    }

    /// iOS reveals the in-list search for every playlist (macOS keeps its
    /// search field in the action row).
    private var supportsPlaylistSearch: Bool {
        #if os(iOS)
        return model.detail != nil
        #else
        return false
        #endif
    }

    /// Loading notes that mention search: always on the liked list, as
    /// before, and on any other playlist while it is being searched.
    private var showsSearchLoadingNotes: Bool {
        supportsPlaylistSearch && (isOwnLikedSongs || isSearchActive || TrackSearch.query(model.filter) != nil)
    }

    #if os(iOS)
    private func revealSearch(_ proxy: ScrollViewProxy) {
        withAnimation(AppAnimation.standard) {
            showSearch = true
            proxy.scrollTo("playlistTop", anchor: .top)
        }
        searchFocused = true
    }
    #endif

    private var isSearchActive: Bool {
        #if os(iOS)
        return supportsPlaylistSearch && showSearch
        #else
        return false
        #endif
    }

    var body: some View {
        ScrollViewReader { proxy in
            onlineContent(searchProxy: proxy)
                .task(id: "\(playlistID):\(account.offlineScope ?? ""):\(downloads.network.isKnown):\(downloads.network.connected)") {
                    await loadPlaylist()
                }
                #if os(iOS)
                .sheet(isPresented: $showFullDescription, onDismiss: {
                    if playlistWasDeleted { dismissPlaylist() }
                }) {
                    if let detail = model.detail {
                        playlistDescriptionSheet(detail)
                    }
                }
                .onChange(of: locateRequest) { _ in
                    guard let id = locateTrackID else { return }
                    // Let a cleared search lay out its rows before scrolling.
                    DispatchQueue.main.async {
                        withAnimation(AppAnimation.standard) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
                #endif
                .toolbar {
                    if model.errorMessage != nil, downloads.network.connected, model.detail != nil {
                        ToolbarItem(placement: .primaryAction) {
                            Button { Task { await loadPlaylist() } } label: { Image(systemName: "arrow.clockwise") }
                                .accessibilityLabel("重试")
                                .help("重试")
                        }
                    }
                }
        }
    }

    private func loadPlaylist() async {
        #if os(iOS)
        let artworkSize: Int? = LayoutSizeClass.isCompact(horizontal: horizontalSizeClass,
            vertical: verticalSizeClass, fallback: UIDevice.current.userInterfaceIdiom == .phone) ? 160 : 96
        #else
        let artworkSize: Int? = nil
        #endif
        await model.load(allowNetwork: !downloads.network.isKnown || downloads.network.connected,
                         summary: account.userPlaylists.first { $0.id == playlistID },
                         artworkSize: artworkSize)
    }

    @ViewBuilder
    private func onlineContent(searchProxy: ScrollViewProxy) -> some View {
        #if os(macOS)
        Group {
            if model.loadedScope == account.offlineScope, let detail = model.detail {
                let tracks = model.filteredTracks
                TrackTable(
                    trackIDs: tracks.map(\.id),
                    header: AnyView(regularHeader(detail)
                        .padding(.horizontal, Theme.Layout.contentInset)
                        .padding(.top, 16)
                        .padding(.bottom, 20)),
                    footer: AnyView(VStack(spacing: 20) {
                        playlistStatus(detail)
                        PlayerClearanceSpacer()
                    }.padding(.top, 20)),
                    headerHeight: 246,
                    footerHeight: desktopFooterHeight(detail)
                ) { index in
                    AnyView(trackList(tracks, layout: .singleRow(index))
                        .padding(.horizontal, Theme.Layout.contentInset - 10))
                }
            } else {
                ScrollView { playlistContents }
            }
        }
        .clipped()
        .navigationTitle(model.detail?.name ?? String(localized: "歌单"))
        #else
        GeometryReader { geo in
            let isLandscape = HomeView.splitsLandscape(geo.size)
            let style = coverPreference.style(landscape: geo.size.width > geo.size.height)
            let gradientStyle = CollectionGradientStyle(rawValue: style)
            let showsGradient = gradientStyle != nil && model.loadedScope == account.offlineScope && model.detail != nil
            Group {
                if showsGradient, let detail = model.detail, let gradientStyle {
                    gradientContent(detail, width: geo.size.width, style: gradientStyle,
                                    landscapeLeftWidth: isLandscape ? leftColumnWidth(geo.size.width) : nil,
                                    search: supportsPlaylistSearch ? { toggleGradientSearch(searchProxy) } : nil)
                } else if isLandscape {
                    landscapeContents(width: geo.size.width)
                } else {
                    singleColumnContents
                }
            }
            .toolbar {
                if !isLandscape || !showsGradient {
                    searchToolbar(searchProxy, usesGradient: gradientStyle != nil)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .progressiveTopBarInLandscape()
        .background(Platform.windowBackgroundColor.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(isSearchActive
                     ? String(localized: "搜索歌单内歌曲")
                     : (model.detail?.name ?? ""))
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(headerStuck || isSearchActive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.18), value: headerStuck)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        #endif
    }

    #if os(iOS)
    @ToolbarContentBuilder
    private func searchToolbar(_ proxy: ScrollViewProxy, usesGradient: Bool) -> some ToolbarContent {
        if !usesGradient, isOwnLikedSongs && supportsPlaylistSearch && !isSearchActive {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        revealSearch(proxy)
                    } label: {
                        Label("在歌单内查找", systemImage: "magnifyingglass")
                    }
                    Menu {
                        Picker("排序方式", selection: $model.sortOrder) {
                            ForEach(PlaylistTrackSort.allCases, id: \.self) { order in
                                Text(LocalizedStringKey(order.rawValue)).tag(order)
                            }
                        }
                    } label: {
                        Label("排序方式", systemImage: "arrow.up.arrow.down")
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis")
                }
                .accessibilityIdentifier("likedSongsMenu")
            }
        } else if supportsPlaylistSearch && !isSearchActive {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    revealSearch(proxy)
                } label: {
                    Label("在歌单内查找", systemImage: "magnifyingglass")
                }
                .accessibilityIdentifier("playlistSearchButton")
            }
        }
    }

    private func toggleGradientSearch(_ proxy: ScrollViewProxy) {
        if isSearchActive {
            model.filter = ""
            searchFocused = false
            withAnimation(AppAnimation.standard) { showSearch = false }
        } else {
            revealSearch(proxy)
        }
    }

    /// 竖屏：原来的单列（hero + 吸顶操作条 + 歌曲列表）。
    private var singleColumnContents: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                playlistHero
                    .padding(.horizontal, isCompact ? 16 : Theme.Layout.contentInset)
                    .frame(maxWidth: heroMaxWidth, alignment: .leading)
                    .padding(.top, isCompact ? 12 : 16)
                    .padding(.bottom, 4)
                Section {
                    playlistBody
                        .padding(.leading, heroInset)
                } header: {
                    pinnedActionBar
                        // 吸顶条顶到导航栏下缘（`minY` 到 0）就算两部分合并；
                        // 还在跟着内容走的时候不显示标题。
                        .background {
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: HeaderStuckKey.self,
                                    value: geo.frame(in: .named("playlistScroll")).minY
                                )
                            }
                        }
                }
            }
            .id("playlistTop")
            #if os(iOS)
            .background {
                if supportsPlaylistSearch {
                    PlaylistSearchScrollGesture(isSearchActive: showSearch, onPullDown: {
                        withAnimation(AppAnimation.standard) { showSearch = true }
                        searchFocused = true
                    }, onScrollUp: {
                        searchFocused = false
                        withAnimation(AppAnimation.standard) { showSearch = false }
                    })
                }
            }
            #endif
        }
        .coordinateSpace(name: "playlistScroll")
        #if os(iOS)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { containerSize = proxy.size }
                    .onChange(of: proxy.size) { size in containerSize = size }
            }
        }
        #endif
        .onPreferenceChange(HeaderStuckKey.self) { minY in
            headerStuck = minY <= 1
        }
    }

    private func gradientContent(_ detail: PlaylistDetail, width: CGFloat, style: CollectionGradientStyle, landscapeLeftWidth: CGFloat?, search: (() -> Void)?) -> some View {
        GradientCollectionPage(
            width: width, landscapeLeftWidth: landscapeLeftWidth, coverURL: detail.coverImgUrl?.resizedImageURL(960),
            style: style,
            portraitSquareCover: true,
            title: isLikedList ? String(localized: "我喜欢的音乐") : detail.name,
            author: detail.creator?.nickname,
            description: detail.description,
            editDescription: isOwnPlaylist ? { showFullDescription = true } : nil,
            isFavorite: detail.subscribed, canPlay: !playable.isEmpty,
            play: { player.play(tracks: playable, source: .playlist(playlistID), context: .playlist(id: playlistID, name: detail.name)) },
            favorite: !isOwnPlaylist && account.isLoggedIn ? { toggleSubscribe(detail) } : nil,
            search: search
        ) {
            if isSelecting {
                selectionBar(detail)
            } else {
                HStack(spacing: 10) {
                    Text("\(detail.trackCount) 首 · \(Formatters.playCount(detail.playCount)) 次播放")
                        .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 4)
                    selectToggleButton()
                    downloadButton(detail, compact: true)
                }
                .padding(.top, 8)
                .padding(.bottom, landscapeLeftWidth == nil ? 4 : 8)
            }
        } rows: {
            playlistBody.id("playlistTop")
        }
        .overlay {
            GeometryReader { geo in
                let clearance = miniPlayerFrame.map { max(0, geo.frame(in: .global).maxY - $0.minY) }
                    ?? floatingChromeClearance ?? Theme.Layout.playerChromeClearance
                currentTrackLocator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16)
                    .padding(.bottom, clearance + 24)
            }
        }
    }

    private func leftColumnWidth(_ width: CGFloat) -> CGFloat { max(260, min(420, width * 0.42)) }

    /// 横屏：左半 = 封面/标题/创作者/简介/操作条，右半 = 歌曲列表，各自独立滚动。
    private func landscapeContents(width: CGFloat) -> some View {
        let leftWidth = leftColumnWidth(width)
        return HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    playlistHero
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    pinnedActionBar
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, Theme.Layout.playerChromeClearance)
            }
            .frame(width: leftWidth)
            .scrollIndicators(.hidden)

            Divider().opacity(0.35)

            ScrollView {
                playlistBody
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, Theme.Layout.playerChromeClearance)
            }
            .scrollIndicators(.hidden)
        }
    }
    #endif

    #if os(macOS)
    private func desktopFooterHeight(_ detail: PlaylistDetail) -> CGFloat {
        let clearance = Theme.Layout.playerChromeClearance + Theme.Layout.scrollBreathingMargin + 20
        if model.isLoading || model.isLoadingMore { return clearance + 60 }
        if model.tracks.isEmpty { return clearance + 100 }
        if model.tracks.count < detail.trackCount { return clearance + 40 }
        return clearance
    }
    #endif

    private func trackList(_ tracks: [Track], layout: TrackListView.Layout = .stack) -> some View {
        #if os(iOS)
        let selection = isSelecting ? $selectedIDs : nil
        let move: ((Int, Int, Bool) -> Void)? = isSelecting && !model.isLoading && !model.isLoadingMore && recommendationContext == nil
            ? { model.moveTrack($0, relativeTo: $1, after: $2) } : nil
        #else
        let selection: Binding<Set<Int>>? = nil
        let move: ((Int, Int, Bool) -> Void)? = nil
        #endif
        return TrackListView(
            tracks: tracks,
            privileges: model.privileges,
            source: .playlist(playlistID),
            context: model.detail.map { .playlist(id: playlistID, name: $0.name) },
            removableFromPlaylistID: isOwnPlaylist ? playlistID : nil,
            onRemoved: { track in Task { await model.remove(track) } },
            recommendationContext: recommendationContext,
            onRecommendationReplaced: { model.replaceRecommendation($0, with: $1) },
            selection: selection,
            onMove: move,
            layout: layout,
            // A search result plays the whole playlist from that song.
            queue: model.orderedTracks
        )
    }

    /// Cover, title, counts and description. Scrolls away — it is deliberately
    /// not part of the pinned area.
    @ViewBuilder
    private var playlistHero: some View {
        if !isSearchActive, model.loadedScope == account.offlineScope, let detail = model.detail {
            if isCompact {
                compactHero(detail)
            } else {
                regularHeader(detail)
            }
        }
    }

    /// The play-all row. Only this row stays pinned while the list scrolls.
    @ViewBuilder
    private var pinnedActionBar: some View {
        if isCompact, !isSearchActive, model.loadedScope == account.offlineScope, let detail = model.detail {
            compactActionBar(detail)
                .padding(.horizontal, 16)
                // 横屏时和顶部信息一样只用左半区；外面那层 maxWidth 仍然拉满，
                // 这样白底不会只铺一半。
                .frame(maxWidth: heroMaxWidth, alignment: .leading)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                // 吸顶条自己不再铺底：横屏的底由系统导航栏提供，这里只留按钮本身。
        }
    }

    /// Everything below the pinned header.
    @ViewBuilder
    private var playlistBody: some View {
        if model.loadedScope == account.offlineScope, let detail = model.detail {
            let filteredTracks = model.filteredTracks
            VStack(alignment: .leading, spacing: isCompact ? 16 : 20) {
                if isSearchActive {
                    ListSearchBar(text: $model.filter, isFocused: $searchFocused) {
                        model.filter = ""
                        searchFocused = false
                        withAnimation(AppAnimation.standard) { showSearch = false }
                    }
                    .padding(.horizontal, isCompact ? 8 : Theme.Layout.contentInset - 8)
                    .padding(.top, 8)
                    .transition(.opacity)
                }

                if supportsPlaylistSearch && TrackSearch.query(model.filter) != nil {
                    SongSearchSummary(
                        count: filteredTracks.count,
                        isSettled: !model.isLoadingMore && model.errorMessage == nil,
                        onClear: isSearchActive ? nil : { model.filter = "" },
                        horizontalPadding: isCompact ? 16 : Theme.Layout.contentInset
                    )
                }

                trackList(filteredTracks)
                    .padding(.horizontal, isCompact ? 6 : Theme.Layout.contentInset - 10)

                playlistStatus(detail)
            }
            .padding(.top, 8)
        } else if model.isLoading {
            loadingHeader
        } else if let message = model.errorMessage {
            ErrorStateView(message: message) {
                Task { await loadPlaylist() }
            }
            .frame(minHeight: 400)
        } else {
            EmptyStateView(icon: "music.note.list", title: "联网后载入歌曲")
                .frame(minHeight: 400)
        }
        PlayerClearanceSpacer()
    }

    @ViewBuilder
    private var playlistContents: some View {
        if model.loadedScope == account.offlineScope, let detail = model.detail {
            let filteredTracks = model.filteredTracks
            if !isSearchActive {
                if isCompact {
                    compactHeader(detail)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                } else {
                    regularHeader(detail)
                        .padding(.horizontal, Theme.Layout.contentInset)
                        .padding(.top, 16)
                }
            }

            #if os(iOS)
            if isSearchActive {
                ListSearchBar(text: $model.filter, isFocused: $searchFocused) {
                    model.filter = ""
                    searchFocused = false
                    withAnimation(AppAnimation.standard) { showSearch = false }
                }
                .padding(.horizontal, isCompact ? 8 : Theme.Layout.contentInset - 8)
                .padding(.top, 8)
                .transition(.opacity)
            }

            if supportsPlaylistSearch && TrackSearch.query(model.filter) != nil {
                SongSearchSummary(
                    count: filteredTracks.count,
                    isSettled: !model.isLoadingMore && model.errorMessage == nil,
                    onClear: isSearchActive ? nil : { model.filter = "" },
                    horizontalPadding: isCompact ? 16 : Theme.Layout.contentInset
                )
            }
            #endif

            trackList(filteredTracks)
                .padding(.horizontal, isCompact ? 6 : Theme.Layout.contentInset - 10)

            playlistStatus(detail)
        } else if model.isLoading {
            loadingHeader
        } else if let message = model.errorMessage {
            ErrorStateView(message: message) {
                Task { await loadPlaylist() }
            }
            .frame(minHeight: 400)
        } else {
            EmptyStateView(icon: "music.note.list", title: "联网后载入歌曲")
                .frame(minHeight: 400)
        }
        PlayerClearanceSpacer()
    }

    @ViewBuilder
    private func playlistStatus(_ detail: PlaylistDetail) -> some View {
        if !model.isRefreshing && (model.isLoading || model.isLoadingMore) {
            HStack {
                Spacer()
                ProgressView().controlSize(.small)
                #if os(iOS)
                if showsSearchLoadingNotes {
                    Text("正在加载歌单，搜索结果会继续更新…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                #endif
                Spacer()
            }
            .padding(.vertical, 12)
        } else if model.tracks.isEmpty {
            Text(detail.trackCount == 0 ? String(localized: "歌单暂无歌曲") : String(localized: "联网后载入歌曲"))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else if model.tracks.count < detail.trackCount {
            Text("已载入 \(model.tracks.count)/\(detail.trackCount) 首")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, isCompact ? 16 : Theme.Layout.contentInset)
        }

        #if os(iOS)
        if showsSearchLoadingNotes, model.tracks.count < detail.trackCount, let message = model.errorMessage {
            VStack(spacing: 8) {
                Text("歌单未完整加载，搜索结果可能不完整")
                    .font(.subheadline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("重试") { Task { await loadPlaylist() } }
                    .buttonStyle(.bordered)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, isCompact ? 16 : Theme.Layout.contentInset)
        }
        #endif
    }

    // MARK: - Compact (Mobile) Header

    private func compactHeader(_ detail: PlaylistDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            compactHero(detail)
            compactActionBar(detail)
        }
    }

    private var playlistEditorChevron: some View {
        Button { showFullDescription = true } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .frame(minWidth: 24, minHeight: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tertiary)
        .accessibilityLabel("打开歌单编辑")
    }

    private func compactHero(_ detail: PlaylistDetail) -> some View {
        let needsDescription = isOwnPlaylist && (detail.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                CachedAsyncImage(url: detail.coverImgUrl?.resizedImageURL(384), animated: false) {
                    // 占位不要画音符图标：图标出现再消失才叫「闪」，纯色块过渡看不出来。
                    RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }
                .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(isLikedList ? String(localized: "我喜欢的音乐") : detail.name)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(3)

                    if let creator = detail.creator, !isLikedList || needsDescription {
                        HStack(spacing: 6) {
                            CachedAsyncImage(url: creator.avatarUrl?.resizedImageURL(48), animated: false)
                                .frame(width: 18, height: 18)
                                .clipShape(Circle())
                            Text(creator.nickname)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if needsDescription {
                                playlistEditorChevron
                            }
                        }
                    }

                    Text("\(detail.trackCount) 首 · \(Formatters.playCount(detail.playCount)) 次播放")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            if let description = detail.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    showFullDescription = true
                } label: {
                    HStack(spacing: 4) {
                        Text(description.replacingOccurrences(of: "\n", with: " "))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    #if os(iOS)
    private func playlistDescriptionSheet(_ detail: PlaylistDetail) -> some View {
        let owner = account.authenticatedAccountID
        let scope = account.offlineScope
        let binding = MusicClient.shared.authenticationFingerprint
        let editable = isOwnPlaylist && owner != nil && scope != nil && binding != nil
        let deleteAction: (@MainActor () async throws -> Void)?
        if editable && detail.specialType != 5 {
            deleteAction = {
                guard let scope, let binding, owner == account.authenticatedAccountID,
                      scope == account.offlineScope, binding == MusicClient.shared.authenticationFingerprint else {
                    throw MusicAPIError.needLogin
                }
                try await MusicAPI.deletePlaylist(id: playlistID, binding: binding)
                await PlaylistSnapshotStore.shared.removePlaylist(id: playlistID, scope: scope)
                guard owner == account.authenticatedAccountID, scope == account.offlineScope,
                      binding == MusicClient.shared.authenticationFingerprint else { return }
                account.userPlaylists.removeAll { $0.id == playlistID }
                playlistWasDeleted = true
                showFullDescription = false
                Task { await account.refreshLibrary() }
            }
        } else {
            deleteAction = nil
        }
        return PlaylistDescriptionSheet(detail: detail, editable: editable, onDelete: deleteAction, onSave: { description, jpeg in
            guard editable, let scope, let binding, owner == account.authenticatedAccountID,
                  scope == account.offlineScope, binding == MusicClient.shared.authenticationFingerprint else {
                throw MusicAPIError.needLogin
            }
            var coverURL: String?
            if let description {
                try await MusicAPI.updatePlaylistDescription(id: playlistID, description: description, binding: binding)
            }
            if let jpeg {
                coverURL = try await MusicAPI.updatePlaylistCover(id: playlistID, jpeg: jpeg, binding: binding)
            }
            guard owner == account.authenticatedAccountID, scope == account.offlineScope,
                  binding == MusicClient.shared.authenticationFingerprint else { throw CancellationError() }
            if let coverURL, let index = account.userPlaylists.firstIndex(where: { $0.id == playlistID }) {
                account.userPlaylists[index].coverURL = coverURL
            }
            await model.applyEditedMetadata(description: description, coverURL: coverURL, scope: scope)
            return coverURL
        })
    }
    #endif

    @ViewBuilder
    private var currentTrackLocator: some View {
        #if os(iOS)
        PlaylistLocateButton(trackIDs: Set(model.tracks.map(\.id))) { id in
            model.filter = ""
            showSearch = false
            searchFocused = false
            locateTrackID = id
            locateRequest += 1
        }
        #endif
    }

    private func compactActionBar(_ detail: PlaylistDetail) -> some View {
        Group {
            if isSelecting {
                selectionBar(detail)
            } else {
            HStack(spacing: 10) {
                Button {
                    player.play(tracks: playable, source: .playlist(playlistID),
                                context: model.detail.map { .playlist(id: playlistID, name: $0.name) })
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("播放全部 (\(playable.count))")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Theme.accentGradient, in: Capsule())
                    .shadow(color: Theme.accent.opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.pressable)
                .disabled(playable.isEmpty)

                selectToggleButton()

                downloadButton(detail, compact: true)

                if isLikedList {
                    Button {
                        startHeartbeat()
                    } label: {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 38, height: 38)
                            .background(.primary.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.pressable)
                } else if !isOwnPlaylist, account.isLoggedIn {
                    Button {
                        toggleSubscribe(detail)
                    } label: {
                        Image(systemName: detail.subscribed ? "star.fill" : "star")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(detail.subscribed ? Color(red: 0.95, green: 0.72, blue: 0.02) : .primary)
                            .frame(width: 38, height: 38)
                            .background(.primary.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.pressable)
                }
                currentTrackLocator
            }
            }
        }
        .animation(AppAnimation.standard, value: isSelecting)
    }

    // MARK: - Regular (Desktop / iPad) Header

    private func regularHeader(_ detail: PlaylistDetail) -> some View {
        HStack(alignment: .bottom, spacing: 24) {
            CachedAsyncImage(url: detail.coverImgUrl?.resizedImageURL(512), animated: false)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(isLikedList ? String(localized: "我喜欢的音乐") : String(localized: "歌单"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(detail.name)
                    .font(.title.weight(.bold))
                    .lineLimit(2)

                if let creator = detail.creator {
                    HStack(spacing: 6) {
                        CachedAsyncImage(url: creator.avatarUrl?.resizedImageURL(48), animated: false)
                            .frame(width: 18, height: 18)
                            .clipShape(Circle())
                        Text(creator.nickname)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        #if os(iOS)
                        if isOwnPlaylist && (detail.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            playlistEditorChevron
                        }
                        #endif
                    }
                }

                Text("\(detail.trackCount) 首 · \(Formatters.playCount(detail.playCount)) 次播放 · 更新于 \(Formatters.date(fromMS: detail.updateTime))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)

                if let description = detail.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        showFullDescription = true
                    } label: {
                        Text(description.replacingOccurrences(of: "\n", with: " "))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    #if os(macOS)
                    .popover(isPresented: $showFullDescription, arrowEdge: .bottom) {
                        ScrollView {
                            Text(description)
                                .font(.system(size: 13))
                                .padding(16)
                                .frame(width: 380, alignment: .leading)
                        }
                        .frame(maxHeight: 400)
                    }
                    #endif
                }

                Spacer(minLength: 4)

                actionRow(detail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 210)
    }

    private func actionRow(_ detail: PlaylistDetail) -> some View {
        Group {
            if isSelecting {
                selectionBar(detail)
            } else {
            HStack(spacing: 10) {
            Button {
                player.play(tracks: playable, source: .playlist(playlistID),
                            context: .playlist(id: playlistID, name: detail.name))
            } label: {
                Label("播放全部", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Theme.accentGradient, in: Capsule())
                    .shadow(color: Theme.accent.opacity(0.3), radius: 6, y: 2)
            }
            .buttonStyle(.pressable)
            .disabled(playable.isEmpty)

            selectToggleButton()

            if isLikedList {
                Button {
                    startHeartbeat()
                } label: {
                    Label("心动模式", systemImage: "heart.circle")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.pressable)
            } else if !isOwnPlaylist, account.isLoggedIn {
                Button {
                    toggleSubscribe(detail)
                } label: {
                    Label(detail.subscribed ? String(localized: "已收藏") : String(localized: "收藏"),
                          systemImage: detail.subscribed ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.pressable)
            }

            downloadButton(detail)

            #if os(iOS)
            Spacer(minLength: 0)
            currentTrackLocator
            #endif

            #if os(macOS)
            Spacer()

            ListFilterField(placeholder: "搜索歌单内歌曲", text: $model.filter)
            #endif
            }
            }
        }
        .animation(AppAnimation.standard, value: isSelecting)
    }

    private var playable: [Track] {
        let tracks = model.orderedTracks
        if SettingsManager.shared.canResolveUnblockedTracks { return tracks }
        return tracks.filter { track in
            downloads.offlineTracksByID[track.id] != nil || track.playability(privilege: model.privileges[track.id],
                           isLoggedIn: account.isLoggedIn,
                           vipType: account.vipType) == .playable
        }
    }

    private func startHeartbeat() {
        Task {
            guard let seed = playable.randomElement() else { return }
            do {
                let tracks = try await MusicAPI.intelligenceList(songID: seed.id, playlistID: playlistID)
                guard !tracks.isEmpty else {
                    ToastCenter.shared.show(String(localized: "心动模式暂时不可用"))
                    return
                }
                player.play(tracks: tracks, source: .playlist(playlistID), context: .heartbeat)
                ToastCenter.shared.show(String(localized: "已开启心动模式"))
            } catch {
                ToastCenter.shared.show(error.localizedDescription)
            }
        }
    }

    private func toggleSubscribe(_ detail: PlaylistDetail) {
        Task {
            do {
                try await MusicAPI.subscribePlaylist(id: detail.id, subscribe: !detail.subscribed)
                model.detail?.subscribed.toggle()
                await account.refreshLibrary()
            } catch {
                ToastCenter.shared.show(error.localizedDescription)
            }
        }
    }

    // MARK: - Selection

    private func selectToggleButton() -> some View {
        Button {
            withAnimation(AppAnimation.standard) {
                isSelecting.toggle()
                if !isSelecting { selectedIDs = [] }
            }
        } label: {
            Image(systemName: isSelecting ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(isSelecting ? Theme.accent : Color.primary)
                .frame(width: 38, height: 38)
                .background(.primary.opacity(0.06), in: Circle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(isSelecting ? "退出选择" : "选择歌曲")
        .accessibilityIdentifier("playlist-select-toggle")
    }

    private func selectionAction(_ symbol: String, _ label: String,
                                 enabled: Bool = true,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .frame(width: 38, height: 38)
                .background(.primary.opacity(0.06), in: Circle())
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier("playlist-select-\(label)")
    }

    private func selectionBar(_ detail: PlaylistDetail) -> some View {
        HStack(spacing: 10) {
            Text("已选 \(selectedIDs.count) 首")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .accessibilityIdentifier("playlist-select-count")
            Spacer(minLength: 0)
            selectionAction("checkmark.circle", "全选") { toggleSelectAll() }
            selectionAction("arrow.down.circle", "下载所选", enabled: !selectedIDs.isEmpty) { downloadSelection(detail) }
            selectionAction("heart", "收藏所选", enabled: !selectedIDs.isEmpty) { likeSelection() }
            selectionAction("text.badge.plus", "添加到歌单", enabled: !selectedIDs.isEmpty) {
                addSelectionToPlaylist = true
            }
            Button("完成") {
                withAnimation(AppAnimation.standard) {
                    isSelecting = false
                    selectedIDs = []
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .accessibilityIdentifier("playlist-select-done")
        }
        .padding(.vertical, 2)
        .addToPlaylistPicker(isPresented: $addSelectionToPlaylist) {
            AddToPlaylistSheet(tracks: selectedTrackList)
        }
    }

    private var selectedTrackList: [Track] {
        model.tracks.filter { selectedIDs.contains($0.id) }
    }

    private func toggleSelectAll() {
        let all = Set(model.tracks.map(\.id))
        if selectedIDs.isSuperset(of: all) { selectedIDs = [] } else { selectedIDs = all }
    }

    private func downloadSelection(_ detail: PlaylistDetail) {
        let tracks = selectedTrackList
        guard !tracks.isEmpty else {
            ToastCenter.shared.show(String(localized: "先选几首"))
            return
        }
        let owner = "playlist:\(playlistID)"
        let name = detail.name
        MeteredDownloadCenter.shared.request(bulk: true, count: tracks.count, network: downloads.network) { metered in
            Task {
                await downloads.enqueue(tracks: tracks, owner: owner, name: name,
                                        quality: SettingsManager.shared.downloadQuality.rawValue,
                                        allowsMetered: metered)
            }
        }
    }

    private func likeSelection() {
        let tracks = selectedTrackList
        guard !tracks.isEmpty else {
            ToastCenter.shared.show(String(localized: "先选几首"))
            return
        }
        guard account.isLoggedIn else {
            ToastCenter.shared.show(String(localized: "登录后才能收藏"))
            return
        }
        Task {
            for track in tracks {
                try? await MusicAPI.likeTrack(id: track.id, like: true)
            }
            await account.refreshLibrary()
            ToastCenter.shared.show(String(localized: "已收藏 \(tracks.count) 首"))
        }
    }

    private func downloadButton(_ detail: PlaylistDetail, compact: Bool = false) -> some View {
        DownloadCollectionButton(tracks: model.tracks, owner: "playlist:\(playlistID)", name: detail.name,
                                 enabled: model.canDownloadAll, compact: compact)
            .accessibilityHint("等待歌单完整加载后下载全部歌曲")
    }

    private var loadingHeader: some View {
        HStack(alignment: .top, spacing: isCompact ? 14 : 24) {
            SkeletonView(cornerRadius: isCompact ? Theme.Radius.standard : Theme.Radius.large)
                .frame(width: isCompact ? 120 : 200, height: isCompact ? 120 : 200)

            VStack(alignment: .leading, spacing: 10) {
                SkeletonView(cornerRadius: 4).frame(width: 80, height: 14)
                SkeletonView(cornerRadius: 4).frame(maxWidth: isCompact ? 160 : 220, minHeight: 14, maxHeight: 14)
                SkeletonView(cornerRadius: 4).frame(width: 120, height: 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, isCompact ? 16 : Theme.Layout.contentInset)
        .padding(.top, isCompact ? 12 : 16)
    }
}

#if os(iOS)
private struct PlaylistLocateButton: View {
    let trackIDs: Set<Int>
    let locate: (Int) -> Void
    @ObservedObject private var player = PlayerService.shared

    private var isVisible: Bool {
        guard let id = player.currentTrack?.id else { return false }
        return trackIDs.contains(id)
    }

    var body: some View {
        // 始终存在，宽度/透明度做动画：定位按钮冒出来时，播放全部胶囊
        // 收缩、右侧按钮左移都是同一帧的连续插值，不会硬跳。
        Button {
            if let id = player.currentTrack?.id, trackIDs.contains(id) { locate(id) }
        } label: {
            LocateGlyph(size: 20, color: Theme.accent)
                .frame(width: 38, height: 38)
                .background(.primary.opacity(0.06), in: Circle())
        }
        .buttonStyle(.pressable)
        .frame(width: isVisible ? 38 : 0)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.7)
        .clipped()
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .accessibilityLabel("定位当前歌曲")
        .accessibilityIdentifier("playlist-locate-current")
        .animation(AppAnimation.standard, value: isVisible)
    }
}
#endif

/// 滚动内容相对 `playlistScroll` 坐标系的 minY。
private struct HeaderStuckKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}


#if os(iOS)
private struct PlaylistDescriptionSheet: View {
    let editable: Bool
    let onDelete: (@MainActor () async throws -> Void)?
    let onSave: @MainActor (String?, Data?) async throws -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var original: String
    @State private var draft: String
    @State private var coverURL: String?
    @State private var selection: PhotosPickerItem?
    @State private var jpeg: Data?
    @State private var busy = false
    @State private var message = ""
    @State private var confirmDeletion = false

    init(detail: PlaylistDetail, editable: Bool, onDelete: (@MainActor () async throws -> Void)?,
         onSave: @escaping @MainActor (String?, Data?) async throws -> String?) {
        self.editable = editable
        self.onDelete = onDelete
        self.onSave = onSave
        _original = State(initialValue: detail.description ?? "")
        _draft = State(initialValue: detail.description ?? "")
        _coverURL = State(initialValue: detail.coverImgUrl)
    }

    var body: some View {
        NavigationStack {
            Group {
                if editable {
                    Form {
                        Section("歌单封面") {
                            HStack {
                                Group {
                                    if let jpeg, let image = UIImage(data: jpeg) {
                                        Image(uiImage: image).resizable().scaledToFill()
                                    } else {
                                        CachedAsyncImage(url: coverURL?.resizedImageURL(128), animated: false)
                                    }
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                PhotosPicker(selection: $selection, matching: .images) {
                                    Text("更换封面")
                                }
                                .disabled(busy)
                            }
                        }
                        Section("歌单简介") {
                            TextEditor(text: $draft)
                                .frame(minHeight: 112)
                                .accessibilityLabel("歌单简介")
                                .disabled(busy)
                        }
                        if busy { ProgressView() }
                        if !message.isEmpty {
                            Text(message).font(.footnote).foregroundStyle(.red)
                        }
                        if onDelete != nil {
                            Section {
                                Button("删除歌单", role: .destructive) { confirmDeletion = true }
                                    .disabled(busy)
                            }
                        }
                    }
                } else {
                    ScrollView { Text(original).padding(20).frame(maxWidth: .infinity, alignment: .leading) }
                }
            }
            .navigationTitle(editable ? "歌单编辑" : "歌单简介")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("确认删除歌单？", isPresented: $confirmDeletion, titleVisibility: .visible) {
                Button("确认删除", role: .destructive) { deletePlaylist() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这会删除网易云音乐上的歌单，无法撤销。")
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") { finish() }.disabled(busy)
                }
            }
        }
        .interactiveDismissDisabled(busy)
        .task(id: selection) {
            guard let selection else { return }
            busy = true
            defer { busy = false }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else {
                    throw MusicAPIError.decoding("Missing cover")
                }
                let prepared = try await Task.detached(priority: .userInitiated) { try Self.squareJPEG(data) }.value
                try Task.checkCancellation()
                jpeg = prepared
                message = ""
            } catch is CancellationError {
            } catch {
                message = "读取图片失败，请换一张照片"
            }
        }
    }

    private func deletePlaylist() {
        guard !busy, let onDelete else { return }
        busy = true
        message = ""
        Task {
            defer { busy = false }
            do { try await onDelete() }
            catch {
                message = error.localizedDescription
            }
        }
    }

    private func finish() {
        guard !busy else { return }
        let description = editable && draft != original ? draft : nil
        let jpeg = editable ? self.jpeg : nil
        guard description != nil || jpeg != nil else { dismiss(); return }
        if let description, description.utf16.count > 1000 {
            message = "歌单简介最多 1000 字符"
            return
        }
        busy = true
        message = ""
        Task {
            defer { busy = false }
            do {
                if let description {
                    _ = try await onSave(description, nil)
                    original = description
                }
                if let jpeg {
                    coverURL = try await onSave(nil, jpeg)
                    self.jpeg = nil
                }
                dismiss()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    nonisolated private static func squareJPEG(_ data: Data) throws -> Data {
        guard data.count <= 30 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 960
              ] as CFDictionary) else { throw MusicAPIError.decoding("Invalid cover image") }
        let side = min(image.width, image.height)
        let rect = CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2,
                          width: side, height: side)
        let output = NSMutableData()
        guard let cropped = image.cropping(to: rect),
              let target = CGImageDestinationCreateWithData(output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw MusicAPIError.decoding("Invalid cover crop") }
        CGImageDestinationAddImage(target, cropped, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
        guard CGImageDestinationFinalize(target), output.length <= 768 * 1024 else {
            throw MusicAPIError.decoding("Cover image too large")
        }
        return output as Data
    }
}
#endif
