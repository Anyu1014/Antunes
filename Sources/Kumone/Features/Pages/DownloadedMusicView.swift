import SwiftUI

/// A music-library page, using the same rows and layout as Recents and Cloud.
/// Only explicitly retained downloads belong here; automatic caches stay private.
/// 「已下载」的排序方式。名称是原有行为，其余三种是新增的。
enum DownloadSortOrder: String, CaseIterable, Identifiable {
    case name
    case size
    case newest
    case oldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return String(localized: "按名称")
        case .size: return String(localized: "按大小")
        case .newest: return String(localized: "从新到旧")
        case .oldest: return String(localized: "从旧到新")
        }
    }
}

struct DownloadedMusicView: View {
    var collectionID: String?
    @ObservedObject private var downloads = DownloadManager.shared
    private let player = PlayerService.shared
    @Environment(\.openDestination) private var openDestination
    @State private var isSelecting = false
    @State private var selectedIDs: Set<Int> = []
    @State private var confirmRemoval = false
    @State private var pendingRemoval: Set<Int> = []
    @State private var removalScope: String?
    @State private var isRemoving = false
    @AppStorage("downloadSortOrder") private var sortOrderRaw = DownloadSortOrder.name.rawValue

    private var collection: DownloadCollection? { downloads.collections.first { $0.id == collectionID } }
    private var sortOrder: DownloadSortOrder {
        DownloadSortOrder(rawValue: sortOrderRaw) ?? .name
    }

    /// 每首下载的体积、落盘时间与档位，用于排序和行尾标注。
    private struct DownloadFacts {
        let bytes: Int64
        let downloadedAt: Date?
        let quality: String?
    }

    private var facts: [Int: DownloadFacts] {
        var result: [Int: DownloadFacts] = [:]
        for entry in downloads.downloadedTracks {
            let assets = entry.assets.filter { !$0.retainedBy.isEmpty || $0.state == .complete }
            guard !assets.isEmpty else { continue }
            let rank = AudioQuality.allCases.map(\.rawValue)
            let best = assets.max { lhs, rhs in
                let l = rank.firstIndex(of: lhs.descriptor.identity.quality) ?? -1
                let r = rank.firstIndex(of: rhs.descriptor.identity.quality) ?? -1
                return l < r
            }
            result[entry.id] = DownloadFacts(
                bytes: assets.reduce(0) { $0 + $1.descriptor.byteCount },
                downloadedAt: assets.compactMap { $0.verifiedModificationDate ?? $0.lastPlayed }.max(),
                quality: best?.descriptor.identity.quality
            )
        }
        return result
    }

    private var tracks: [Track] {
        let base = downloads.downloadedSongs(in: collectionID)
        let facts = self.facts
        switch sortOrder {
        case .name:
            return base.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size:
            return base.sorted { (facts[$0.id]?.bytes ?? 0) > (facts[$1.id]?.bytes ?? 0) }
        case .newest:
            return base.sorted { (facts[$0.id]?.downloadedAt ?? .distantPast) > (facts[$1.id]?.downloadedAt ?? .distantPast) }
        case .oldest:
            return base.sorted { (facts[$0.id]?.downloadedAt ?? .distantPast) < (facts[$1.id]?.downloadedAt ?? .distantPast) }
        }
    }
    private var pendingCount: Int { downloads.pendingJobs.count }

