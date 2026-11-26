import SwiftUI

/// 私人漫游 — immersive personal FM page.
struct FMView: View {
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var account: AccountStore
    @Environment(\.openLogin) private var openLogin
    @Environment(\.colorScheme) private var colorScheme
    #if os(iOS)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var artwork: PlatformImage?
    @State private var previousArtwork: PlatformImage?
    @State private var artworkRevision = 0
    #endif

    private var isPhone: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            backdrop
            if account.hasAuthCookie {
                content
            } else {
                loginPrompt
            }
        }
        .navigationTitle("漫游")
        .compatHiddenToolbarBackground()
        // 横屏不要那条系统顶栏（右半会露出一块材质），标题自己画在左上角。
        .toolbar(isLandscape ? .hidden : .visible, for: .navigationBar)
        #if os(iOS)
        .task(id: artworkURL) { await loadArtwork() }
        #endif
    }

    private var track: Track? {
        player.isFMMode ? player.currentTrack : nil
    }

    #if os(iOS)
    private var artworkURL: URL? { track?.album.picUrl?.resizedImageURL(768) }

    private func loadArtwork() async {
        guard let url = artworkURL else {
            previousArtwork = nil
            artwork = nil
            return
        }
        let image = await ImageCache.shared.image(for: url)
        guard !Task.isCancelled, artworkURL == url else { return }
        // Leave the previous cover in place until the next image is decoded.
        previousArtwork = image == nil || reduceMotion ? nil : artwork
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
            artwork = image
            artworkRevision += 1
        }
    }

    private var artworkLayers: some View {
        ZStack {
            if let previousArtwork {
                Image(platformImage: previousArtwork).resizable().scaledToFill()
                    .accessibilityHidden(true)
            }
            if let artwork {
                Image(platformImage: artwork).resizable().scaledToFill()
                    .id(artworkRevision)
                    .zIndex(1)
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))
                    .accessibilityHidden(true)
            }
        }
    }
    #endif

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            Platform.windowBackgroundColor
            #if os(iOS)
            GeometryReader { geo in
                artworkLayers
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .blur(radius: 80)
                    .opacity(colorScheme == .dark ? 0.45 : 0.3)
                    .saturation(1.4)
            }
            #else
            if let cover = track?.album.picUrl?.resizedImageURL(384) {
                CachedAsyncImage(url: cover)
                    .scaledToFill()
                    .blur(radius: 80)
                    .opacity(colorScheme == .dark ? 0.45 : 0.3)
                    .saturation(1.4)
            }
            #endif
            LinearGradient(
                colors: [.clear, Platform.windowBackgroundColor.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        #if os(macOS)
        .animation(AppAnimation.smooth, value: track?.id)
        #endif
    }

    // MARK: - Content

    /// 横屏判定：`GeometryReader` 在导航栈里拿到的尺寸偶尔还是竖屏形状，
    /// 所以先用窗口方向兜底（安卓那边同一处也踩过这个坑）。
    private var isLandscape: Bool {
        #if os(iOS)
        if UIDevice.current.orientation.isLandscape { return true }
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            return scene.interfaceOrientation.isLandscape
        }
        #endif
        return false
    }

    private var content: some View {
        GeometryReader { geo in
            #if os(iOS)
            if isLandscape || geo.size.width > geo.size.height {
                landscape(geo)
            } else {
                centered(geo)
            }
            #else
            centered(geo)
            #endif
        }
    }

    /// 竖屏：封面 + 歌名 / 歌手 + 四个按钮，原本的样子。
    private func centered(_ geo: GeometryProxy) -> some View {
            let maxDim: CGFloat = isPhone ? 240 : 300
            let coverDimension = max(110, min(maxDim, min(geo.size.width - 48, geo.size.height * 0.38)))
            let spacing: CGFloat = isPhone ? (geo.size.height < 520 ? 12 : 20) : 28

            return VStack(spacing: spacing) {
                Spacer()

                coverArt(coverDimension)
                .scaleEffect(player.isPlaying && player.isFMMode ? 1 : 0.94)
                .animation(AppAnimation.bouncy, value: player.isPlaying && player.isFMMode)

                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text(track?.name ?? String(localized: "私人漫游"))
                            .font(
                                .system(
                                    size: isPhone && geo.size.height < 520 ? 18 : 22,
                                    weight: .bold
                                )
                            )
                            .lineLimit(1)
                        if track?.fee == 1 {
                            VIPBadge()
                        }
                    }
                    Text(track?.artistNames ?? String(localized: "根据你的口味漫游好音乐"))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: 420)
                #if os(iOS)
                .contentTransition(reduceMotion ? .identity : .opacity)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: track?.id)
                #endif

                if player.isFMMode {
                    controls
                } else {
                    Button {
                        player.startFM()
                    } label: {
                        Label("开始漫游", systemImage: "wave.3.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Theme.accentGradient, in: Capsule())
                            .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 3)
                    }
                    .buttonStyle(.pressable)
                }

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
    }

    /// 横屏：只留封面——歌名、歌手、四个按钮都不画。
    /// 方框 = 播放控制器左右为宽（底栏 playWidth 同一公式）、屏幕上下为高再让出播放条的安全距离；
    /// 封面取短边 88%，落在这个方框的对角线中心。
    #if os(iOS)
    @ViewBuilder
    private func landscape(_ geo: GeometryProxy) -> some View {
        // 没开启漫游时，整页只留一个「开始漫游」按钮——不要拿别的队列的歌充数。
        if !player.isFMMode {
            VStack {
                Spacer()
                Button {
                    player.startFM()
                } label: {
                    Label("开始漫游", systemImage: "wave.3.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Theme.accentGradient, in: Capsule())
                        .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 3)
                }
                .buttonStyle(.pressable)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            landscapeStage(geo)
        }
    }

    private func landscapeStage(_ geo: GeometryProxy) -> some View {
        let screenW = max(geo.size.width, geo.size.height)
        let screenH = min(geo.size.width, geo.size.height)
        let inset: CGFloat = 12
        let playerWidth = inset + min(336, max(218, (screenW - 24) * 0.38))
        let bottomClearance: CGFloat = 96
        let boxW = max(80, playerWidth - inset)
        // 封面以「整屏竖直中线」为中心；可用高度取中线到播放条之间能放下的最大正方形，
        // 这样既居中又不会压到播放条。
        let barTop = screenH - bottomClearance
        let halfSpan = max(40, min(boxW / 2 - 16, barTop - 12 - screenH / 2))
        let side = max(80, halfSpan * 2 * 0.88)
        // `let` 之后必须显式 return，否则 opaque return type 推断不出来。
        return ZStack(alignment: .topLeading) {
            Text("漫游")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.leading, 20)
                .padding(.top, 6)
            coverArt(side)
                .frame(width: boxW, height: screenH, alignment: .center)
                .padding(.leading, inset)
            // 右半 = 播放器歌词的原样投影（同一个 PlayerLyricsList，仅换配色与字号）。
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                PlayerLyricsList(
                    // 上下各留半屏：第一句和最后一句都能滚到屏幕中线，与播放页的
                    // `scrollTo(anchor: .center)` 位置完全一致。
                    topInset: max(0, screenH / 2 - 24),
                    bottomInset: max(0, screenH / 2 - 24),
                    horizontalPadding: 14,
                    primaryColor: .primary,
                    secondaryColor: .primary,
                    activeSize: 26,
                    idleSize: 20,
                    annotationSize: 15,
                    highlightColor: .black,
                    // 非当前行 = 当前行「未擦亮」那一截的浓度（0.28），且不再叠行级淡出。
                    inactiveOpacity: 0.28,
                    idleRowOpacity: 1
                )
                // 高度必须给成整屏：否则 ScrollView 只按内容撑开，`anchor: .center`
                // 就没有可视窗口可居中，当前行会停在顶部。
                .frame(width: screenW / 2, height: screenH)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: player.lyrics == nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    #endif

    private func coverArt(_ size: CGFloat) -> some View {
        #if os(iOS)
        ZStack {
            coverPlaceholder(size)
            artworkLayers
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 28, y: 14)
        #else
        ZStack {
            if let cover = track?.album.picUrl?.resizedImageURL(768) {
                CachedAsyncImage(url: cover)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 28, y: 14)
            } else {
                coverPlaceholder(size)
            }
        }
        #endif
    }

    private func coverPlaceholder(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.quaternary.opacity(0.4))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "wave.3.right.circle")
                    .font(.system(size: max(32, size * 0.25), weight: .light))
                    .foregroundStyle(.tertiary)
            )
    }

    private var controls: some View {
        HStack(spacing: 26) {
            Button {
                player.fmTrash()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.pressable)
            .help("不喜欢，换一首")

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.accentGradient)
                        .frame(width: 64, height: 64)
                        .shadow(color: Theme.accent.opacity(0.4), radius: 12, y: 4)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.opacity)
                }
            }
            .buttonStyle(.pressable)

            Button {
                player.fmNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.pressable)
            .help("下一首")

            if let track {
                LikeButton(trackID: track.id, size: 16)
                    .frame(width: 48, height: 48)
                    .background(.primary.opacity(0.06), in: Circle())
            }
        }
    }

    private var loginPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "wave.3.right.circle")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tertiary)
            Text("登录后开启私人漫游")
                .font(.headline)
            Text("根据你的听歌口味推荐音乐")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("登录") { openLogin() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
    }
}
