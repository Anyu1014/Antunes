import SwiftUI
#if os(macOS)
import Combine
#endif

#if os(iOS)
/// The iOS Settings sheet: its navigation stack, title and 完成 button around
/// `SettingsView`. Present it from the app's root (`presentSettingsSheet`).
///
/// Presented from inside the Library tab, the sheet was re-hosted whenever
/// the tab view updated, so changing a setting from a pushed page (picking a
/// sound effect, say) reset the stack and popped the page back to the root.
/// It also keeps the stack apart from `SettingsView`, which re-renders on
/// every settings change.
struct SettingsSheet: View {
    var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .automatic
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openDestination) private var openDestination
    @State private var path: [SettingsView.SettingsPage] = []

    var body: some View {
        NavigationStack(path: $path) {
            SettingsView()
                .navigationTitle("设置")
                .navigationBarTitleDisplayMode(titleDisplayMode)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                    }
                }
                .navigationDestination(for: SettingsView.SettingsPage.self) { page in
                    switch page {
                    case .storage:
                        StorageSpaceView {
                            dismiss()
                            openDestination(.downloaded)
                        }
                    case .soundEffects:
                        SoundEffectsPage()
                    case .about:
                        AboutView()
                    }
                }
        }
        // 设置抽屉也是「场景」之一：横屏同样去掉系统顶栏底色，只留自建渐进模糊。
        .progressiveTopBarInLandscape()
    }
}
#endif

struct SettingsView: View {
    #if os(iOS)
    private var coverPreference = CollectionCoverPreference()
    #endif
    @AppStorage("tabBarShowsLabels") private var showsTabBarLabels = false
    @AppStorage("librarySearchButton") private var librarySearchButton = true
    @AppStorage("bottomBarLyrics") private var bottomBarLyrics = true
    @AppStorage("lyricBarAlignment") private var lyricBarAlignment = "center"
    @AppStorage("tabOrder") private var tabOrder = "home,explore,library,search"
    @AppStorage("startTab") private var startTab = "auto"
    @AppStorage(HomeFeed.hiddenSectionsKey) private var hiddenHomeSections = ""
    @AppStorage("libraryOrder") private var libraryOrder = "liked,daily,recents,collections,downloads,cloud"
    @AppStorage("libraryShowsCreatedPlaylists") private var libraryShowsCreatedPlaylists = true
    @AppStorage("libraryShowsCollectedPlaylists") private var libraryShowsCollectedPlaylists = true
    @AppStorage("libraryShowsLiked") private var libraryShowsLiked = true
    @AppStorage("libraryShowsDaily") private var libraryShowsDaily = true
    @AppStorage("libraryShowsRecents") private var libraryShowsRecents = true
    @AppStorage("libraryShowsCollections") private var libraryShowsCollections = true
    @AppStorage("libraryShowsDownloads") private var libraryShowsDownloads = true
    @AppStorage("libraryShowsCloud") private var libraryShowsCloud = true
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var account: AccountStore
    @Environment(\.openDestination) private var openDestination
    #if os(macOS)
    @AppStorage(SettingsManager.Keys.menuBarPlayer) private var showMenuBarPlayer = false
    @State private var navigationPath: [SettingsPage] = []
    #else
    @State private var editingProfileBioFor: Int?
    @State private var profileBioDraft = ""
    #endif

    fileprivate enum SettingsPage: Hashable {
        case storage
        case about
        #if os(iOS)
        case soundEffects
        #endif
        #if os(macOS)
        case shortcuts
        #endif
    }

