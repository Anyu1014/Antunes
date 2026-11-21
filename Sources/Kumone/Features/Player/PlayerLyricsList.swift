import SwiftUI

/// 歌词列表的唯一实现：播放页与漫游横屏都挂这一份，后者只换容器与配色。
/// 当前行滚动后始终落在容器竖直中点（`scrollTo(anchor: .center)`）。
struct PlayerLyricsList: View {
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var settings: SettingsManager
    @ObservedObject private var lyricsCursor = PlayerService.shared.lyricsCursor

    var topInset: CGFloat = 120
    var bottomInset: CGFloat = 180
    var horizontalPadding: CGFloat = 32
    var primaryColor: Color = .white
    var secondaryColor: Color = .white
    var activeSize: CGFloat = 26
    var idleSize: CGFloat = 20
    var annotationSize: CGFloat = 15
    /// 擦亮（逐字跟随）那段文字的颜色；播放器白字，漫游浅底用黑字。
    var highlightColor: Color = .white
    /// 非当前行的字色透明度（播放页 0.45；漫游要和「当前行未擦亮那截」一致，传 0.28）。
    var inactiveOpacity: Double = 0.45
    /// 非当前行整行的额外淡出（播放页 0.72；漫游传 1，避免和 0.28 叠加后更淡）。
    var idleRowOpacity: Double = 0.72

    @State private var activeIndex: Int?
    @State private var isUserScrolling = false
    private static var lastScrollAt = Date.distantPast

    var body: some View {
        if let lyrics = player.lyrics, !lyrics.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        Color.clear.frame(height: topInset)
                        ForEach(lyrics.lines) { line in
                            lyricLine(line, isActive: line.id == activeIndex)
                                .id(line.id)
                        }
                        Color.clear.frame(height: bottomInset)
                    }
                    .padding(.horizontal, horizontalPadding)
                }
                .lyricsScrollTracking(isUserScrolling: $isUserScrolling)
                .id(player.currentTrack?.id)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.12),
                            .init(color: .black, location: 0.85),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .onChange(of: lyricsCursor.activeIndex) { index in
                    guard index != activeIndex else { return }
                    activeIndex = index
                    guard !isUserScrolling, let index else { return }
                    // 歌词时间戳重复/倒挂时游标可能在两行之间来回跳，这里限速，
                    // 免得每一跳都起一次 spring 动画把主线程压死。
                    let now = Date()
                    guard now.timeIntervalSince(Self.lastScrollAt) > 0.18 else { return }
                    Self.lastScrollAt = now
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
                .onAppear {
                    adoptCursor(proxy: proxy)
                }
                .onChange(of: player.currentTrack?.id) { _ in
                    activeIndex = nil
                    isUserScrolling = false
                }
            }
        } else if player.lyrics?.isInstrumental == true {
            VStack(spacing: 10) {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(primaryColor.opacity(0.4))
                Text("纯音乐，请欣赏")
                    .font(.system(size: 15))
                    .foregroundStyle(primaryColor.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView()
                .controlSize(.small)
                .tint(primaryColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Jump straight to the line the song is on. Used when the view appears,
    /// where waiting for the next line change would leave the lyrics parked at
    /// the top. Scrolling is deferred a turn: the list has not laid out yet
    /// while `onAppear` runs, and `scrollTo` on an unlaid list does nothing.
    private func adoptCursor(proxy: ScrollViewProxy) {
        let index = lyricsCursor.activeIndex
        activeIndex = index
        guard let index else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(index, anchor: .center)
        }
    }

    private func lyricLine(_ line: LyricLine, isActive: Bool) -> some View {
        Button {
            player.seek(to: line.time)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                if settings.lyricsAnnotation == .romaji, let romaji = line.romaji {
                    Text(romaji)
                        .font(.system(size: isActive ? annotationSize : annotationSize - 2, weight: .medium))
                        .foregroundStyle(secondaryColor.opacity(isActive ? 0.7 : 0.35))
                }
                LyricMainText(
                    line: line, isActive: isActive,
                    size: isActive ? activeSize : idleSize, weight: isActive ? .bold : .semibold,
                    verbatim: settings.verbatimLyrics,
                    inactiveOpacity: inactiveOpacity,
                    highlightColor: highlightColor
                )
                if settings.showLyricsTranslation, let translation = line.translation {
                    Text(translation)
                        .font(.system(size: isActive ? annotationSize + 1 : annotationSize - 1, weight: .medium))
                        .foregroundStyle(secondaryColor.opacity(isActive ? 0.7 : 0.35))
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(isActive || isUserScrolling ? 1 : idleRowOpacity)
            .scaleEffect(isActive ? 1.02 : 1, anchor: .leading)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
        .animation(.easeOut(duration: 0.25), value: isUserScrolling)
    }
}
