import Combine
import SwiftUI

#if os(iOS)
public struct IOSMainWindow: View {
    @StateObject private var player = PlayerService.shared
    @StateObject private var account = AccountStore.shared
    @StateObject private var settings = SettingsManager.shared
    @AppStorage("tabBarShowsLabels") private var showsTabBarLabels = false
    @StateObject private var toasts = ToastCenter.shared
    @StateObject private var artworkStore = NowPlayingArtworkStore()
    @Namespace private var nowPlayingTransition
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase

    /// The app's intended scheme, read on this ancestor so the search-active
    /// tab environment can't invert it (#31).
    private var resolvedColorScheme: ColorScheme {
        settings.appearance.colorScheme ?? systemColorScheme
    }

    @State private var selectedTab: IOSTab = .home
    /// 合并连续切板块时的窗口底色写入（见 scheduleWindowBackgroundRefresh）。
    @State private var windowBackgroundTask: Task<Void, Never>?
    @State private var lyricsOpen = true
    @AppStorage("bottomBarLyrics") private var bottomBarLyrics = true
    @AppStorage("tabOrder") private var tabOrder = "home,fm,explore,search,library"
    @AppStorage("startTab") private var startTab = "library"

    /// Returning from the lock screen every few minutes must not rescan

    /// every download and playlist each time.

    @State private var lastForegroundRefresh: Date?
    @State private var showLogin = false
    @State private var showSettings = false
    @State private var homePath: [Destination] = []
    @State private var explorePath: [Destination] = []
    @State private var fmPath: [Destination] = []
    @State private var searchPath: [Destination] = []
    /// 进入搜索板块之前停留的板块，用于搜索页的关闭按钮。
    @State private var previousTab: IOSTab = .home
    @State private var libraryPath: [Destination] = []
    @State private var iPadPath: [Destination] = []

    public init() {}

    public var body: some View {
        gatedBody
            .tint(Theme.accent)
            .preferredColorScheme(settings.appearance.colorScheme)
    }