    var body: some View {
        #if os(macOS)
        NavigationStack(path: $navigationPath) { settingsForm }
            .toolbar {
                if !navigationPath.isEmpty {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            _ = navigationPath.popLast()
                        } label: {
                            Label("返回", systemImage: "chevron.backward")
                        }
                        .labelStyle(.iconOnly)
                    }
                }
            }
            .background(SettingsWindowToolbar(onClose: { navigationPath.removeAll() }))
            .frame(width: 520, height: 620)
            .overlay(alignment: .top) { SettingsToastOverlay() }
        #else
        // Navigation lives in `SettingsSheet`, which observes no settings.
        settingsForm
        #endif
    }

    // MARK: - 主页板块排序

    private func orderedKeys(_ all: [String], stored: String) -> [String] {
        let order = stored.split(separator: ",").map(String.init)
        return all.sorted { a, b in
            (order.firstIndex(of: a) ?? 99) < (order.firstIndex(of: b) ?? 99)
        }
    }

    private var orderedTabs: [String] {
        orderedKeys(["home", "explore", "fm", "library", "search"], stored: tabOrder)
    }

    private var orderedLibraryRows: [String] {
        orderedKeys(["liked", "daily", "recents", "collections", "downloads", "cloud"], stored: libraryOrder)
    }

    private func libraryRowTitle(_ key: String) -> String {
        switch key {
        case "liked": return "我喜欢的音乐"
        case "daily": return "每日推荐"
        case "recents": return "最近播放"
        case "collections": return "我的收藏"
        case "downloads": return "我的下载"
        case "cloud": return "音乐云盘"
        default: return key
        }
    }

    private func libraryRowBinding(for key: String) -> Binding<Bool> {
        switch key {
        case "liked": return $libraryShowsLiked
        case "daily": return $libraryShowsDaily
        case "recents": return $libraryShowsRecents
        case "collections": return $libraryShowsCollections
        case "downloads": return $libraryShowsDownloads
        case "cloud": return $libraryShowsCloud
        default: return .constant(true)
        }
    }

    private func homeSectionToggle(_ title: String, key: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { !hiddenHomeSections.split(separator: ",").contains(Substring(key)) },
            set: { enabled in
                var hidden = Set(hiddenHomeSections.split(separator: ",").map(String.init))
                if enabled {
                    hidden.remove(key)
                } else {
                    hidden.insert(key)
                }
                hiddenHomeSections = hidden.sorted().joined(separator: ",")
            }
        ))
    }

    #if os(iOS)
    @ViewBuilder private var collectionCoverOptions: some View {
        Text("经典歌单封面").tag("classic")
        Text("渐变封面柔和").tag("gradient")
        Text("渐变封面压暗").tag("gradientDimmed")
    }
    #endif

    private func tabTitle(_ key: String) -> String {
        switch key {
        case "home": return "推荐"
        case "explore": return "精选"
        case "fm": return "漫游"
        case "library": return "我的"
        case "search": return "搜索"
        default: return key
        }
    }

    private func binding(for key: String) -> Binding<Bool> {
        switch key {
        case "home": return $settings.showHome
        case "explore": return $settings.showExplore
        case "fm": return $settings.showFM
        case "library": return $settings.showLibrary
        case "search": return $settings.showSearch
        default: return .constant(true)
        }
    }

    /// 一组可排序行：当前顺序，以及顺序的回写方式。
    private struct ReorderStore {
        var order: [String]
        var commit: ([String]) -> Void
    }

    /// 三个点菜单里的四种移动。
    private enum RowMove: String, CaseIterable {
        case top = "移到顶部"
        case up = "上移"
        case down = "下移"
        case bottom = "移到底部"

        var symbol: String {
            switch self {
            case .top: return "arrow.up.to.line"
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .bottom: return "arrow.down.to.line"
            }
        }
    }

    private var tabStore: ReorderStore {
        ReorderStore(order: orderedTabs) { keys in
            tabOrder = keys.joined(separator: ",")
        }
    }

    private var libraryStore: ReorderStore {
        ReorderStore(order: orderedLibraryRows) { keys in
            libraryOrder = keys.joined(separator: ",")
        }
    }

    /// 只把 `key` 挪一格或挪到端点，其余行保持相对顺序。
    private func moveRow(_ key: String, _ move: RowMove, store: ReorderStore) {
        var order = store.order
        guard order.count > 1, let index = order.firstIndex(of: key) else { return }
        switch move {
        case .top:
            guard index > 0 else { return }
            order.remove(at: index)
            order.insert(key, at: 0)
        case .up:
            guard index > 0 else { return }
            order.swapAt(index, index - 1)
        case .down:
            guard index < order.count - 1 else { return }
            order.swapAt(index, index + 1)
        case .bottom:
            guard index < order.count - 1 else { return }
            order.remove(at: index)
            order.append(key)
        }
        withAnimation(AppAnimation.standard) { store.commit(order) }
    }

    private func canMove(_ key: String, _ move: RowMove, store: ReorderStore) -> Bool {
        guard let index = store.order.firstIndex(of: key) else { return false }
        switch move {
        case .top, .up: return index > 0
        case .down, .bottom: return index < store.order.count - 1
        }
    }

    /// 三点按钮的圆底：iOS 26 起用 `glassEffect`，旧系统退回材质圆。
    @ViewBuilder
    private var dragHandleSurface: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            Circle().fill(.clear).glassEffect(.regular, in: Circle())
        } else {
            Circle().fill(.regularMaterial)
        }
        #else
        Circle().fill(.regularMaterial)
        #endif
    }

    private func reorderRow(_ key: String, title: String, isOn: Binding<Bool>,
                            store: @escaping () -> ReorderStore) -> some View {
        let current = store()
        return HStack {
            Toggle(title, isOn: isOn)
            Menu {
                ForEach(RowMove.allCases, id: \.self) { move in
                    Button {
                        moveRow(key, move, store: store())
                    } label: {
                        Label(move.rawValue, systemImage: move.symbol)
                    }
                    .disabled(!canMove(key, move, store: current))
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background { dragHandleSurface }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .accessibilityLabel("调整顺序：\(title)")
        }
    }

    private func sectionRow(_ key: String) -> some View {
        // 「我的」是兜底板块：其它四个（推荐/精选/漫游/搜索）全部关闭后才允许关闭它，
        // 否则底栏会无处可去，设置页本身也会跟着一起被关掉。
        let locked = key == "library" && !settings.otherSectionsAllOff
        return reorderRow(key, title: tabTitle(key), isOn: binding(for: key), store: { tabStore })
            .disabled(locked)
            .opacity(locked ? 0.45 : 1)
    }

    private func librarySectionRow(_ key: String) -> some View {
        reorderRow(key, title: libraryRowTitle(key), isOn: libraryRowBinding(for: key), store: { libraryStore })
    }

    private var settingsForm: some View {
        Form {
            Section("播放") {
                Picker("音质", selection: Binding(
                    get: { settings.audioQuality.normalized },
                    set: { settings.audioQuality = $0 }
                )) {
                    ForEach(AudioQuality.selectable) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                    .accessibilityIdentifier("settingsAudioQuality")
                Picker("下载音质", selection: Binding(
                    get: { settings.downloadQuality.normalized },
                    set: { settings.downloadQuality = $0 }
                )) {
                    ForEach(AudioQuality.selectable) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .accessibilityIdentifier("settingsDownloadQuality")
                #if os(iOS)
                NavigationLink(value: SettingsPage.soundEffects) {
                    HStack {
                        Text("音效")
                        Spacer()
                        Text(settings.soundEffectPreset.displayName)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityValue(settings.soundEffectPreset.displayName)
                .accessibilityIdentifier("settingsSoundEffectsButton")
                #endif
                #if os(macOS)
                Toggle("灰色歌曲解锁", isOn: $settings.enableUnblock)
                Text("无版权或下架歌曲将从已启用音源中匹配播放")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }
            #if os(macOS)
            AutoMixSettingsSection()

            if settings.enableUnblock {
                Section {
                    ForEach(AudioSourceID.allCases, id: \.self) { source in
                        Toggle(source.displayName, isOn: Binding(
                            get: { settings.enabledAudioSourceIDs.contains(source) },
                            set: { isEnabled in
                                if isEnabled {
                                    settings.enabledAudioSourceIDs.insert(source)
                                } else {
                                    settings.enabledAudioSourceIDs.remove(source)
                                }
                            }
                        ))
                    }
                } header: {
                    Text("音源")
                }
            }
            #endif

            #if os(iOS)
            Section("板块管理") {
                DisclosureGroup("主页板块") {
                    Toggle("底栏歌词", isOn: $bottomBarLyrics)
                    Picker("底栏歌词对齐", selection: $lyricBarAlignment) {
                        Text("居左").tag("left")
                        Text("居中").tag("center")
                        Text("居右").tag("right")
                    }
                    Toggle("底栏文字", isOn: $showsTabBarLabels)
                    Toggle("我的页搜索按钮", isOn: $librarySearchButton)
                    Picker("冷启动板块", selection: $startTab) {
                        Text("自动（第一个板块）").tag("auto")
                        ForEach(orderedTabs, id: \.self) { tab in
                            Text(tabTitle(tab)).tag(tab)
                        }
                    }
                    ForEach(orderedTabs, id: \.self) { tab in
                        sectionRow(tab)
                    }
                    Text("点右侧三个点可移到顶部、上移、下移、移到底部（顺序即底栏从左到右）；只留一项时底栏显示该项图标。「我的」只能在其它四个板块全部关闭后关闭，全部关闭时默认显示「我的」。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup("我的音乐板块") {
                    ForEach(orderedLibraryRows, id: \.self) { key in
                        librarySectionRow(key)
                    }
                    Text("点右侧三个点可移到顶部、上移、下移、移到底部（顺序即“我的”页里从上到下的顺序）；关掉的项不再出现在“我的”页。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup("主页歌单展示") {
                    Toggle("展示创建的歌单", isOn: $libraryShowsCreatedPlaylists)
                    Toggle("展示收藏的歌单", isOn: $libraryShowsCollectedPlaylists)
                    Toggle("我喜欢的音乐显示在创建的歌单", isOn: $settings.showLikedInCreated)
                    Text("关掉后“我的”页不再显示对应的歌单分组，歌单本身不会被删除。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup("推荐页板块") {
                    ForEach(HomeSupplement.shortcuts, id: \.self) { section in
                        homeSectionToggle(section.title, key: section.rawValue)
                    }
                    ForEach(HomeFeedSlot.allCases, id: \.self) { slot in
                        homeSectionToggle(HomeFeed.defaultTitle(for: slot), key: slot.rawValue)
                    }
                    ForEach(HomeSupplement.shelves, id: \.self) { section in
                        homeSectionToggle(section.title, key: section.rawValue)
                    }
                }
            }
            #endif

            Section("外观") {
                #if os(iOS)
                Picker("竖屏歌单封面风格", selection: coverPreference.portraitSelection) {
                    collectionCoverOptions
                }
                Picker("横屏歌单封面风格", selection: coverPreference.landscapeSelection) {
                    collectionCoverOptions
                    Text("渐变封面流光").tag("gradientFlow")
                }
                #endif
                Picker("主题", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
                #if os(macOS)
                // macOS only renders two now-playing layouts — 黑胶 and the
                // regular page; the iOS 沉浸/简洁 options all fall back to the
                // regular page here, so offering four was misleading (#105).
                // Map any non-vinyl value onto 经典模式 so a stored default (e.g.
                // 沉浸模式) still shows a valid selection.
                Picker("播放页模式", selection: Binding(
                    get: { settings.nowPlayingMode == .vinyl ? .vinyl : .classic },
                    set: { settings.nowPlayingMode = $0 }
                )) {
                    Text(NowPlayingMode.vinyl.displayName).tag(NowPlayingMode.vinyl)
                    Text(NowPlayingMode.classic.displayName).tag(NowPlayingMode.classic)
                }
                #endif
                Toggle("点击封面打开专辑", isOn: $settings.openAlbumOnArtworkClick)
                Toggle("显示歌词翻译", isOn: $settings.showLyricsTranslation)
                Toggle("逐字歌词（卡拉OK）", isOn: $settings.verbatimLyrics)
                Picker("日文歌词读音", selection: $settings.lyricsAnnotation) {
                    ForEach(LyricsAnnotation.allCases) { annotation in
                        Text(annotation.displayName).tag(annotation)
                    }
                }
                Text("罗马音在歌词上方另起一行，汉字读音把假名标在汉字正上方；缺少官方罗马音时自动生成读音")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("主界面环境色", isOn: $settings.showMainWindowAmbientBackground)
                if settings.showMainWindowAmbientBackground {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("背景色强度")
                            Spacer()
                            Text("\(Int(settings.mainWindowAmbientBackgroundIntensity * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: $settings.mainWindowAmbientBackgroundIntensity,
                            in: SettingsManager.mainWindowAmbientBackgroundIntensityRange,
                            step: 0.1
                        )
                        HStack {
                            Text("50%")
                            Spacer()
                            Text("150%")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                #if os(macOS)
                Toggle("桌面歌词", isOn: $settings.showDesktopLyrics)
                if settings.showDesktopLyrics {
                    Toggle("桌面歌词水平居中", isOn: $settings.desktopLyricsCentered)
                }
                Text("在屏幕上悬浮显示当前歌词，可拖动调整位置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }

            Section("存储") {
                NavigationLink(value: SettingsPage.storage) {
                    Label("存储空间", systemImage: "internaldrive")
                }
            }

            #if os(macOS)
            Section("通用") {
                Toggle("在菜单栏显示", isOn: $showMenuBarPlayer)
                NavigationLink(value: SettingsPage.shortcuts) {
                    Label("快捷键", systemImage: "keyboard")
                }
            }
            #endif

            SyncSettingsSection()

            Section("账号") {
                if let profile = account.profile {
                    LabeledContent("当前账号", value: profile.nickname)
                    #if os(iOS)
                    if let userID = account.authenticatedAccountID, userID > 0 {
                        Button("自定义个人简介") {
                            profileBioDraft = settings.customProfileBio(for: userID)
                            editingProfileBioFor = userID
                        }
                    }
                    #endif
                    Button("退出登录", role: .destructive) {
                        Task {
                            do { try await AccountStore.shared.logout() }
                            catch { ToastCenter.shared.show(error.localizedDescription) }
                        }
                    }
                } else {
                    Text("未登录")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                NavigationLink(value: SettingsPage.about) {
                    HStack {
                        Text("关于")
                        Spacer()
                        Text("Antunes · \(appVersionAndBuild)")
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("settingsAboutButton")
            }

        }
        .formStyle(.grouped)
        #if os(iOS)
        .alert("自定义个人简介", isPresented: Binding(
            get: { editingProfileBioFor != nil },
            set: { if !$0 { editingProfileBioFor = nil } }
        ), presenting: editingProfileBioFor) { userID in
            TextField("留空使用网易云音乐简介", text: $profileBioDraft)
            Button("取消", role: .cancel) {}
            Button("保存") {
                guard account.authenticatedAccountID == userID else { return }
                settings.setCustomProfileBio(profileBioDraft, for: userID)
            }
        } message: { _ in
            Text("仅修改本机显示，不会更新网易云音乐上的简介。")
        }
        #endif
        #if os(macOS)
        .navigationDestination(for: SettingsPage.self) { page in
            Group {
                switch page {
                case .storage:
                    StorageSpaceView {
                        openDestination(.downloaded)
                    }
                case .about:
                    AboutView()
                case .shortcuts:
                    ShortcutSettingsView()
                }
            }
            .navigationBarBackButtonHidden()
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    switch page {
                    case .storage: Text("存储空间").font(.headline)
                    case .about: Text("关于").font(.headline)
                    case .shortcuts: Text("快捷键").font(.headline)
                    }
                }
            }
        }
        #endif
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    private var appBuild: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    /// "0.1.0 (2)": version, then build in brackets, both read from the bundle.
    private var appVersionAndBuild: String {
        guard let build = appBuild, !build.isEmpty else { return appVersion }
        return "\(appVersion) (\(build))"
    }

}

#if os(macOS)
private struct SettingsToastOverlay: View {
    @ObservedObject private var toasts = ToastCenter.shared

    var body: some View {
        Group {
            if let toast = toasts.current {
                ToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 12)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.spring(duration: 0.3), value: toasts.current)
        .allowsHitTesting(false)
    }
}

/// Keep navigation and the title in the native, compact titlebar toolbar.
/// Settings scenes retain their view state when closed, so reset the path here.
struct SettingsWindowToolbar: NSViewRepresentable {
    let onClose: () -> Void

    func makeNSView(context: Context) -> ToolbarHost {
        let view = ToolbarHost()
        view.onClose = onClose
        return view
    }

    func updateNSView(_ nsView: ToolbarHost, context: Context) {
        nsView.onClose = onClose
        nsView.updateToolbar()
    }

    final class ToolbarHost: NSView {
        var onClose: () -> Void = {}
        private var closeObserver: AnyCancellable?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            closeObserver = window.map { window in
                NotificationCenter.default.publisher(for: NSWindow.willCloseNotification, object: window)
                    .sink { [weak self] _ in self?.onClose() }
            }
            updateToolbar()
        }

        func updateToolbar() {
            guard let window, window.toolbarStyle != .unifiedCompact else { return }
            DispatchQueue.main.async { [weak self] in
                guard let window = self?.window, window.toolbarStyle != .unifiedCompact else { return }
                window.toolbarStyle = .unifiedCompact
            }
        }
    }
}
#endif
