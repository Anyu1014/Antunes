import SwiftUI

/// 听歌排行 — 照搬备用源码 MeloX 的 `/v1/play/record`：
/// 最近一周 / 所有时间两档，按播放次数排序，点一行从那首开始播整张榜。
struct ListeningRankView: View {
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var account: AccountStore
    @Environment(\.isLandscapeWindow) private var isLandscape

    @State private var week = true
    @State private var records: [PlayRecord] = []
    @State private var weekRecords: [PlayRecord] = []
    @State private var allRecords: [PlayRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var displayedKey: LoadKey?

    private struct LoadKey: Hashable {
        let ownerID: Int?
        let week: Bool? // nil means both columns are displayed.
    }

    private var loadKey: LoadKey {
        LoadKey(ownerID: account.authenticatedAccountID, week: isLandscape ? nil : week)
    }

    private var visibleError: String? {
        displayedKey == loadKey ? errorMessage : nil
    }

    var body: some View {
        let key = loadKey
        Group {
            if isLandscape {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        column(records: displayedKey == key ? weekRecords : [], periodWeek: true)
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 0.5)
                        column(records: displayedKey == key ? allRecords : [], periodWeek: false)
                    }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            // Leave room for Back without shifting the headings away from the two columns.
                            HStack(spacing: geometry.size.width * 0.25) {
                                periodButton("最近一周", periodWeek: true)
                                periodButton("所有时间", periodWeek: false)
                            }
                            .frame(width: geometry.size.width * 0.75)
                        }
                    }
                }
            } else {
                portraitBody
            }
        }
        .navigationTitle(isLandscape ? Text(verbatim: "") : Text("听歌排行"))
        .navigationBarTitleDisplayMode(.inline)
        .progressiveTopBarInLandscape()
        .task(id: key) { await load(key) }
    }

    private func periodButton(_ title: LocalizedStringKey, periodWeek: Bool) -> some View {
        Button {
            week = periodWeek
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(week == periodWeek ? Theme.accent : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(week == periodWeek ? .isSelected : [])
    }

    private func column(records: [PlayRecord], periodWeek: Bool) -> some View {
        Group {
            if let visibleError {
                Text(visibleError).font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if (isLoading || displayedKey != loadKey), records.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            } else if records.isEmpty {
                Text("还没有听歌记录")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                List {
                    Section {
                        ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                            Button {
                                playAll(records: records, from: record)
                            } label: {
                                row(index: index, record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        Text(periodWeek ? "最近一周播放次数最多的歌" : "按总播放次数排序")
                    }
                }
                .listStyle(.plain)
                .compatSymmetricTopEdgeEffect()
                // 底部迷你播放条浮在内容上，留出它的高度，最后一行不会被压住。
                .safeAreaInset(edge: .bottom, spacing: 0) { PlayerClearanceSpacer() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var portraitBody: some View {
        let records = displayedKey == loadKey ? self.records : []
        return List {
            Section {
                Picker("", selection: $week) {
                    Text("最近一周").tag(true)
                    Text("所有时间").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if let visibleError {
                Text(visibleError)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if (isLoading || displayedKey != loadKey), records.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 220)
            } else if records.isEmpty, visibleError == nil {
                EmptyStateView(icon: "chart.bar.xaxis", title: "还没有听歌记录")
                    .frame(minHeight: 260)
            } else {
                Section {
                    ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                        Button {
                            playAll(records: records, from: record)
                        } label: {
                            row(index: index, record: record)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text(week ? "最近一周播放次数最多的歌" : "按总播放次数排序")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { PlayerClearanceSpacer() }
    }

    private func row(index: Int, record: PlayRecord) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .center)
            CachedAsyncImage(url: record.song.album.picUrl?.resizedImageURL(96))
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(record.song.name)
                    .font(.system(size: 15))
                    .lineLimit(1)
                    .foregroundStyle(player.currentTrack?.id == record.song.id ? Theme.accent : .primary)
                Text(record.song.artistNames)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("\(record.playCount) 次")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.song.name)，播放 \(record.playCount) 次")
    }

    private func playAll(records list: [PlayRecord], from record: PlayRecord) {
        let tracks = list.map(\.song)
        player.play(tracks: tracks, source: .none, startAt: record.song)
    }

    private func load(_ key: LoadKey) async {
        func isCurrent() -> Bool { !Task.isCancelled && loadKey == key }
        guard isCurrent() else { return }
        displayedKey = key
        records = []
        weekRecords = []
        allRecords = []
        errorMessage = nil
        guard let uid = key.ownerID else {
            errorMessage = account.hasAuthCookie
                ? String(localized: "账号资料尚未就绪") : String(localized: "登录后才有听歌排行")
            isLoading = false
            return
        }
        isLoading = true
        do {
            if let week = key.week {
                let result = try await MusicAPI.userPlayRecords(userID: uid, week: week)
                guard isCurrent() else { return }
                records = result
            } else {
                async let recent = MusicAPI.userPlayRecords(userID: uid, week: true)
                async let all = MusicAPI.userPlayRecords(userID: uid, week: false)
                let (weeks, totals) = try await (recent, all)
                guard isCurrent() else { return }
                weekRecords = weeks
                allRecords = totals
            }
        } catch {
            guard isCurrent() else { return }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