    var body: some View {
        let displayed = tracks
        let visible = !downloads.isReady && downloads.errorMessage == nil ? [] : displayed
        TrackListScrollView(trackIDs: visible.map(\.id), spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                if isSelecting { selectionHeader(tracks: displayed) } else { header(tracks: displayed) }

                if !downloads.isReady, downloads.errorMessage == nil {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                } else if let error = downloads.errorMessage, displayed.isEmpty {
                    EmptyStateView(icon: "exclamationmark.triangle", title: "无法读取下载", subtitle: LocalizedStringKey(error))
                        .frame(minHeight: 300)
                } else if displayed.isEmpty {
                    EmptyStateView(icon: "arrow.down.circle", title: "还没有下载歌曲",
                                   subtitle: "在歌曲菜单或歌单页面选择下载，即可离线收听")
                        .frame(minHeight: 300)
                }
            }
        } rows: { layout in
            TrackListView(tracks: visible, source: .none, selection: isSelecting ? $selectedIDs : nil,
                          layout: layout, sizeLabels: sizeLabels)
                .disabled(isRemoving)
                .padding(.horizontal, Theme.Layout.contentInset - 10)
        } footer: {
            PlayerClearanceSpacer()
        }
        // NavigationStack keeps its previous page behind this destination.
        // Give the music page a surface so transparent scroll content cannot
        // show the previous list through a saved-collection page.
        .background(Platform.windowBackgroundColor)
        .navigationTitle(collection?.name ?? String(localized: "已下载"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(collectionID == nil ? .large : .inline)
        #endif
        .task { await downloads.start(); await downloads.refreshLibrary() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("排序", selection: $sortOrderRaw) {
                        ForEach(DownloadSortOrder.allCases) { order in
                            Text(order.title).tag(order.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .disabled(displayed.isEmpty)
                .accessibilityIdentifier("sort-downloads")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(isSelecting ? String(localized: "完成") : String(localized: "选择")) {
                    selectedIDs = []
                    isSelecting.toggle()
                }
                .disabled(isRemoving || (!isSelecting && displayed.isEmpty))
                .accessibilityIdentifier("select-downloads")
            }
        }
        .onChange(of: displayed.map(\.id)) { ids in
            selectedIDs.formIntersection(ids)
            if ids.isEmpty { isSelecting = false }
        }
        .onChange(of: downloads.accountScope) { _ in
            selectedIDs = []
            isSelecting = false
            confirmRemoval = false
            pendingRemoval = []
        }
        .alert("移除所选的 \(pendingRemoval.count) 首下载？", isPresented: $confirmRemoval) {
            Button("移除下载", role: .destructive) { removeSelection() }
            Button("取消", role: .cancel) {}
        } message: { Text("歌曲仍会保留在歌单中。") }
    }

    /// 「已下载」每行右侧：占用空间 · 下载档位（档位认不出时只显示空间）。
    private var sizeLabels: [Int: String] {
        let facts = self.facts
        var labels: [Int: String] = [:]
        for (id, bytes) in downloads.downloadedBytes {
            let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            if let quality = facts[id]?.quality, let named = AudioQuality(rawValue: quality)?.displayName {
                labels[id] = "\(size) · \(named)"
            } else {
                labels[id] = size
            }
        }
        return labels
    }

    private func selectionHeader(tracks: [Track]) -> some View {
        HStack(spacing: 12) {
            Text("已选择 \(selectedIDs.count) 首")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            let ids = Set(tracks.map(\.id))
            let allSelected = !ids.isEmpty && ids.isSubset(of: selectedIDs)
            Button(allSelected ? String(localized: "取消全选") : String(localized: "全选")) {
                selectedIDs = allSelected ? [] : ids
            }
            .keyboardShortcut("a", modifiers: .command)
            .accessibilityIdentifier("select-all-downloads")
            Button("移除下载", role: .destructive) {
                pendingRemoval = selectedIDs.intersection(ids)
                removalScope = downloads.accountScope
                confirmRemoval = true
            }
            .disabled(selectedIDs.isEmpty)
            .accessibilityIdentifier("remove-selected-downloads")
        }
        .font(.system(size: 12.5, weight: .medium))
        .buttonStyle(.borderless)
        .disabled(isRemoving)
        .padding(.horizontal, Theme.Layout.contentInset)
        .padding(.top, 12)
    }

    private func removeSelection() {
        let ids = pendingRemoval, scope = removalScope
        guard !ids.isEmpty, downloads.accountScope == scope else { return }
        isRemoving = true
        Task {
            defer { isRemoving = false }
            guard downloads.accountScope == scope else { return }
            let succeeded = await downloads.deleteLocalAudio(trackIDs: ids)
            guard downloads.accountScope == scope else { return }
            selectedIDs.subtract(ids)
            pendingRemoval = []
            if !succeeded { ToastCenter.shared.show(String(localized: "部分下载未能移除，请重试")) }
        }
    }

    private func header(tracks: [Track]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                songCount(tracks: tracks)
                Spacer(minLength: 12)
                actionRow(tracks: tracks)
            }
            VStack(alignment: .leading, spacing: 12) {
                songCount(tracks: tracks)
                ViewThatFits(in: .horizontal) {
                    actionRow(tracks: tracks)
                    VStack(alignment: .leading, spacing: 8) {
                        downloadQueueButton
                        playAllButton(tracks: tracks)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.Layout.contentInset)
        .padding(.top, 12)
    }

    private func songCount(tracks: [Track]) -> some View {
        Text("已下载 \(tracks.count) 首")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func actionRow(tracks: [Track]) -> some View {
        HStack(spacing: 10) {
            downloadQueueButton
            playAllButton(tracks: tracks)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var downloadQueueButton: some View {
        Button {
            openDestination(.downloadTasks)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                Text("下载任务")
                if pendingCount > 0 { Text("\(pendingCount)").monospacedDigit() }
            }
            .font(.system(size: 12.5, weight: .medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.pressable)
    }

    private func playAllButton(tracks: [Track]) -> some View {
        Button {
            player.play(tracks: tracks, source: .none)
        } label: {
            Label("播放全部", systemImage: "play.fill")
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Theme.accentGradient, in: Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(tracks.isEmpty)
    }
}

/// Secondary download controls follow the music pages' spacing and row styling.
struct DownloadTasksView: View {
    @ObservedObject private var downloads = DownloadManager.shared
    @State private var confirmCancelAll = false

    private var displayedJobs: [DownloadJob] {
        let jobs = downloads.pendingJobs
        return jobs.filter { $0.status.isWorking } + jobs.filter { !$0.status.isWorking }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Text("任务：\(downloads.pendingJobs.count)")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    taskButton("全部暂停", icon: "pause.fill", enabled: downloads.pendingJobs.contains { [.queued, .resolving, .downloading, .waitingNetwork].contains($0.status) }) {
                        Task { await downloads.pauseAll() }
                    }
                    taskButton("继续全部", icon: "play.fill", enabled: downloads.pendingJobs.contains { $0.status.canResume }) {
                        let count = downloads.pendingJobs.filter { $0.status.canResume }.count
                        MeteredDownloadCenter.shared.request(bulk: true, count: count, network: downloads.network) { metered in
                            Task { await downloads.resumeAll(allowsMetered: metered) }
                        }
                    }
                    Menu {
                        Button("重试失败任务") {
                            let count = downloads.pendingJobs.filter { [.failed, .unavailable].contains($0.status) }.count
                            MeteredDownloadCenter.shared.request(bulk: true, count: count, network: downloads.network) { metered in
                                Task { await downloads.resumeAll(failedOnly: true, allowsMetered: metered) }
                            }
                        }
                        Button("取消未完成任务", role: .destructive) { confirmCancelAll = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(.primary.opacity(0.06), in: Circle())
                    }
                    #if os(macOS)
                    .menuStyle(.borderlessButton)
                    #endif
                    .fixedSize()
                    .accessibilityLabel("更多下载操作")
                    .disabled(downloads.pendingJobs.isEmpty)
                }
                .padding(.horizontal, Theme.Layout.contentInset)
                .padding(.top, 12)

                if downloads.pendingJobs.isEmpty {
                    EmptyStateView(icon: "arrow.down.circle", title: "暂无下载任务")
                        .frame(minHeight: 300)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(displayedJobs) { job in
                            DownloadTaskRow(job: job, manager: downloads, progress: downloads.progress)
                        }
                    }
                    .padding(.horizontal, Theme.Layout.contentInset - 10)
                }
                PlayerClearanceSpacer()
            }
        }
        .navigationTitle("下载任务")
        .task { await downloads.start() }
        .alert("取消未完成的下载？", isPresented: $confirmCancelAll) {
            Button("取消下载", role: .destructive) {
                Task { await downloads.cancelAll() }
            }
            Button("保留任务", role: .cancel) {}
        } message: { Text("已完成的下载会保留。") }
    }

    private func taskButton(_ title: LocalizedStringKey, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12.5, weight: .medium))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
    }
}

private struct DownloadTaskRow: View {
    let job: DownloadJob
    @ObservedObject var manager: DownloadManager
    @ObservedObject var progress: DownloadProgress
    @State private var isHovering = false
    @ScaledMetric(relativeTo: .body) private var artworkSize: CGFloat = 42
    private var waitsForWiFi: Bool {
        job.status == .waitingNetwork && manager.network.connected && !manager.network.permits(job)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(url: job.track.album.picUrl?.resizedImageURL(160), animated: false)
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.track.name).font(.body.weight(.medium)).lineLimit(1)
                        Text(job.track.artistNames).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if job.status.canResume {
                        control(job.status == .paused ? "play.fill" : "arrow.clockwise", title: "继续下载") {
                            MeteredDownloadCenter.shared.request(bulk: false, count: 1, network: manager.network) { metered in
                                Task { await manager.resume(job.id, allowsMetered: metered) }
                            }
                        }
                    } else if [.queued, .resolving, .downloading].contains(job.status) {
                        control("pause.fill", title: "暂停下载") { Task { await manager.pause(job.id) } }
                    }
                    control("xmark", title: "取消下载") { Task { await manager.cancel(job.id) } }
                }
                let value = progress.values[job.id]
                let received = value?.received ?? job.receivedBytes
                let expected = value?.expected ?? job.expectedBytes
                if [.downloading, .waitingNetwork, .paused].contains(job.status), expected > 0 {
                    ProgressView(value: min(1, Double(received) / Double(expected)))
                        .tint(Theme.accent).controlSize(.small)
                }
                HStack {
                    Text(job.errorMessage ?? (waitsForWiFi ? String(localized: "等待 Wi-Fi") : job.status.label))
                    Spacer(minLength: 8)
                    if expected > 0 {
                        Text("\(ByteCountFormatter.string(fromByteCount: received, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: expected, countStyle: .file))")
                            .monospacedDigit()
                    }
                }.font(.system(size: 11)).foregroundStyle(.secondary)
                if waitsForWiFi {
                    Button("使用当前网络下载") { Task { await manager.resume(job.id, allowsMetered: true) } }
                        .font(.system(size: 11.5)).buttonStyle(.plain).foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous)
            .fill(isHovering ? Color.primary.opacity(0.06) : .clear))
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .contain)
    }

