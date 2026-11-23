import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case all = "综合"
        case songs = "单曲"
        case artists = "歌手"
        case albums = "专辑"
        case playlists = "歌单"

        var id: String { rawValue }
    }

    var query: String
    @Published var tab: Tab = .all
    @Published var songs: [Track] = []
    @Published var artists: [ArtistSummary] = []
    @Published var albums: [AlbumSummary] = []
    @Published var playlists: [PlaylistSummary] = []
    @Published var loadedTabs: Set<Tab> = []
    @Published private var loadingTabs: Set<Tab> = []
    @Published private(set) var failedTabs: Set<Tab> = []
    /// Bumped on every query change so responses to an older query are dropped.
    private var generation = 0
    private var requests: [Tab: UUID] = [:]

    var isLoading: Bool { loadingTabs.contains(tab) }

    init(query: String) {
        self.query = query
    }

    func setQuery(_ newQuery: String) {
        guard newQuery != query else { return }
        query = newQuery
        generation &+= 1
        requests.removeAll()
        loadedTabs.removeAll()
        loadingTabs.removeAll()
        failedTabs.removeAll()
        songs = []
        artists = []
        albums = []
        playlists = []
    }

    func load(tab: Tab) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !loadedTabs.contains(tab), !Task.isCancelled else { return }
        failedTabs.remove(tab)
        let requestGeneration = generation
        let request = UUID()
        requests[tab] = request
        loadingTabs.insert(tab)
        func isCurrent() -> Bool {
            generation == requestGeneration && requests[tab] == request && !Task.isCancelled
        }
        defer {
            if requests[tab] == request {
                requests[tab] = nil
                loadingTabs.remove(tab)
            }
        }

        // A failed request leaves the tab unloaded so submitting again retries
        // instead of keeping an empty result for this query.
        switch tab {
        case .all:
            async let songsTask = try? MusicAPI.search(trimmed, type: .songs, limit: 12)
            async let artistsTask = try? MusicAPI.search(trimmed, type: .artists, limit: 10)
            async let albumsTask = try? MusicAPI.search(trimmed, type: .albums, limit: 10)
            async let playlistsTask = try? MusicAPI.search(trimmed, type: .playlists, limit: 10)
            let (songResult, artistResult, albumResult, playlistResult) =
                await (songsTask, artistsTask, albumsTask, playlistsTask)
            guard isCurrent() else { return }
            if let songResult { songs = songResult.songs ?? [] }
            if let artistResult { artists = artistResult.artists ?? [] }
            if let albumResult { albums = albumResult.albums ?? [] }
            if let playlistResult { playlists = playlistResult.playlists ?? [] }
            if songResult == nil || artistResult == nil || albumResult == nil || playlistResult == nil {
                markFailed(tab)
            }
        case .songs:
            let result = try? await MusicAPI.search(trimmed, type: .songs, limit: 100)
            guard isCurrent() else { return }
            if let result { songs = result.songs ?? songs } else { markFailed(tab) }
        case .artists:
            let result = try? await MusicAPI.search(trimmed, type: .artists, limit: 50)
            guard isCurrent() else { return }
            if let result { artists = result.artists ?? artists } else { markFailed(tab) }
        case .albums:
            let result = try? await MusicAPI.search(trimmed, type: .albums, limit: 50)
            guard isCurrent() else { return }
            if let result { albums = result.albums ?? albums } else { markFailed(tab) }
        case .playlists:
            let result = try? await MusicAPI.search(trimmed, type: .playlists, limit: 50)
            guard isCurrent() else { return }
            if let result { playlists = result.playlists ?? playlists } else { markFailed(tab) }
        }
        if !failedTabs.contains(tab) { loadedTabs.insert(tab) }
    }

    private func markFailed(_ tab: Tab) {
        loadedTabs.remove(tab)
        if !Task.isCancelled { failedTabs.insert(tab) }
    }
}

struct SearchView: View {
    @StateObject private var model: SearchViewModel
    @State private var searchText: String = ""
    @Environment(\.closeSearch) private var closeSearch

    init(query: String) {
        _model = StateObject(wrappedValue: SearchViewModel(query: query))
        _searchText = State(initialValue: query)
    }

