import SwiftUI

#if os(iOS)
struct IOSPlaybackQueueView: View {
    @EnvironmentObject private var player: PlayerService
    let backdrop: ArtworkColors
    @EnvironmentObject private var toasts: ToastCenter

    var body: some View {
        let entries = player.playbackList
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    PlaybackHandoffList()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    if !entries.isEmpty {
                        ForEach(entries) { entry in
                            PlaybackQueueRow(entry: entry)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 28, weight: .light))
                            Text("播放队列是空的")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
                .padding(10)
            }
            .navigationTitle("播放列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(entries.count) 首")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .background(queueBackdrop)
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if let toast = toasts.current {
                ToastView(toast: toast).padding(.top, 8)
            }
        }
    }

    private var queueBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [backdrop.primary, backdrop.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Color.black.opacity(0.45)
        }
        .ignoresSafeArea()
    }
}

private struct PlaybackQueueRow: View {
    let entry: PlaybackQueuePlan.ListEntry
    private var track: Track { entry.track }

    @EnvironmentObject private var player: PlayerService

    var body: some View {
        Button {
            player.jumpToPlaylistEntry(entry)
        } label: {
            HStack(spacing: 10) {
                CachedAsyncImage(url: track.album.picUrl?.resizedImageURL(96), animated: false)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(entry.isCurrent ? Theme.accent : .primary)
                        .lineLimit(1)
                    Text(track.artistNames)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if entry.isCurrent {
                    PlayingIndicator(animating: player.isPlaying)
                } else {
                    Text(Formatters.duration(track.duration))
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(entry.isCurrent ? .isSelected : [])
    }
}
#endif