    private func control(_ icon: String, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.callout.weight(.medium))
                #if os(macOS)
                .frame(width: 28, height: 28)
                #else
                .frame(width: 44, height: 44)
                #endif
        }
        .buttonStyle(.pressable)
        .foregroundStyle(.secondary)
        .accessibilityLabel(title)
    }
}

struct TrackDownloadActions: View {
    let track: Track
    let showsIcons: Bool
    @ObservedObject private var state: TrackDownloadState
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.openLogin) private var openLogin

    init(track: Track, showsIcons: Bool = false) {
        self.track = track
        self.showsIcons = showsIcons
        // Other songs' download changes must not rebuild this menu.
        _state = ObservedObject(wrappedValue: DownloadManager.shared.trackState(for: track.id))
    }

    private var downloads: DownloadManager { .shared }

    var body: some View {
        let job = state.value.menuJob
        if let job, job.status == .complete {
            Button(role: .destructive) { Task { await downloads.deleteLocalAudio(trackID: track.id) } } label: {
                actionLabel("移除下载", systemImage: "trash")
            }
        } else if let job, [.queued, .resolving, .downloading, .verifying, .waitingNetwork].contains(job.status) {
            if job.status != .verifying {
                Button { Task { await downloads.pause(job.id) } } label: { actionLabel("暂停下载", systemImage: "pause") }
            }
            Button(role: .destructive) { Task { await downloads.cancel(job.id) } } label: {
                actionLabel("取消下载", systemImage: "xmark")
            }
        } else if let job, job.status.canResume {
            Button { resume(job) } label: { actionLabel("继续下载", systemImage: "play") }
        } else {
            Button { enqueue() } label: { actionLabel("下载", systemImage: "arrow.down.circle") }
        }
    }

    @ViewBuilder
    private func actionLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        if showsIcons { Label(title, systemImage: systemImage) }
        else { Text(title) }
    }

    private func resume(_ job: TrackDownloadState.MenuJob) {
        MeteredDownloadCenter.shared.request(bulk: false, count: 1, network: downloads.network) { metered in
            Task { await downloads.resume(job.id, allowsMetered: metered) }
        }
    }

    private func enqueue() {
        guard account.isLoggedIn else { openLogin(); return }
        MeteredDownloadCenter.shared.request(bulk: false, count: 1, network: downloads.network) { metered in
            Task { await downloads.enqueue(track: track, quality: settings.downloadQuality.rawValue, allowsMetered: metered) }
        }
    }
}

