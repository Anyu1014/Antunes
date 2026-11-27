import SwiftUI

#if os(iOS)
struct IOSPlaybackQueueView: View {
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if #available(iOS 16.4, *) {
                content.presentationBackground(.regularMaterial)
            } else {
                content.background(.regularMaterial)
            }
        }
        .presentationDetents([.fraction(0.78), .large])
        .presentationDragIndicator(.visible)
    }

    private var content: some View {
        let entries = player.playbackList
        return VStack(spacing: 0) {
            HStack {
                Text("播放列表").font(.headline).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("完成") { dismiss() }
            }
            .padding(.top, 22)
            .padding(.bottom, 10)
            .padding(.horizontal, 20)

            HStack {
                Text("\(entries.count) 首歌曲")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Button(action: player.cyclePlaybackMode) {
                    Text(playbackMode)
                }
                .disabled(player.isFMMode)
            }
            .font(.subheadline)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        PlaybackHandoffList()
                        ForEach(entries) { entry in
                            PlaybackQueueRow(entry: entry)
                                .id(entry.id)
                        }
                        if entries.isEmpty {
                            Text("播放队列是空的")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 160)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    guard let current = entries.first(where: \.isCurrent) else { return }
                    DispatchQueue.main.async {
                        proxy.scrollTo(current.id, anchor: .center)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if let toast = toasts.current {
                ToastView(toast: toast).padding(.top, 8)
            }
        }
    }

    private var playbackMode: LocalizedStringKey {
        if player.shuffleEnabled { return "随机播放" }
        switch player.repeatMode {
        case .off: return "顺序播放"
        case .all: return "列表循环"
        case .one: return "单曲循环"
        }
    }
}

private struct PlaybackQueueRow: View {
    let entry: PlaybackQueuePlan.ListEntry
    private var track: Track { entry.track }

    @EnvironmentObject private var player: PlayerService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 2) {
            Button {
                player.jumpToPlaylistEntry(entry)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    CachedAsyncImage(url: track.album.picUrl?.resizedImageURL(96), animated: false)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(entry.isCurrent ? Theme.accent : .primary)
                            .lineLimit(1)
                        Text(track.artistNames)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if entry.isCurrent {
                        PlayingIndicator(animating: player.isPlaying)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(entry.isCurrent ? .isSelected : [])

            if !entry.isCurrent {
                Button {
                    player.removePlaylistEntry(entry)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("从队列移除：\(track.name)")
            }
        }
        .padding(.leading, 8)
    }
}
#endif