    private var gatedBody: some View {
        presentationRoot
            .modifier(OfflinePlaybackAlert(player: player, onDownloads: { openDestination(.downloaded) }, enabled: !player.showNowPlaying))
            .modifier(MeteredDownloadAlert(enabled: !player.showNowPlaying))
            .environmentObject(player)
            .environmentObject(account)
            .environmentObject(settings)
            .environmentObject(toasts)
            .environmentObject(artworkStore)
            .tint(Theme.accent)
            .preferredColorScheme(settings.appearance.colorScheme)
            .environment(\.openLogin, { showLogin = true })
            .environment(\.presentSettingsSheet, { showSettings = true })
            .environment(\.openSearch, openSearch)
            .environment(\.closeSearch, closeSearch)
            .environment(\.openDestination, openDestination)
            .modifier(PlaybackLifecycle())
            .onAppear {
                applyStartupTab()
                lyricsOpen = bottomBarLyrics
            }
            .onChange(of: selectedTab) { tab in
                if tab != .search { previousTab = tab }
            }
            .onChange(of: bottomBarLyrics) { new in lyricsOpen = new }
            .onChange(of: settings.homeSectionVisibility) { _ in ensureVisibleTab() }
            .onChange(of: tabOrder) { _ in ensureVisibleTab() }
            .task {
                await DownloadManager.shared.start()
                await account.bootstrap()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                if let last = lastForegroundRefresh, Date().timeIntervalSince(last) < 300 { return }
                lastForegroundRefresh = Date()
                Task {
                    await DownloadManager.shared.refreshLibrary()
                    if DownloadManager.shared.network.connected { await account.refreshLibrary() }
                }
            }
            .task(id: settings.showMainWindowAmbientBackground) {
                artworkStore.setArtworkNeeded(settings.showMainWindowAmbientBackground)
            }
            // Presented here rather than from the Library tab or the iPad
            // sidebar: a sheet hosted inside the tab view is re-hosted when
            // the tabs update, which reset its navigation (#191 review).
            .sheet(isPresented: $showSettings) {
                // Outside the modifiers above, so hand the sheet the same
                // environment the rest of the app gets.
                SettingsSheet(
                    titleDisplayMode: UIDevice.current.userInterfaceIdiom == .pad ? .inline : .automatic
                )
                .environmentObject(player)
                .environmentObject(account)
                .environmentObject(settings)
                .environmentObject(toasts)
                .environmentObject(artworkStore)
                .tint(Theme.accent)
                .preferredColorScheme(settings.appearance.colorScheme)
                .environment(\.openLogin, { showLogin = true })
                .environment(\.openDestination, openDestination)
            }
            .sheet(isPresented: $showLogin) {
                LoginSheet()
                    .environmentObject(account)
                    .environmentObject(toasts)
            }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    if let toast = toasts.current {
                        ToastView(toast: toast)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if !player.hasCurrentTrack {
                        PlaybackHandoffBanner()
                    }
                }
                .padding(.top, 8)
            }
            .animation(.spring(duration: 0.3), value: toasts.current)
            .animation(.spring(duration: 0.35), value: player.hasCurrentTrack)
    }

    @ViewBuilder
    private var presentationRoot: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            if #available(iOS 18.0, *) {
                zoomNowPlayingRoot
            } else {
                // iOS 16/17 used to slide the page up in place, inside a
                // ZStack over the tabs. On iOS 17 that transition could stop
                // part way, leaving the page stuck short of the top (#213), so
                // these systems use the system cover too. Without the zoom
                // there is no system swipe to close it, so the page keeps its
                // own pull-down; what it uncovers is the cover's backdrop.
                systemNowPlayingRoot(usesSystemInteractiveDismissal: false)
            }
        } else {
            systemNowPlayingRoot(usesSystemInteractiveDismissal: true)
        }
    }

    private func systemNowPlayingRoot(usesSystemInteractiveDismissal: Bool) -> some View {
        appContent
            .fullScreenCover(isPresented: $player.showNowPlaying) {
                systemNowPlayingPresentation(
                    usesSystemInteractiveDismissal: usesSystemInteractiveDismissal
                )
            }
    }

    @available(iOS 18.0, *)
    private var zoomNowPlayingRoot: some View {
        appContent
            .fullScreenCover(isPresented: $player.showNowPlaying) {
                systemNowPlayingPresentation(usesSystemInteractiveDismissal: true)
                    .navigationTransition(
                        .zoom(
                            sourceID: NowPlayingTransitionID.surface,
                            in: nowPlayingTransition
                        )
                    )
            }
    }

    @ViewBuilder
    private func systemNowPlayingPresentation(usesSystemInteractiveDismissal: Bool) -> some View {
        // A clear cover background sends iOS 17 into an endless layout pass
        // over the page: the cover never comes up and the app freezes at
        // full CPU (#213, reproduced on the iOS 17.5 simulator). Earlier
        // systems keep the cover's own background.
        if #available(iOS 18.0, *) {
            nowPlayingPresentation(usesSystemInteractiveDismissal: usesSystemInteractiveDismissal)
                .presentationBackground(.clear)
        } else {
            nowPlayingPresentation(usesSystemInteractiveDismissal: usesSystemInteractiveDismissal)
        }
    }

    @ViewBuilder
    private var appContent: some View {
        if UIDevice.current.userInterfaceIdiom == .pad, !settings.onlyLibrarySection {
            MainWindow(path: $iPadPath)
        } else {
            tabInterface
                .overlay {
                    if settings.showMainWindowAmbientBackground {
                        MainWindowAmbientBackground(
                            colors: artworkStore.colors,
                            intensity: settings.mainWindowAmbientBackgroundIntensity
                        )
                        .ignoresSafeArea()
                    }
                }
        }
    }

    private func nowPlayingPresentation(usesSystemInteractiveDismissal: Bool) -> some View {
        // The cover animates its own way out; a SwiftUI animation would only
        // be layered on top of it.
        IOSNowPlayingPresentation(
            isPresented: $player.showNowPlaying,
            mode: settings.nowPlayingMode,
            usesSystemInteractiveDismissal: usesSystemInteractiveDismissal,
            dismissAnimation: nil
        ) {
            NowPlayingView(onOpenDestination: openDestination)
                .environmentObject(player)
                .environmentObject(account)
                .environmentObject(settings)
        }
        .modifier(NowPlayingLoginPresenter())
        // A fullScreenCover sits above the root toast overlay, so re-host the
        // same ToastCenter on the page (#182).
        .overlay(alignment: .top) {
            if let toast = toasts.current {
                ToastView(toast: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: toasts.current)
        .environmentObject(toasts)
    }

    @ViewBuilder
    private var tabInterface: some View {
        // 自定义胶囊；不再用 iOS 26 的合并 accessory。
        customTabInterface
    }

    /// Attach the bottom mini-player accessory only when something is playing.
    /// Leaving the modifier on with empty content still renders an empty,
    /// translucent accessory platter above the tab bar when idle (#35), so we
    /// apply it conditionally.
    @available(iOS 26.0, *)
    private var iOS26TabInterface: some View {
        iOS26TabView
            .tabBarMinimizeBehavior(.onScrollDown)
            // Apply the accessory through a ViewModifier so the TabView keeps a
            // single identity across the hasCurrentTrack toggle. An if/else here
            // churns the TabView identity, which detaches the accessory's
            // matchedTransitionSource and makes the now-playing zoom anchor at
            // the screen centre (#57); not applying it when idle keeps the empty
            // accessory platter gone (#35).
            .modifier(MiniPlayerAccessoryModifier(
                isActive: player.hasCurrentTrack,
                transitionNamespace: nowPlayingTransition,
                colorScheme: resolvedColorScheme
            ))
            .animation(AppAnimation.standard, value: player.hasCurrentTrack)
    }

    @available(iOS 26.0, *)
    private var iOS26TabView: some View {
        TabView(selection: $selectedTab) {
            if settings.showHome {
                Tab("推荐", systemImage: "house", value: .home) {
                    tabStack(.home) { HomeView() }.tint(Theme.accent)
                }
            }

            if settings.showExplore {
                Tab("精选", systemImage: "square.grid.2x2", value: .explore) {
                    tabStack(.explore) { ExploreView() }.tint(Theme.accent)
                }
            }

            Tab("漫游", systemImage: "wave.3.right.circle", value: .fm) {
                tabStack(.fm) { FMView() }.tint(Theme.accent)
            }

            Tab("我的", systemImage: "person", value: .library) {
                tabStack(.library) { IOSLibraryView(showLogin: $showLogin) }.tint(Theme.accent)
            }

            if settings.showSearch {
                Tab("搜索", systemImage: "magnifyingglass", value: .search) {
                    tabStack(.search) { SearchView(query: "") }.tint(Theme.accent)
                }
            }
        }
        .tint(resolvedColorScheme == .dark ? .white : .black)
    }

    private var customTabInterface: some View {
        GeometryReader { geo in
            let horizontal = geo.size.width > geo.size.height && geo.size.width >= 500
                && player.hasCurrentTrack && (lyricsOpen || !settings.onlyLibrarySection)
            let layout = horizontal
                ? AnyLayout(HStackLayout(spacing: 10))
                : AnyLayout(VStackLayout(spacing: 8))
            let playerWidth = min(336, max(218, (geo.size.width - 24) * 0.38))
            let barHeight: CGFloat = 64

            ZStack(alignment: .bottom) {
                ZStack {
                    if settings.showHome {
                        page(.home) { tabStack(.home) { HomeView() } }
                    }
                    if settings.showExplore {
                        page(.explore) { tabStack(.explore) { ExploreView() } }
                    }
                    page(.fm) { tabStack(.fm) { FMView() } }
                    if settings.showSearch {
                        page(.search) { tabStack(.search) { SearchView(query: "") } }
                    }
                    page(.library) { tabStack(.library) { IOSLibraryView(showLogin: $showLogin) } }
                }
                // 顶栏靠这个判断要不要换成渐进模糊；这里只取几何方向，和底栏
                // 的 `horizontal`（还要求有正在播放的歌）解耦。
                .environment(\.isLandscapeWindow, geo.size.width > geo.size.height && geo.size.width >= 500)

                layout {
                    if player.hasCurrentTrack {
                        IOSMiniPlayerBar(presentation: .legacyOverlay, overlayHeight: horizontal ? barHeight : nil)
                            .nowPlayingTransitionSource(in: nowPlayingTransition)
                            .frame(width: horizontal ? playerWidth : nil)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    GeometryReader { bottom in
                        // 底栏展开状态关在这一层：动画帧只重画底栏，不再带着
                        // 上面四个板块的页面一起重算（卡死根因）。
                        BottomBarSlot { expanded, morphing in
                            bottomBar(width: bottom.size.width,
                                      tabBarExpanded: expanded,
                                      morphing: morphing)
                        }
                    }
                    .frame(height: barHeight)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            // 整屏底色：横屏左右两条安全区（刘海/圆角那两块）露的是窗口色，
            // 铺一层当前 tab 的底色并 ignore 安全区，才能和页面里一致。
            .background(pageBackground(selectedTab).ignoresSafeArea())
        }
        .animation(AppAnimation.standard, value: player.hasCurrentTrack)
        #if os(iOS)
        .onAppear { applyWindowBackground() }
        .onChange(of: selectedTab) { _ in scheduleWindowBackgroundRefresh() }
        #endif
    }

    /// The bottom row, laid out the way Android's `.bar-row` does it. The two
    /// slots have complementary widths that add up to the row, so they animate
    /// against each other: one grows exactly as much as the other shrinks.
    /// Nothing is clipped and nothing is given a shadow here — the frames
    /// describe the layout, and each glass shape is drawn at its own width, so
    /// its rounded ends survive the morph.
    private func bottomBar(width: CGFloat,
                           tabBarExpanded tabsExpanded: Binding<Bool>,
                           morphing: Bool) -> some View {
        let setExpanded: (Bool) -> Void = { tabsExpanded.wrappedValue = $0 }
        let hasTrack = player.hasCurrentTrack
        let showsNav = !settings.onlyLibrarySection
        let lyricSlot = lyricsOpen && hasTrack
        // Android: the avatar only ever replaces the strip in the lyric state
        // (`lyricsBar && t && !tabsExpanded`). With no lyric strip there is
        // nothing to fold into, so the strip is what shows — and, being the
        // only thing in the row, it sits centred.
        let expanded = showsNav && (tabsExpanded.wrappedValue || !lyricSlot)
        let folded = showsCollapsedLyric(tabBarExpanded: tabsExpanded.wrappedValue)

        // Android: `.tab-row{flex:0 0 auto}` keeps the pill at the width its
        // labels ask for; with the lyrics open it collapses to the avatar's
        // 64pt, and with four or more tabs the strip folds to its「词」circle.
        let navWidth: CGFloat = {
            guard showsNav else { return 0 }
            guard lyricSlot else { return min(intrinsicTabWidth, width) }
            if expanded {
                return folded ? max(0, width - 74) : min(intrinsicTabWidth, max(0, width - 74))
            }
            return 64
        }()

        let lyricWidth: CGFloat = {
            guard lyricSlot else { return 0 }
            guard showsNav else { return width }
            return max(0, width - navWidth - 10)
        }()

        // 展开后的目标宽度。标签胶囊按这个宽度排版，胶囊本身再跟着动画长出来，
        // 这样每一帧都不需要重排图标，也就不会出现从屏幕外滑进来的残影。
        let navTargetWidth: CGFloat = {
            guard showsNav else { return 0 }
            guard lyricSlot else { return min(intrinsicTabWidth, width) }
            return folded ? max(0, width - 74) : min(intrinsicTabWidth, max(0, width - 74))
        }()

        // A persistent glass shell avoids crossfading two material snapshots during collapse.
        return HStack(spacing: 10) {
            if lyricSlot {
                ZStack(alignment: .leading) {
                    LyricStripPill(morphing: morphing)
                        .opacity(folded ? 0 : 1)
                        .animation(nil, value: folded)
                        .contentShape(Rectangle())
                        .onTapGesture { setExpanded(false) }
                        .allowsHitTesting(!folded && tabsExpanded.wrappedValue)

                    collapsedLyricButton(setExpanded: setExpanded)
                        .opacity(folded ? 1 : 0)
                        .animation(nil, value: folded)
                        .allowsHitTesting(folded)
                }
                .frame(width: lyricWidth, height: 64, alignment: .leading)
                // 宽度动画期间只保留胶囊内的内容，别画到屏幕边上。
                .clipShape(Capsule(style: .continuous))
                .nativeGlassCapsule()
            }

            if showsNav {
                // 展开和收起走同一套布局：标签条一直按「展开后的目标宽度」排好，
                // 胶囊只负责把它露出来或盖回去，头像则在原地淡入淡出。
                // 这样两个方向都不需要插入/移除动画，也不会逐帧重排图标。
                ZStack(alignment: .trailing) {
                    tabBar(compact: true)
                        .frame(width: navTargetWidth, height: 64, alignment: .trailing)
                        .opacity(expanded ? 1 : 0)
                        .allowsHitTesting(expanded)

                    avatarButton(setExpanded: setExpanded)
                        .opacity(expanded ? 0 : 1)
                        .allowsHitTesting(!expanded)
                }
                .frame(width: navWidth, height: 64, alignment: .trailing)
                .clipShape(Capsule(style: .continuous))
                .nativeGlassCapsule()
            }
        }
        // Without a lyric strip the row holds the tab pill alone; it stays
        // centred the way it was before the strip existed, as on Android.
        .frame(width: width, alignment: lyricSlot ? .leading : .center)
        .animation(barAnimation, value: tabsExpanded.wrappedValue)
        .animation(barAnimation, value: lyricsOpen)
        .animation(barAnimation, value: hasTrack)
        .animation(barAnimation, value: folded)
    }

    /// With four or more tabs the strip has no room left: it folds into a
    /// round「词」button, and tapping it brings the strip back.
    private func collapsedLyricButton(setExpanded: @escaping (Bool) -> Void) -> some View {
        Button {
            setExpanded(false)
        } label: {
            Text("词")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 64, height: 64)
                .overlay {
                    Circle().strokeBorder(.white.opacity(resolvedColorScheme == .dark ? 0.08 : 0.22), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("展开歌词")
    }

    /// Four or more tabs leave no width for the strip: it folds into a round
    /// 「词」button and the pair packs to the right, 10pt apart.
    private func showsCollapsedLyric(tabBarExpanded: Bool) -> Bool {
        lyricsOpen && player.hasCurrentTrack && tabBarExpanded
            && !settings.onlyLibrarySection && visibleTabItems.count >= 4
    }

    private func tabBar(compact: Bool) -> some View {
        GlassTabBar(items: visibleTabItems, selection: $selectedTab) { tab in
            popToRoot(tab)
        }
        // Compact pill next to the「词」circle stretches to fill what is left;
        // the normal bar keeps the width its labels ask for.
        .frame(maxWidth: compact ? .infinity : nil)
        .frame(width: compact ? nil : min(UIScreen.main.bounds.width - 48,
                                         CGFloat(visibleTabItems.count) * (showsTabBarLabels ? 56 : 48)
                                           + (showsTabBarLabels ? 104 : 88)))
    }

    /// Bottom bar morph，与安卓端 360ms cubic-bezier(.32,.72,0,1) 一致。
    private var barAnimation: Animation {
        .timingCurve(0.32, 0.72, 0, 1, duration: 0.36)
    }

    /// 标签胶囊按文案要的宽度，和布局解耦后用来算展开态的分配。
    private var intrinsicTabWidth: CGFloat {
        min(UIScreen.main.bounds.width - 48,
            CGFloat(max(visibleTabItems.count, 1)) * (showsTabBarLabels ? 56 : 48)
              + (showsTabBarLabels ? 104 : 88))
    }

    /// The collapsed nav: the user's avatar in a glass circle. Tapping it brings
    /// the tab bar back; tapping the lyric strip on the left puts it away again.
    private func avatarButton(setExpanded: @escaping (Bool) -> Void) -> some View {
        Button {
            setExpanded(true)
        } label: {
            ZStack {
                Circle().fill(.clear)
                if let only = singleTabIcon {
                    Image(systemName: only)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else if let raw = account.profile?.avatarUrl, let url = URL(string: raw) {
                    CachedAsyncImage(url: url, animated: false) {
                        Color.clear
                    }
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(Circle())
            .frame(width: 64, height: 64)
            .overlay {
                Circle().strokeBorder(.white.opacity(resolvedColorScheme == .dark ? 0.08 : 0.22), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("展开导航")
    }

    /// 只开一个板块且不是「我的」时，收起态直接显示该板块图标
    private var singleTabIcon: String? {
        guard visibleTabItems.count == 1, let only = visibleTabItems.first, only.tab != .library else { return nil }
        return only.icon
    }

    private func isTabEnabled(_ tab: IOSTab) -> Bool {
        switch tab {
        case .home: return settings.showHome
        case .explore: return settings.showExplore
        case .fm: return true
        case .search: return settings.showSearch
        case .library: return settings.showLibrary
        }
    }

    private var visibleTabItems: [GlassTabBar.Item] {
        let enabled = Self.tabItems.filter { isTabEnabled($0.tab) }
        guard !enabled.isEmpty else { return Self.tabItems.filter { $0.tab == .library } }
        let order = tabOrder.split(separator: ",").map(String.init)
        func rank(_ tab: IOSTab) -> Int {
            let i = order.firstIndex(of: tab.rawValue)
            return i ?? order.count + 1
        }
        return enabled.sorted { rank($0.tab) < rank($1.tab) }
    }

    private func ensureVisibleTab() {
        let visible = visibleTabItems
        if !visible.contains(where: { $0.tab == selectedTab }) {
            selectedTab = visible.first?.tab ?? .library
        }
    }

    /// 冷启动板块：auto 取第一个可用板块
    private func applyStartupTab() {
        ensureVisibleTab()
        let want = IOSTab(rawValue: startTab)
        if let want, visibleTabItems.contains(where: { $0.tab == want }) { selectedTab = want }
    }

    private func popToRoot(_ tab: IOSTab) {
        switch tab {
        case .home: homePath = []
        case .explore: explorePath = []
        case .fm: fmPath = []
        case .search: searchPath = []
        case .library: libraryPath = []
        }
    }

    /// 「我的」页工具条里的搜索按钮：切到搜索板块并回到它的根页。
    private func openSearch() {
        player.showNowPlaying = false
        if settings.showSearch {
            searchPath = []
            selectedTab = .search
        } else {
            // 搜索板块被关掉时 /search 路由不存在，改成在「我的」里推一层。
            libraryPath.appendIfNotCurrent(.search(""))
        }
    }

    /// 搜索页右上角的关闭按钮：有下钻就先退回搜索根页，否则回到上一个板块。
    private func closeSearch() {
        player.showNowPlaying = false
        if !searchPath.isEmpty {
            searchPath = []
            return
        }
        if case .search = libraryPath.last {
            libraryPath.removeLast()
            return
        }
        // 上一个板块可能已经关掉，甚至只剩「搜索」一个板块：这时落到
        // 仍然可见的板块，都没有就回「我的」（它始终存在）。
        let visible = visibleTabItems.map(\.tab).filter { $0 != .search }
        if visible.contains(previousTab) {
            selectedTab = previousTab
        } else if let fallback = visible.first {
            selectedTab = fallback
        } else {
            selectedTab = .library
        }
    }

    private func openDestination(_ destination: Destination) {
        player.showNowPlaying = false
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadPath.appendIfNotCurrent(destination)
            return
        }

        let path = binding(for: selectedTab)
        var destinations = path.wrappedValue
        destinations.appendIfNotCurrent(destination)
        path.wrappedValue = destinations
    }

    @ViewBuilder
    private func tabStack<Content: View>(
        _ tab: IOSTab,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        NavigationStack(path: binding(for: tab)) {
            content()
                .appDestinations()
                // 导航栈内部自己会铺一层白底，横屏时导航栏那一条就是它露出来的；
                // 在这里铺同色底，顶栏区域才和页面同色（模糊仍叠在上面）。
                .background(pageBackground(tab).ignoresSafeArea())
                .progressiveTopBarInLandscape()
        }
        .publishesWindowHorizontalInsets()
    }

    /// 每个 tab 自己的底色。横屏时左右两条安全区露的就是窗口底色，
    /// 必须和页面本身同色才不会出现「两侧一条别的灰/白」。
    /// 「我的」是 grouped List（灰），其余页是普通 ScrollView（白）。
    #if os(iOS)
    /// 窗口本身的底色。SwiftUI 的 `.background` 铺不到的角落（圆角、
    /// 刘海两侧、横屏左右两条安全区）露的就是这一层，必须跟着当前 tab 走。
    private func applyWindowBackground() {
        let color = UIColor(pageBackground(selectedTab))
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where !colorsMatch(window.backgroundColor, color) {
                window.backgroundColor = color
            }
        }
    }

    /// 只有四个 tab 分两种底色（「我的」是分组灰，其余白），
    /// 大部分切换其实不需要动窗口——写一次就会让整窗失效、底栏玻璃重采样一次。
    private func colorsMatch(_ a: UIColor?, _ b: UIColor) -> Bool {
        guard let a else { return false }
        var ra: CGFloat = 0, ga: CGFloat = 0, ba: CGFloat = 0, aa: CGFloat = 0
        var rb: CGFloat = 0, gb: CGFloat = 0, bb: CGFloat = 0, ab: CGFloat = 0
        guard a.getRed(&ra, green: &ga, blue: &ba, alpha: &aa),
              b.getRed(&rb, green: &gb, blue: &bb, alpha: &ab) else { return a == b }
        return abs(ra - rb) < 0.002 && abs(ga - gb) < 0.002 && abs(ba - bb) < 0.002 && abs(aa - ab) < 0.002
    }

    /// 连续切板块时把窗口底色合并成一次：切 5 下只写 1 次，避免每次切换都整窗失效。
    private func scheduleWindowBackgroundRefresh() {
        windowBackgroundTask?.cancel()
        windowBackgroundTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }
            applyWindowBackground()
        }
    }
    #endif

    private func pageBackground(_ tab: IOSTab) -> Color {
        #if os(iOS)
        tab == .library ? Color(uiColor: .systemGroupedBackground) : Platform.windowBackgroundColor
        #else
        Platform.windowBackgroundColor
        #endif
    }

    private func page<Content: View>(
        _ tab: IOSTab,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            // 铺到安全区外：横屏左右那两条和界面内同色。
            .background(pageBackground(tab).ignoresSafeArea())
            .environment(\.pageBaseColor, pageBackground(tab))
            .opacity(selectedTab == tab ? 1 : 0)
            .allowsHitTesting(selectedTab == tab)
            .zIndex(selectedTab == tab ? 1 : 0)
    }

    private func binding(for tab: IOSTab) -> Binding<[Destination]> {
        switch tab {
        case .home: return $homePath
        case .explore: return $explorePath
        case .fm: return $fmPath
        case .search: return $searchPath
        case .library: return $libraryPath
        }
    }
}

enum IOSTab: String, Hashable {
    case home, explore, fm, search, library
}

extension IOSMainWindow {
    static let tabItems: [GlassTabBar.Item] = [
        .init(tab: .home, title: "推荐", icon: "house"),
        .init(tab: .explore, title: "精选", icon: "square.grid.2x2"),
        .init(tab: .fm, title: "漫游", icon: "dot.radiowaves.left.and.right"),
        .init(tab: .search, title: "搜索", icon: "magnifyingglass"),
        .init(tab: .library, title: "我的", icon: "person"),
    ]
}

/// 底栏展开/收起状态的家。
///
/// 它原来是 `IOSMainWindow` 的 `@State`，而四个板块的页面
/// （`page(.home)/.explore/.search/.library`）与底栏在同一个 body 里。
/// 于是底栏每动画一帧，四个页面 body 全部跟着重算一遍；连续点开合就把
/// 主线程排满，表现为整个 App 卡死。把状态下放到这一层之后，动画帧只会
/// 重画底栏本身。
private struct BottomBarSlot<Content: View>: View {
    @State private var expanded = false
    /// 一次 morph 的时长。玻璃要按新宽度重采样、歌词要重排，
    /// 两条动画叠在同一层上时单帧工作量是单条的几倍。
    private let morphDuration: Double = 0.36

    /// 「最后一步说话」：新动作立刻打断上一次——取消它的收尾任务、
    /// 把目标改成新值（SwiftUI 让同一条属性动画重定向，不会叠出新轨），
    /// 收尾任务结束就自己清空，之后不再有任何残留工作。
    @State private var morphTask: Task<Void, Never>?
    /// 机械抖动保护：同一瞬间的重复触摸直接丢弃。
    @State private var lastRequestAt = Date.distantPast
    /// 正在形变的这 0.36 秒。底栏里的逐字擦亮要知道，
    /// 免得和「玻璃按新宽度重采样」抢同一帧。
    @State private var isMorphing = false

    let content: (Binding<Bool>, Bool) -> Content

    var body: some View {
        content(Binding(get: { expanded },
                        set: { next in request(next) }),
                isMorphing)
    }

    private func request(_ next: Bool) {
        guard next != expanded else { return }
        let now = Date()
        guard now.timeIntervalSince(lastRequestAt) > 0.02 else { return }
        lastRequestAt = now

        // 打断上一次：它挂的收尾任务立刻作废，本次动作独立成立。
        morphTask?.cancel()

        // 形变期间把底栏里的逐字擦亮停掉（见 LyricStripPill.morphing）。
        isMorphing = true
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: morphDuration)) {
            expanded = next
        }

        morphTask = Task { @MainActor in
            let ns = UInt64((morphDuration + 0.02) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            // 本次动作彻底结束：清掉收尾任务、放开擦亮，后续不再有任何残留工作。
            isMorphing = false
            morphTask = nil
        }
    }
}

private enum NowPlayingTransitionID {
    static let surface = "now-playing-surface"
}

/// Login requested from the player must be presented by the player itself:
/// the main window is already presenting its full-screen cover on iOS 18+.
/// Keeping this state here also makes cancellation return to the same player.
private struct NowPlayingLoginPresenter: ViewModifier {
    @EnvironmentObject private var account: AccountStore
    @State private var showLogin = false

    func body(content: Content) -> some View {
        content
            .environment(\.openLogin, { showLogin = true })
            .sheet(isPresented: $showLogin) {
                LoginSheet()
                    .environmentObject(account)
            }
    }
}

// MARK: - Mini player bar for iOS

@available(iOS 26.0, *)
private struct MiniPlayerAccessoryModifier: ViewModifier {
    let isActive: Bool
    let transitionNamespace: Namespace.ID
    let colorScheme: ColorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive {
            content.tabViewBottomAccessory {
                IOSMiniPlayerAccessory(transitionNamespace: transitionNamespace)
                    // Pin the scheme so the search-active tab environment
                    // doesn't flip the bar's text to white (#31).
                    .environment(\.colorScheme, colorScheme)
            }
        } else {
            content
        }
    }
}

@available(iOS 26.0, *)
private struct IOSMiniPlayerAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @State private var lastKnownPlacementIsInline: Bool?
    let transitionNamespace: Namespace.ID

    var body: some View {
        IOSMiniPlayerBar(presentation: presentation)
            // Match the complete system accessory, never only its artwork.
            .nowPlayingTransitionSource(in: transitionNamespace)
            .onChange(of: placementIsInline, initial: true) { _, isInline in
                if let isInline { lastKnownPlacementIsInline = isInline }
            }
    }

    private var placementIsInline: Bool? {
        placement.map { $0 == .inline }
    }

    private var presentation: IOSMiniPlayerBar.Presentation {
        NowPlayingPresentationMetrics.shouldUseInlineMiniPlayerLayout(
            placementIsInline: placementIsInline,
            lastKnownPlacementIsInline: lastKnownPlacementIsInline
        ) ? .inlineAccessory : .bottomAccessory
    }
}

private extension View {
    @ViewBuilder
    func nowPlayingTransitionSource(in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(
                id: NowPlayingTransitionID.surface,
                in: namespace
            )
        } else {
            // Pre-18 slides the full-screen cover up; there is no zoom to
            // pair with.
            self
        }
    }
}

/// Renders mini-player content inside either a system-owned tab accessory or
/// the material-backed compatibility overlay used before iOS 26.
///
/// Do not add a background for `bottomAccessory` or `inlineAccessory`: the
/// tab view owns their Liquid Glass surface and adding another material creates
/// a visibly nested card.
struct IOSMiniPlayerBar: View {
    enum Presentation {
        case bottomAccessory
        case inlineAccessory
        case legacyOverlay

        var isInline: Bool { self == .inlineAccessory }
        var drawsBackground: Bool { self == .legacyOverlay }
    }

    @EnvironmentObject private var player: PlayerService
    @Environment(\.colorScheme) private var colorScheme
    let presentation: Presentation
    var overlayHeight: CGFloat? = nil
    var onToggleLyrics: (() -> Void)?

    var body: some View {
        playerBarSurface
            .simultaneousGesture(expandGesture)
    }

    @ViewBuilder
    private var playerBarSurface: some View {
        if presentation.drawsBackground {
            // Same surface as the tab bar pill so the two read as one glass family.
            //
            // No `.shadow` here: Liquid Glass is composited by the system in its
            // own layer, and a SwiftUI shadow is rebuilt from that layer's alpha.
            // When the now-playing zoom cover dismisses, the glass re-samples its
            // backdrop every frame, so the shadow drops and pops back — the black
            // halo the player bar had was flickering, not shading. The tab pill
            // never had one; the blur and the hairline are the separation.
            content
                .frame(height: overlayHeight)
                .nativeGlassCapsule()
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.22),
                                      lineWidth: 0.5)
                }
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 4) {
            summarySlot
                .accessibilityIdentifier("mini-player-now-playing")


            if !presentation.isInline {
                Button(action: player.previous) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("上一首")
            }

            Button(action: player.togglePlayPause) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(player.isPlaying ? "暂停" : "播放")

            if !presentation.isInline {
                Button(action: player.next) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("下一首")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    private var summarySlot: some View {
        Button(action: showNowPlaying) {
            trackSummary(for: player.currentTrack)
        }
        .buttonStyle(.plain)
        .frame(height: artworkSize)
        .accessibilityLabel(nowPlayingAccessibilityLabel)
        .accessibilityHint("打开正在播放")
    }

    private func trackSummary(for track: Track?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            CachedAsyncImage(url: track?.album.picUrl?.resizedImageURL(128))
                .frame(
                    width: artworkSize,
                    height: artworkSize
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 1)

            VStack(alignment: .leading, spacing: metadataSpacing) {
                Text(track?.name ?? "")
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(track?.artistNames ?? "")
                    .font(artistFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(track == nil ? 0 : 1)
    }

    private var artworkSize: CGFloat {
        presentation.isInline ? 28 : 32
    }

    private var titleFont: Font {
        .system(size: presentation.isInline ? 10 : 13, weight: .semibold)
    }

    private var artistFont: Font {
        .system(size: presentation.isInline ? 8 : 10)
    }

    private var metadataSpacing: CGFloat {
        presentation.isInline ? 2 : 3
    }

    private var nowPlayingAccessibilityLabel: String {
        let title = player.currentTrack?.name ?? String(localized: "正在播放")
        guard let artist = player.currentTrack?.artistNames, !artist.isEmpty else {
            return title
        }
        return "\(title)，\(artist)"
    }

    private var expandGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                guard NowPlayingPresentationMetrics.shouldExpandFromMiniPlayer(
                    translation: value.translation.height,
                    predictedTranslation: value.predictedEndTranslation.height
                ) else { return }
                showNowPlaying()
            }
    }

    private func showNowPlaying() {
        player.showNowPlaying = true
    }
}

// MARK: - iOS Library View

struct IOSLibraryView: View {
    @AppStorage("librarySearchButton") private var librarySearchButton = true
    @Binding var showLogin: Bool
    @EnvironmentObject private var account: AccountStore
    @AppStorage("libraryOrder") private var libraryOrder = "liked,daily,recents,collections,downloads,cloud"
    @AppStorage("libraryShowsLiked") private var libraryShowsLiked = true
    @AppStorage("libraryShowsDaily") private var libraryShowsDaily = true
    @AppStorage("libraryShowsRecents") private var libraryShowsRecents = true
    @AppStorage("libraryShowsCollections") private var libraryShowsCollections = true
    @AppStorage("libraryShowsDownloads") private var libraryShowsDownloads = true
    @AppStorage("libraryShowsCloud") private var libraryShowsCloud = true
    @AppStorage("libraryShowsCreatedPlaylists") private var libraryShowsCreatedPlaylists = true
    @AppStorage("libraryShowsCollectedPlaylists") private var libraryShowsCollectedPlaylists = true

    /// “我的音乐”那一组行的顺序与开关，读的是设置里同一批 AppStorage 键。
    private var libraryRowOrder: [String] {
        let all = ["liked", "daily", "recents", "collections", "downloads", "cloud"]
        let order = libraryOrder.split(separator: ",").map(String.init)
        return all
            .sorted { (order.firstIndex(of: $0) ?? 99) < (order.firstIndex(of: $1) ?? 99) }
            .filter(libraryRowEnabled)
    }

    private func libraryRowEnabled(_ key: String) -> Bool {
        switch key {
        case "liked": return libraryShowsLiked
        case "daily": return libraryShowsDaily
        case "recents": return libraryShowsRecents
        case "collections": return libraryShowsCollections
        case "downloads": return libraryShowsDownloads
        case "cloud": return libraryShowsCloud
        default: return true
        }
    }

    @ViewBuilder
    private func libraryRow(_ key: String) -> some View {
        switch key {
        case "liked":
            if let liked = account.likedSongsPlaylist {
                NavigationLink(value: Destination.playlist(liked.id)) {
                    Label("我喜欢的音乐", systemImage: "heart.fill")
                        .foregroundStyle(Theme.accent)
                }
            }
        case "daily":
            NavigationLink(value: Destination.daily) {
                Label("每日推荐", systemImage: "calendar")
            }
        case "recents":
            NavigationLink(value: Destination.recents) {
                Label("最近播放", systemImage: "clock.fill")
            }
        case "collections":
            NavigationLink(value: Destination.collections) {
                Label("我的收藏", systemImage: "star.fill")
            }
        case "downloads":
            NavigationLink(value: Destination.downloaded) {
                Label("我的下载", systemImage: "arrow.down.circle.fill")
            }
        case "cloud":
            NavigationLink(value: Destination.cloud) {
                Label("音乐云盘", systemImage: "icloud.fill")
            }
        default:
            EmptyView()
        }
    }

    @Environment(\.presentSettingsSheet) private var presentSettingsSheet
    @Environment(\.openSearch) private var openSearch
    @EnvironmentObject private var settings: SettingsManager
    @State private var showNewPlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        Group {
            #if os(iOS)
            GeometryReader { geo in
                if HomeView.splitsLandscape(geo.size) {
                    // 横屏：左栏用户信息 + 我的音乐，右栏创建/收藏的歌单，
                    // 两栏各是独立 List，滚动互不影响（与「推荐」页同一套判断）。
                    HStack(alignment: .top, spacing: 0) {
                        libraryList(columns: .left)
                            .frame(width: Self.libraryColumnWidth(in: geo.size))
                        libraryList(columns: .right)
                    }
                } else {
                    libraryList(columns: .all)
                }
            }
            #else
            libraryList(columns: .all)
            #endif
        }
        .navigationTitle("我的")
        .toolbar {
            // 两个按钮放进同一个分组，系统才会把它们并排靠在一起；
            // 分两条 ToolbarItem 会被拉开成左右两端。
            // 搜索按钮只受设置里的「我的页搜索按钮」控制，与底栏「搜索」板块
            // 的开关无关；两个按钮放进同一个 HStack，间距由这里定。
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if librarySearchButton {
                        Button {
                            openSearch()
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel("搜索音乐")
                    }
                    Button {
                        presentSettingsSheet()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                }
            }
        }
        .alert("新建歌单", isPresented: $showNewPlaylist) {
            TextField("歌单名称", text: $newPlaylistName)
            Button("创建") {
                let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                newPlaylistName = ""
                guard !name.isEmpty else { return }
                Task {
                    do {
                        try await MusicAPI.createPlaylist(name: name, isPrivate: false)
                        await account.refreshLibrary()
                        ToastCenter.shared.show(String(localized: "歌单已创建"))
                    } catch {
                        ToastCenter.shared.show(error.localizedDescription)
                    }
                }
            }
            Button("取消", role: .cancel) { newPlaylistName = "" }
        }
    }

    /// 左栏宽度 = 底栏播放器胶囊的右边缘，和安卓端 `--player-edge` 同一条公式。
    static func libraryColumnWidth(in size: CGSize) -> CGFloat {
        12 + min(336, max(218, (size.width - 24) * 0.38))
    }

    @ViewBuilder
    private func libraryList(columns: HomeColumn) -> some View {
        List {
            // Profile / Login header
            if columns != .right { Section {
                SyncedLoginButtons()
                if let profile = account.profile {
                    HStack(spacing: 14) {
                        CachedAsyncImage(url: profile.avatarUrl?.resizedImageURL(128))
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(profile.nickname)
                                    .font(.headline)
                                if profile.vipType > 0 {
                                    VIPBadge()
                                }
                            }
                            if let sig = profile.signature, !sig.isEmpty {
                                Text(sig)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Button {
                        showLogin = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 25))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 52, height: 52)
                                .background(Color.primary.opacity(0.06), in: Circle())
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("登录账号")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("同步我喜欢的音乐、歌单与每日推荐")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            }

            if account.hasAuthCookie {
                if columns != .right {
                    Section("我的音乐") {
                        ForEach(libraryRowOrder, id: \.self) { key in
                            libraryRow(key)
                        }
                    }
                }

                if columns != .left, libraryShowsCreatedPlaylists {
                    if !account.createdPlaylists.isEmpty {
                        Section {
                            ForEach(account.createdPlaylists) { playlist in
                                NavigationLink(value: Destination.playlist(playlist.id)) {
                                    HStack(spacing: 10) {
                                        CachedAsyncImage(url: playlist.coverURL?.resizedImageURL(80), animated: false)
                                            .frame(width: 32, height: 32)
                                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(playlist.name)
                                                .font(.system(size: 14))
                                                .lineLimit(1)
                                            Text("\(playlist.trackCount) 首")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text("创建的歌单")
                                Spacer()
                                Button {
                                    showNewPlaylist = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                        }
                    }
                }

                if columns != .left, libraryShowsCollectedPlaylists, !account.subscribedPlaylists.isEmpty {
                    Section("收藏的歌单") {
                        ForEach(account.subscribedPlaylists) { playlist in
                            NavigationLink(value: Destination.playlist(playlist.id)) {
                                HStack(spacing: 10) {
                                    CachedAsyncImage(url: playlist.coverURL?.resizedImageURL(80), animated: false)
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(playlist.name)
                                            .font(.system(size: 14))
                                            .lineLimit(1)
                                        Text("\(playlist.trackCount) 首")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if columns != .left {
                Section {
                    PlayerClearanceSpacer()
                        .listRowBackground(Color.clear)
                }
            }
        }
    }
}
#endif


/// 迷你播放器下方的歌词条：两排，整句按宽度折行；逐字进度走过上面那一排时
/// 整条上滑一行，下一句顺势接上（和安卓端 `.lyric-bar` 是同一套行为）。
private struct LyricStripPill: View {
    @EnvironmentObject private var player: PlayerService
    @ObservedObject private var lyricsCursor = PlayerService.shared.lyricsCursor
    @AppStorage("lyricBarAlignment") private var lyricBarAlignment = "center"

    private static let fontSize: CGFloat = 15
    private static let rowHeight: CGFloat = 24
    private static let sidePadding: CGFloat = 22
    private static let font = PlatformFont.systemFont(ofSize: 15, weight: Font.Weight.semibold.platform)

    /// 一排：整句，或整句里放得下的一段（与安卓 `lyricPlan` 的 row 同构）。
    private struct Row: Identifiable {
        let index: Int
        let start: TimeInterval
        let text: String
        let words: [LyricWord]
        let line: LyricLine
        var id: Int { index }
    }

    @State private var rows: [Row] = []
    /// 当前排。以前由 `TimelineView(.animation(minimumInterval: 1/30))` 每帧算一次，
    /// 等于 30fps 重算整列歌词（N 排 Text/KaraokeLine）——玻璃胶囊每秒被重采样 30 次，
    /// 真机上就是「歌词卡、点不动」。现在只在换排时改一次。
    @State private var cursorIndex = 0
    /// 底栏正在展开/收缩的那 0.36 秒。此时胶囊宽度每帧在变、玻璃每帧重采样，
    /// 逐字擦亮的 display link 再插一脚就是同一帧里三份活。
    var morphing: Bool = false
    var body: some View {
        content
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("歌词：\(currentText)")
    }

    /// 换排检测：0.1s 足够（歌词最短一排也有几百毫秒），
    /// 比 30fps 少 300 倍的 SwiftUI 重算，而肉眼只差最多 0.1s。
    private static let cursorTicker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var content: some View {
        GeometryReader { geo in
            let maxWidth = max(1, geo.size.width - Self.sidePadding * 2)
            // 裁剪只隐藏画面；整列歌词上移时也不能拦截胶囊外的触控。
            track
                .allowsHitTesting(false)
                .padding(.horizontal, Self.sidePadding)
                .padding(.vertical, max(0, (64 - Self.rowHeight * 2) / 2))
                // 只在歌/行数/宽度变化时重排，不在每帧里量字。
                .task(id: signature(width: maxWidth)) {
                    rows = Self.plan(lines: player.lyrics?.lines ?? [], maxWidth: maxWidth)
                    cursorIndex = cursor
                }
                .onReceive(Self.cursorTicker) { _ in
                    // 播放页盖在上面 / 没在播：换排检测没必要跑。
                    guard !player.showNowPlaying, player.isPlaying else { return }
                    let k = cursor
                    if k != cursorIndex { cursorIndex = k }
                }
                .onChange(of: player.currentTrack?.id) { _ in cursorIndex = 0 }
        }
    }

    private func signature(width: CGFloat) -> String {
        "\(player.currentTrack?.id ?? -1)|\(player.lyrics?.lines.count ?? 0)|\(Int(width.rounded()))"
    }

    /// 视口两排：当前排 + 下一排；当前排换到下一排时整体上移一行。
    private var track: some View {
        let k = cursorIndex
        let from = max(0, min(k - 1, max(0, rows.count - 3)))
        let to = min(rows.count - 1, from + 2)
        let visible = (from <= to && !rows.isEmpty) ? Array(rows[from...to]) : []
        return ZStack(alignment: .top) {
            if rows.isEmpty {
                Text(placeholderText)
                    .font(.system(size: Self.fontSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: rowAlignment)
                    .frame(height: Self.rowHeight * 2, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(visible) { row in
                        rowView(row, isCurrent: row.index == k)
                            .frame(maxWidth: .infinity, alignment: rowAlignment)
                            .frame(height: Self.rowHeight, alignment: rowAlignment)
                    }
                }
                .modifier(SlideOffset(k: CGFloat(k - from), height: Self.rowHeight))
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(height: Self.rowHeight * 2, alignment: .top)
        .clipped()
        // 只画三排（当前 ±1），换排时内容整体换掉；不再做整列位移动画
        // （窗口化之后位移动画等于不动，留着只会多一条 0.34s 的无效事务）。

    }

    /// 最后一个 `start <= 播放时间` 的排；和安卓的 `k` 一致。
    private var cursor: Int {
        guard !rows.isEmpty else { return 0 }
        let pos = player.livePlaybackTime
        var k = 0
        for (index, row) in rows.enumerated() where row.start <= pos {
            k = index
        }
        return min(k, rows.count - 1)
    }

    @ViewBuilder private func rowView(_ row: Row, isCurrent: Bool) -> some View {
        if isCurrent, row.words.count > 1 {
            KaraokeLyricLine(line: row.line, words: row.words, size: Self.fontSize,
                             weight: .semibold, color: .primary,
                             alignment: textAlignment,
                             // 三条停摆条件：不在播、底栏正在形变、播放页盖在上面。
                             // 停下时 `update` 会重绘一次，画面冻在当前进度，落位后接着走。
                             playing: player.isPlaying && !morphing && !player.showNowPlaying)
        } else {
            Text(row.text.isEmpty ? " " : row.text)
                .font(.system(size: Self.fontSize, weight: .semibold))
                .foregroundStyle(isCurrent ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .lineLimit(1)
        }
    }

    /// 安卓 `lyricPlan`：逐字有的按词折排、没有的按字折排；
    /// 每排记自己的开始时间，拆成几排就按几个时间点上移。
    private static func plan(lines: [LyricLine], maxWidth: CGFloat) -> [Row] {
        guard !lines.isEmpty else { return [] }
        var rows: [Row] = []
        for (n, line) in lines.enumerated() {
            let next = lines.indices.contains(n + 1) ? lines[n + 1] : nil
            let words = line.words ?? []

            if words.count < 2 {
                var chunks: [String] = []
                var starts: [Int] = []
                var cur = ""
                var used: CGFloat = 0
                var charsBefore = 0
                for ch in line.text {
                    let w = measure(String(ch))
                    if !cur.isEmpty, used + w > maxWidth {
                        chunks.append(cur)
                        starts.append(charsBefore)
                        charsBefore += cur.count
                        cur = ""
                        used = 0
                    }
                    cur.append(ch)
                    used += w
                }
                if !cur.isEmpty {
                    chunks.append(cur)
                    starts.append(charsBefore)
                }
                if chunks.isEmpty {
                    chunks.append("")
                    starts.append(0)
                }

                // 详情页对没有逐字时间的行是按字数线性擦亮的，
                // 所以每排也要按「这排第一个字在一整句里的位置」取时间，
                // 而不是把时长按排数均分 —— 否则字对不上。
                let span = max(1, (next?.time ?? line.time + 4000) - line.time)
                let total = max(1, line.text.count)
                for (offset, chunk) in chunks.enumerated() {
                    let start = line.time + span * Double(starts[offset]) / Double(total)
                    rows.append(Row(index: rows.count,
                                    start: start,
                                    text: chunk,
                                    words: [],
                                    line: LyricLine(id: line.id * 100 + offset,
                                                    time: start,
                                                    end: next?.time ?? line.end,
                                                    text: chunk)))
                }
            } else {
                var group: [LyricWord] = []
                var used: CGFloat = 0
                for word in words {
                    let w = measure(word.text)
                    if !group.isEmpty, used + w > maxWidth {
                        rows.append(piece(group, of: line, index: rows.count))
                        group = []
                        used = 0
                    }
                    group.append(word)
                    used += w
                }
                if !group.isEmpty { rows.append(piece(group, of: line, index: rows.count)) }
            }
        }
        return rows
    }

    private static func piece(_ group: [LyricWord], of line: LyricLine, index: Int) -> Row {
        let start = group.first?.start ?? line.time
        let text = group.map(\.text).joined()
        return Row(index: index,
                   start: start,
                   text: text,
                   words: group,
                   line: LyricLine(id: line.id * 100 + index,
                                   time: start,
                                   end: group.last?.end ?? line.end,
                                   text: text,
                                   words: group))
    }

    private static func measure(_ text: String) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    private var placeholderText: String {
        guard let lyrics = player.lyrics else { return "暂无歌词" }
        return lyrics.lines.isEmpty ? "纯音乐，请欣赏" : "暂无歌词"
    }

    private var rowAlignment: Alignment {
        switch lyricBarAlignment {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private var textAlignment: NSTextAlignment {
        switch lyricBarAlignment {
        case "center": return .center
        case "right": return .right
        default: return .left
        }
    }

    private var currentText: String {
        let lines = player.lyrics?.lines ?? []
        guard let index = lyricsCursor.activeIndex, lines.indices.contains(index) else {
            return lines.isEmpty ? "暂无歌词" : (player.currentTrack?.name ?? "")
        }
        return lines[index].text.isEmpty ? "…" : lines[index].text
    }
}

/// 只让位移参与动画：安卓端的上滑是纯 `translate3d` 过渡，
/// 用 `.offset` + 隐式动画会把同层内容的出现/变色也一起淡入。
private struct SlideOffset: ViewModifier, Animatable {
    var k: CGFloat
    let height: CGFloat

    var animatableData: CGFloat {
        get { k }
        set { k = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(y: -k * height)
    }
}