struct DownloadCollectionButton: View {
    let tracks: [Track]
    let owner: String
    let name: String
    var enabled = true
    var compact = false
    @ObservedObject private var downloads = DownloadManager.shared
    @ObservedObject private var progress = DownloadManager.shared.progress
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.openLogin) private var openLogin
    @Environment(\.openDestination) private var openDestination
    @State private var isSubmitting = false
    @State private var confirmRemoval = false
    @State private var pendingRemoval: Set<Int> = []
    @State private var removalScope: String?
    @State private var isRemoving = false

    private var collectionJobs: [DownloadJob] { downloads.jobs.filter { $0.owners.contains(owner) } }
    private var downloadedIDs: Set<Int> {
        downloads.downloadedTrackIDs.intersection(tracks.map(\.id))
    }
    private var isComplete: Bool {
        !tracks.isEmpty && Set(tracks.map(\.id)).count == downloadedIDs.count
    }
    private var removalTitle: String {
        owner.hasPrefix("album:") ? String(localized: "要移除此专辑的所有下载吗？") : String(localized: "要移除此歌单的所有下载吗？")
    }
    private var removalAction: String {
        owner.hasPrefix("album:") ? String(localized: "移除专辑下载") : String(localized: "移除歌单下载")
    }
    private var isActive: Bool { collectionJobs.contains { $0.status.isInProgress } }
    private var canResume: Bool { collectionJobs.contains { $0.status.canResume && $0.status != .waitingNetwork } }
    private var fraction: Double? {
        let ids = Set(tracks.map(\.id))
        guard !ids.isEmpty else { return nil }
        let jobs = Dictionary(collectionJobs.map { ($0.track.id, $0) }, uniquingKeysWith: { first, _ in first })
        let saved = downloadedIDs
        let total = ids.reduce(0.0) { sum, id in
            sum + (jobs[id].flatMap { progress.fraction(for: $0) } ?? (saved.contains(id) ? 1 : 0))
        }
        return total > 0 ? total / Double(ids.count) : nil
    }
    private var title: String {
        if isActive || isSubmitting { return String(localized: "停止下载") }
        if canResume { return String(localized: "继续下载") }
        if isComplete { return removalAction }
        return String(localized: "下载全部")
    }

    var body: some View {
        Button(action: activate) {
            DownloadButtonIcon(isActive: isActive || isSubmitting, isComplete: isComplete && !canResume && !isActive,
                               progress: fraction, size: compact ? 21 : 19, symbolSize: compact ? 16 : 14,
                               completedSymbol: "checkmark")
                .foregroundStyle(Theme.accent)
                .frame(width: compact ? 38 : 34, height: compact ? 38 : 34)
                .background(.primary.opacity(0.06), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
        .accessibilityIdentifier("collection-download-\(owner)")
        .help(title)
        .disabled(isSubmitting || isRemoving || (!isActive && !canResume && (!enabled || tracks.isEmpty)))
        .alert(removalTitle, isPresented: $confirmRemoval) {
            Button("移除下载", role: .destructive) { removeDownloads() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("其他歌单中的相同歌曲也会移除下载。")
        }
        .onChange(of: downloads.accountScope) { _ in
            confirmRemoval = false
            pendingRemoval = []
        }
        .contextMenu {
            if collectionJobs.contains(where: { [.queued, .resolving, .downloading, .waitingNetwork].contains($0.status) }) {
                Button("暂停下载") {
                    Task { [scope = downloads.accountScope] in
                        guard downloads.accountScope == scope else { return }
                        await downloads.pauseCollection(owner)
                    }
                }
            }
            if canResume {
                Button("继续下载") {
                    let count = collectionJobs.filter { $0.status.canResume }.count
                    MeteredDownloadCenter.shared.request(bulk: true, count: count, network: downloads.network) { metered in
                        Task { [scope = downloads.accountScope] in
                            guard downloads.accountScope == scope else { return }
                            await downloads.resumeCollection(owner, allowsMetered: metered)
                        }
                    }
                }
            }
            if isActive || canResume {
                Button("停止下载") {
                    Task { [scope = downloads.accountScope] in
                        guard downloads.accountScope == scope else { return }
                        await downloads.cancelCollection(owner)
                    }
                }
            }
            if !downloadedIDs.isEmpty {
                Button(removalAction, role: .destructive) { requestRemoval() }
            }
            Button("下载任务") { openDestination(.downloadTasks) }
        }
    }

    private func activate() {
        guard !isSubmitting, !isRemoving else { return }
        if !isActive && !canResume && isComplete { requestRemoval(); return }
        guard account.isLoggedIn else { openLogin(); return }
        if isActive {
            isSubmitting = true
            Task { [scope = downloads.accountScope] in
                defer { isSubmitting = false }
                guard downloads.accountScope == scope else { return }
                await downloads.cancelCollection(owner)
            }
            return
        }
        MeteredDownloadCenter.shared.request(bulk: true, count: tracks.count, network: downloads.network) { metered in
            isSubmitting = true
            Task { [scope = downloads.accountScope] in
                defer { isSubmitting = false }
                guard downloads.accountScope == scope else { return }
                await downloads.resumeCollection(owner, allowsMetered: metered)
                guard downloads.accountScope == scope else { return }
                await downloads.enqueue(tracks: tracks, owner: owner, name: name,
                                        quality: settings.downloadQuality.rawValue, allowsMetered: metered)
            }
        }
    }

    private func requestRemoval() {
        pendingRemoval = downloadedIDs
        guard !pendingRemoval.isEmpty else { return }
        removalScope = downloads.accountScope
        confirmRemoval = true
    }

    private func removeDownloads() {
        let ids = pendingRemoval, scope = removalScope
        guard !ids.isEmpty, downloads.accountScope == scope, !isRemoving else { return }
        isRemoving = true
        Task {
            defer { isRemoving = false }
            guard downloads.accountScope == scope else { return }
            let succeeded = await downloads.deleteLocalAudio(trackIDs: ids)
            guard downloads.accountScope == scope else { return }
            pendingRemoval = []
            if !succeeded { ToastCenter.shared.show(String(localized: "部分下载未能移除，请重试")) }
        }
    }
}