    var body: some View {
        searchContent
        #if os(iOS)
        // iPad enters SearchView from the sidebar, where the desktop window
        // toolbar search field is unavailable. On macOS, MainWindow owns the
        // only search field and navigates here with its submitted query.
        // Keep the field pinned under the title. The default drawer collapses
        // until the page scrolls, and the empty search page has nothing to
        // scroll, so the field stayed hidden on the iPhone Search tab.
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "搜索歌曲、歌手、专辑、歌单"
        )
        .onSubmit(of: .search) {
            model.setQuery(searchText)
            Task { await model.load(tab: model.tab) }
        }
        .onChange(of: searchText) { newValue in
            model.setQuery(newValue)
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if searchText == newValue {
                    await model.load(tab: model.tab)
                }
            }
        }
        #endif
        .navigationTitle(searchText.isEmpty ? "搜索" : String(localized: "搜索：\(searchText)"))
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    closeSearch()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                }
                .accessibilityLabel("关闭搜索")
                .accessibilityIdentifier("search-close-button")
            }
        }
        #endif
        .task(id: model.tab) {
            await model.load(tab: model.tab)
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        #if os(macOS)
        if model.tab == .songs, !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            TrackListScrollView(trackIDs: model.songs.map(\.id)) {
                VStack(spacing: 20) {
                    tabPicker
                    resultStatus
                }
            } rows: { layout in
                TrackListView(tracks: model.songs, layout: layout)
                    .padding(.horizontal, Theme.Layout.contentInset - 10)
            } footer: {
                PlayerClearanceSpacer()
            }
        } else {
            mixedResults.clipped()
        }
        #else
        mixedResults
        #endif
    }

    private var mixedResults: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    tabPicker

                    if !currentEmpty { tabContent }
                    resultStatus
                } else {
                    emptySearchPrompt
                }
                PlayerClearanceSpacer()
            }
        }
    }

    private var tabPicker: some View {
        Picker("", selection: $model.tab) {
            ForEach(SearchViewModel.Tab.allCases) { tab in
                Text(LocalizedStringKey(tab.rawValue)).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, Theme.Layout.contentInset)
        .padding(.top, 12)
    }

    private var emptySearchPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.top, 60)
            Text("探索海量华语流行与经典音乐")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("输入歌曲名称、歌手名或歌单关键字开始搜索")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    private var currentEmpty: Bool {
        switch model.tab {
        case .all: return model.songs.isEmpty && model.artists.isEmpty
            && model.albums.isEmpty && model.playlists.isEmpty
        case .songs: return model.songs.isEmpty
        case .artists: return model.artists.isEmpty
        case .albums: return model.albums.isEmpty
        case .playlists: return model.playlists.isEmpty
        }
    }

    @ViewBuilder
    private var resultStatus: some View {
        if model.failedTabs.contains(model.tab) {
            ErrorStateView(message: String(localized: "搜索失败，请重试")) {
                Task { await model.load(tab: model.tab) }
            }
        } else if currentEmpty {
            if model.isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 300)
            } else if model.loadedTabs.contains(model.tab) {
                EmptyStateView(icon: "magnifyingglass", title: "没有找到相关结果")
                    .frame(minHeight: 300)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch model.tab {
        case .all:
            if !model.songs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "单曲") {
                        model.tab = .songs
                    }
                    .padding(.horizontal, Theme.Layout.contentInset)
                    TrackListView(tracks: Array(model.songs.prefix(6)))
                        .padding(.horizontal, Theme.Layout.contentInset - 10)
                }
            }
            if !model.artists.isEmpty {
                Shelf(title: "歌手", seeAll: { model.tab = .artists }) {
                    artistCards(model.artists.prefix(8))
                }
            }
            if !model.albums.isEmpty {
                Shelf(title: "专辑", seeAll: { model.tab = .albums }) {
                    albumCards(model.albums.prefix(8))
                }
            }
            if !model.playlists.isEmpty {
                Shelf(title: "歌单", seeAll: { model.tab = .playlists }) {
                    playlistCards(model.playlists.prefix(8))
                }
            }
        case .songs:
            TrackListView(tracks: model.songs)
                .padding(.horizontal, Theme.Layout.contentInset - 10)
        case .artists:
            CardGrid(minWidth: 140) {
                artistCards(model.artists)
            }
            .padding(.horizontal, Theme.Layout.contentInset)
        case .albums:
            CardGrid {
                albumCards(model.albums)
            }
            .padding(.horizontal, Theme.Layout.contentInset)
        case .playlists:
            CardGrid {
                playlistCards(model.playlists)
            }
            .padding(.horizontal, Theme.Layout.contentInset)
        }
    }

    private func artistCards(_ items: some Collection<ArtistSummary>) -> some View {
        ForEach(Array(items)) { artist in
            NavigationLink {
                ArtistDetailView(artistID: artist.id)
            } label: {
                VStack(spacing: 10) {
                    CachedAsyncImage(url: artist.picUrl?.resizedImageURL(256))
                        .frame(width: 128, height: 128)
                        .clipShape(Circle())
                    Text(artist.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(width: 140)
            }
            .buttonStyle(.plain)
        }
    }

    private func albumCards(_ items: some Collection<AlbumSummary>) -> some View {
        ForEach(Array(items)) { album in
            NavigationLink {
                AlbumDetailView(albumID: album.id)
            } label: {
                CoverCardBody(
                    coverURL: album.picUrl?.resizedImageURL(384),
                    title: album.name,
                    subtitle: album.artistName
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func playlistCards(_ items: some Collection<PlaylistSummary>) -> some View {
        ForEach(Array(items)) { playlist in
            NavigationLink {
                PlaylistDetailView(playlistID: playlist.id)
            } label: {
                CoverCardBody(
                    coverURL: playlist.coverURL?.resizedImageURL(384),
                    title: playlist.name,
                    playCount: playlist.playCount
                )
            }
            .buttonStyle(.plain)
        }
    }
}
