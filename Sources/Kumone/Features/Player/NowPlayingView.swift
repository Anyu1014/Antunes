import SwiftUI

/// Immersive full-window now-playing page: artwork-tinted gradient backdrop,
/// large artwork on the left, big synced lyrics on the right.
struct NowPlayingView: View {
    let onOpenDestination: (Destination) -> Void

    @EnvironmentObject private var player: PlayerService
    @ObservedObject private var lyricsCursor = PlayerService.shared.lyricsCursor
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var settings: SettingsManager
    #if os(macOS)
    @EnvironmentObject private var artworkStore: NowPlayingArtworkStore
    #endif
    #if os(iOS)
    @Environment(\.dismissNowPlayingAction) private var dismissNowPlayingAction
    @Environment(\.dismissNowPlayingDragAction) private var dismissNowPlayingDragAction
    #endif

    #if os(iOS)
    @State private var loadedArtwork = CachedImageState()
    @State private var loadedArtworkColors: ArtworkColors = .fallback
    #endif
    @State private var showLyricsOnMobile = false
    @State private var showQueueOnMobile = false
    /// Lyrics or comments in the regular page's right column (macOS, iPad).
    @State private var regularColumnPage = RegularColumnPage.lyrics
    #if os(iOS)
    @State private var showSoundEffects = false
    /// Held here rather than by the controls so the panel can sit above the
    /// whole page, with a catcher that closes it on a tap anywhere else.
    @State private var showsVolumeControl = false
    /// 底部「评论区」按钮弹出的评论面板。
    @State private var bottomCommentsTrack: Track?
    #endif

    var body: some View {
        GeometryReader { geo in
            #if os(iOS)
            let isCompact = geo.size.width < 720 && geo.size.width <= geo.size.height
            #else
            let isCompact = geo.size.width < 720
            #endif
            ZStack {
                backdrop

                if isCompact {
                    compactLayout(size: geo.size)
                } else {
                    #if os(iOS)
                    switch settings.landscapeNowPlayingStyle {
                    case .classic:
                        regularLayout(size: geo.size)
                    case .immersive:
                        landscapeImmersiveLayout(size: geo.size)
                    }
                    #else
                    regularLayout(size: geo.size)
                    #endif
                }
            }
            // Pin to the screen width so an intrinsically-wide child can never
            // stretch the ZStack and push the corner overlays off-screen.
            .frame(width: geo.size.width)
            #if os(iOS)
            .overlayPreferenceValue(CompactVolumeButtonAnchorKey.self) { anchor in
                volumeLayer(buttonAnchor: anchor)
            }
            #endif
            #if os(macOS)
            .overlay(alignment: .topTrailing) {
                // Toward the top-trailing corner, level with the window
                // buttons (#128): a 36pt bubble whose center matches the 14pt
                // traffic lights (y 19…33 inside the 52pt titlebar). Clear of
                // the leading corner, where the sidebar toggle sits on the
                // page below.
                collapseButton(diameter: 36, glyphSize: 14)
                    .padding(.top, 8)
                    .padding(.trailing, 24)
            }
            #else
            .overlay(alignment: .topLeading) {
                if showsClassicChrome(isCompact: isCompact) {
                    collapseButton(diameter: 36, glyphSize: 14)
                        .padding(.top, 20)
                        .padding(.leading, 20)
                }
            }
            #endif
            .overlay(alignment: .topTrailing) {
                if isCompact, showsClassicChrome(isCompact: isCompact) {
                    HStack(spacing: 8) {
                        #if os(iOS)
                        SoundEffectsButton(
                            action: { showSoundEffects = true },
                            diameter: 36,
                            glyphSize: 14
                        )
                        #endif

                        Button {
                            withAnimation(AppAnimation.standard) {
                                showLyricsOnMobile.toggle()
                            }
                        } label: {
                            Image(systemName: showLyricsOnMobile ? "music.note" : "quote.bubble")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(showLyricsOnMobile ? Theme.accent : .white.opacity(0.85))
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.pressable)
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                }
            }
            #if os(iOS)
            .overlay {
                if settings.nowPlayingMode == .minimal && showQueueOnMobile {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { showQueueOnMobile = false }
                        .accessibilityLabel("关闭播放列表")
                        .accessibilityAddTraits(.isButton)
                }
            }
            #endif
        }
        #if os(macOS)
        // The window toolbar is hidden while this page is up, but SwiftUI keeps
        // reserving its safe area, which pushed the whole immersive layout —
        // close button included — a toolbar's height down from the window top.
        // iOS keeps its safe area: there the inset is the status bar / notch.
        .ignoresSafeArea()
        #endif
        .preferredColorScheme(.dark)
        #if os(iOS)
        .soundEffectsPresentation(
            isPresented: $showSoundEffects,
            settings: settings
        )
        .modifier(OfflinePlaybackAlert(player: player, onDownloads: { onOpenDestination(.downloaded) },
            enabled: player.showNowPlaying && !(settings.nowPlayingMode == .minimal && showQueueOnMobile)))
        .modifier(MeteredDownloadAlert(enabled: player.showNowPlaying && !(settings.nowPlayingMode == .minimal && showQueueOnMobile)))
        #endif
        #if os(iOS)
        .task(id: currentArtworkURL) {
            await loadArtwork()
        }
        #endif
        #if os(iOS)
        .onAppear {
            showLyricsOnMobile = settings.nowPlayingMode == .immersive
            showQueueOnMobile = false
        }
        .onChange(of: settings.nowPlayingMode) { _ in
            showLyricsOnMobile = settings.nowPlayingMode == .immersive
            showQueueOnMobile = false
        }
        .onChange(of: player.currentTrack?.id) { _ in
            if settings.nowPlayingMode == .minimal || settings.nowPlayingMode == .vinyl {
                showLyricsOnMobile = false
            }
        }
        #endif
        #if os(macOS)
        .onExitCommand {
            close()
        }
        #endif
    }

    private var hasLyricsColumn: Bool {
        if let lyrics = player.lyrics, !lyrics.isEmpty { return true }
        return player.lyrics == nil // still loading — keep layout stable
    }

    private func close() {
        #if os(iOS)
        if let dismissNowPlayingAction {
            dismissNowPlayingAction()
        } else {
            withAnimation(NowPlayingPresentationMetrics.presentationAnimation) {
                player.showNowPlaying = false
            }
        }
        #else
        player.showNowPlaying = false
        #endif
    }

    private func showsClassicChrome(isCompact: Bool) -> Bool {
        #if os(iOS)
        return !isCompact || settings.nowPlayingMode == .classic
        #else
        return true
        #endif
    }

    /// Collapse back to the browse UI. Shared by both platforms so the macOS
    /// layout can park it beside the window buttons (#128).
    private func collapseButton(diameter: CGFloat, glyphSize: CGFloat) -> some View {
        Button {
            close()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: diameter, height: diameter)
                .background(.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Backdrop

    private var artworkImage: PlatformImage? {
        #if os(macOS)
        artworkStore.artwork
        #else
        loadedArtwork.image(for: currentArtworkURL)
        #endif
    }

    private var colors: ArtworkColors {
        #if os(macOS)
        artworkStore.colors
        #else
        artworkImage == nil ? .fallback : loadedArtworkColors
        #endif
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [colors.primary, colors.secondary],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [.white.opacity(0.12), .clear],
                center: .topLeading, startRadius: 0, endRadius: 700
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.35)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: colors)
    }

    #if os(iOS)
    private var currentArtworkURL: URL? {
        player.currentTrack?.album.picUrl?.resizedImageURL(768)
    }

    private func loadArtwork() async {
        loadedArtworkColors = .fallback
        guard let urlString = player.currentTrack?.album.picUrl,
              let url = currentArtworkURL else {
            loadedArtwork = CachedImageState()
            return
        }
        loadedArtwork = CachedImageState(url: url)
        let image = await ImageCache.shared.image(for: url) { preview in
            applyArtwork(preview, for: url, cacheKey: urlString)
        }
        if let image { applyArtwork(image, for: url, cacheKey: urlString) }
    }

    private func applyArtwork(_ image: PlatformImage, for url: URL, cacheKey: String) {
        guard !Task.isCancelled, currentArtworkURL == url else { return }
        loadedArtwork.finish(image, for: url)
        loadedArtworkColors = ArtworkPalette.extract(from: image, cacheKey: cacheKey)
    }
    #endif

    // MARK: - Layouts

    private func regularLayout(size: CGSize) -> some View {
        // Everything below the artwork needs ~300pt; shrink the artwork on
        // short displays (iPhone landscape) instead of clipping it.
        let artworkSize = max(120, min(340, size.width * 0.32, size.height - 300))
        // Cap the two-column band and centre it. Spreading each column to
        // `.infinity` across an ultra-wide display (iPad landscape, ~1368pt)
        // left the left column's content floating in an oversized half and a
        // wide blank gutter on the right (#62).
        let maxBandWidth: CGFloat = hasRegularRightColumn ? 1040 : 560
        return HStack(spacing: 0) {
            leftColumn(artworkSize: artworkSize)
                .frame(maxWidth: .infinity)
            if hasRegularRightColumn {
                regularRightColumn
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: maxBandWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 48)
        .padding(.vertical, size.height < 500 ? 24 : 40)
    }

    #if os(iOS)
    /// Reference layout: cover and transport at left, lyrics or comments at right.
    private func landscapeImmersiveLayout(size: CGSize) -> some View {
        let gap = min(26, max(12, size.height * 0.06))
        let side = min(48, max(24, size.width * 0.05))
        let artworkSize = min(168, max(68, size.height * 0.26))
        // Reduce the downward offset on short screens to leave room at the bottom.
        let controlsOffset = min(14, max(0, (size.height - 260) / 5))
        let lyricInset = max(42, size.height * 0.4)
        return HStack(spacing: side) {
            VStack(spacing: gap) {
                artworkView(size: artworkSize)
                    .scaleEffect(1.08)
                VStack(spacing: gap) {
                    trackMetaView
                    VStack(spacing: 14) {
                        NowPlayingScrubber()
                        landscapeTransportRow
                    }
                }
                .offset(y: controlsOffset)
            }
            .frame(maxWidth: 380)
            .frame(maxWidth: .infinity)

            Group {
                if regularColumnPage == .comments, let track = commentsTrack {
                    RegularCommentsPanel(track: track)
                        .id(track.id)
                } else {
                    lyricsScroll(topInset: lyricInset, bottomInset: lyricInset, horizontalPadding: 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: 1040)
        .padding(.horizontal, side)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var landscapeTransportRow: some View {
        let showsComments = regularColumnPage == .comments && commentsTrack != nil
        return HStack(spacing: 0) {
            Group {
                if let track = player.currentTrack {
                    let liked = account.isLiked(track.id)
                    circleButton(icon: liked ? "heart.fill" : "heart", size: 15, tint: liked ? Theme.accent : nil) {
                        Task { await account.toggleLike(trackID: track.id) }
                    }
                    .accessibilityLabel(liked ? "取消喜欢" : "喜欢")
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
            }
            .frame(maxWidth: .infinity)

            // 横屏这一排和竖屏、紧凑版保持一致：漫游里"上一首"没有意义，
            // 换成就地删除（不喜欢），把当前这首从漫游队列里剔掉。
            if player.isFMMode {
                circleButton(icon: "trash", size: 16) { player.fmTrash() }
                    .accessibilityLabel("不喜欢，换一首")
                    .frame(maxWidth: .infinity)
            } else {
                circleButton(icon: "backward.fill", size: 16) { player.previous() }
                    .accessibilityLabel("上一首")
                    .frame(maxWidth: .infinity)
            }
            playPauseButton()
                .frame(maxWidth: .infinity)
            circleButton(icon: "forward.fill", size: 16) { player.next() }
                .accessibilityLabel("下一首")
                .frame(maxWidth: .infinity)

            circleButton(icon: showsComments ? "quote.bubble" : "text.bubble",
                         size: 16, tint: showsComments ? Theme.accent : nil) {
                regularColumnPage = showsComments ? .lyrics : .comments
            }
            .disabled(commentsTrack == nil)
            .accessibilityLabel(showsComments ? "显示歌词" : "显示评论")
            .accessibilityAddTraits(showsComments ? .isSelected : [])
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("landscapeTransportRow")
    }
    #endif

    @ViewBuilder
    private func compactLayout(size: CGSize) -> some View {
        #if os(iOS)
        switch settings.nowPlayingMode {
        case .vinyl:
            vinylCompactLayout(size: size)
        case .classic:
            classicCompactLayout(size: size)
        case .immersive:
            immersiveCompactLayout(size: size)
        case .minimal:
            minimalCompactLayout(size: size)
        }
        #else
        switch settings.nowPlayingMode {
        case .vinyl:
            vinylCompactLayout(size: size)
        default:
            classicCompactLayout(size: size)
        }
        #endif
    }

    private func vinylCompactLayout(size: CGSize) -> some View {
        let discDimension = min(size.width - 64, size.height * 0.42, 320)
        let showsVinyl = !showLyricsOnMobile && !showQueueOnMobile

        return VStack(spacing: 0) {
            #if os(iOS)
            Color.clear.frame(
                height: NowPlayingPresentationMetrics.immersiveHeaderTopInset
            )

            CompactTrackHeader(
                showsExpandedArtwork: showsVinyl,
                onOpenDestination: onOpenDestination,
                onOpenSoundEffects: { showSoundEffects = true },
                onToggleVolume: { showsVolumeControl.toggle() }
            )
                .padding(.bottom, 10)
            #else
            Spacer().frame(height: 30)
            trackMetaView
                .padding(.bottom, 10)
            #endif

            ZStack {
                if showsVinyl {
                    VStack(spacing: 12) {
                        Spacer(minLength: 4)

                        VinylTurntableView(
                            artworkImage: artworkImage,
                            isPlaying: player.isPlaying,
                            trackId: player.currentTrack?.id,
                            size: discDimension,
                            onTap: {
                                withAnimation(AppAnimation.standard) {
                                    showLyricsOnMobile = true
                                }
                            },
                            onNextTrack: {
                                player.next()
                            },
                            onPreviousTrack: {
                                player.previous()
                            }
                        )
                        .accessibilityIdentifier("vinylTurntable")

                        MiniLyricsView(onOpen: {
                            withAnimation(AppAnimation.standard) {
                                showLyricsOnMobile = true
                            }
                        })
                        .frame(maxWidth: .infinity, maxHeight: 70)

                        Spacer(minLength: 0)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if showQueueOnMobile {
                    #if os(iOS)
                    CompactQueueContent()
                        .transition(.opacity)
                    #else
                    lyricsColumn
                        .transition(.opacity)
                    #endif
                } else {
                    #if os(iOS)
                    NowPlayingLyricsPager(isShown: true, horizontalInset: 32) {
                        IOSImmersiveLyricsColumn()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(AppAnimation.standard) {
                                    showLyricsOnMobile = false
                                }
                            }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
                    #else
                    lyricsColumn
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(AppAnimation.standard) {
                                showLyricsOnMobile = false
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 1.05)))
                    #endif
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            #if os(iOS)
            immersiveControls
            #else
            VStack(spacing: 12) {
                NowPlayingScrubber()
                    .padding(.horizontal, 24)
                controls()
            }
            .padding(.bottom, 24)
            #endif
        }
        .frame(width: max(size.width - 64, 0))
        .padding(.horizontal, 32)
    }

    private func classicCompactLayout(size: CGSize) -> some View {
        let artworkDim = min(size.width - 64, size.height * 0.38, 300)
        return VStack(spacing: 20) {
            Spacer().frame(height: 44)
            if showLyricsOnMobile {
                #if os(iOS)
                NowPlayingLyricsPager(isShown: true, horizontalInset: 16) {
                    lyricsColumn
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                #else
                lyricsColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                #endif
            } else {
                VStack(spacing: 20) {
                    artworkView(size: artworkDim)
                    trackMetaView
                    MiniLyricsView {
                        withAnimation(AppAnimation.standard) {
                            showLyricsOnMobile = true
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.opacity)
            }
            VStack(spacing: 12) {
                NowPlayingScrubber()
                    .padding(.horizontal, 24)
                controls()
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
    }

    #if os(iOS)
    private func immersiveCompactLayout(size: CGSize) -> some View {
        let artworkDimension = min(size.width - 112, size.height * 0.3, 250)
        let showsExpandedArtwork = !showLyricsOnMobile && !showQueueOnMobile

        return VStack(spacing: 0) {
            Color.clear.frame(
                height: NowPlayingPresentationMetrics.immersiveHeaderTopInset
            )

            CompactTrackHeader(
                showsExpandedArtwork: showsExpandedArtwork,
                onOpenDestination: onOpenDestination,
                onTapArtwork: collapseImmersiveArtwork,
                onOpenSoundEffects: { showSoundEffects = true },
                onToggleVolume: { showsVolumeControl.toggle() }
            )
            .padding(.bottom, 14)

            ZStack {
                immersiveArtworkContent(artworkDimension: artworkDimension)
                    .opacity(showsExpandedArtwork ? 1 : 0)
                    .allowsHitTesting(showsExpandedArtwork)
                    .accessibilityHidden(!showsExpandedArtwork)

                if showQueueOnMobile {
                    CompactQueueContent()
                        .transition(.opacity)
                } else {
                    NowPlayingLyricsPager(isShown: showLyricsOnMobile, horizontalInset: 32) {
                        IOSImmersiveLyricsColumn(isVisible: showLyricsOnMobile)
                    }
                        .opacity(showLyricsOnMobile ? 1 : 0)
                        .allowsHitTesting(showLyricsOnMobile)
                        .accessibilityHidden(!showLyricsOnMobile)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            immersiveControls
        }
        .frame(width: max(size.width - 64, 0))
        .padding(.horizontal, 32)
        .overlayPreferenceValue(ImmersiveArtworkFramePreferenceKey.self) { frames in
            GeometryReader { proxy in
                if let compactAnchor = frames[.compact],
                   let expandedAnchor = frames[.expanded] {
                    let compactFrame = proxy[compactAnchor]
                    let expandedFrame = proxy[expandedAnchor]
                    let targetFrame = showsExpandedArtwork ? expandedFrame : compactFrame
                    let targetCenterX = showsExpandedArtwork
                        ? size.width / 2
                        : compactFrame.midX

                    immersiveArtworkSurface(isExpanded: showsExpandedArtwork)
                        .frame(width: targetFrame.width, height: targetFrame.height)
                        .position(x: targetCenterX, y: targetFrame.midY)
                        .accessibilityIdentifier("immersiveArtwork")
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// The volume panel, above the button that opened it, over a clear
    /// catcher that covers the page: a tap anywhere else only closes it.
    @ViewBuilder
    private func volumeLayer(buttonAnchor: Anchor<CGRect>?) -> some View {
        if let buttonAnchor {
            GeometryReader { proxy in
                let button = proxy[buttonAnchor]
                ZStack(alignment: .topLeading) {
                    if showsVolumeControl {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture(perform: closeVolumeControl)
                            .accessibilityHidden(true)
                    }

                    Color.clear
                        .frame(width: button.width, height: button.height)
                        .overlay(alignment: .bottom) {
                            if showsVolumeControl {
                                CompactVolumePopover()
                                    .offset(y: -button.height)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                            }
                        }
                        .position(x: button.midX, y: button.midY)
                }
            }
        }
    }

    private func closeVolumeControl() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            showsVolumeControl = false
        }
    }

    private var immersiveControls: some View {
        VStack(spacing: 17) {
            NowPlayingScrubber()
            CompactTransportControls()
            CompactSecondaryControls(
                showsVolumeControl: $showsVolumeControl,
                showsLyrics: showLyricsOnMobile,
                showsQueue: showQueueOnMobile,
                onToggleLyrics: toggleImmersiveLyrics,
                onToggleQueue: toggleImmersiveQueue,
                onOpenComments: { bottomCommentsTrack = player.currentTrack },
                onOpenSoundEffects: { showSoundEffects = true }
            )
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .accessibilityIdentifier("immersiveControls")
        #if os(iOS)
        .sheet(item: $bottomCommentsTrack) { track in
            SongCommentsView(track: track)
        }
        #endif
    }

    private func immersiveArtworkContent(artworkDimension: CGFloat) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)
            Color.clear
                .frame(width: artworkDimension, height: artworkDimension)
                .anchorPreference(
                    key: ImmersiveArtworkFramePreferenceKey.self,
                    value: .bounds
                ) { [.expanded: $0] }
            MiniLyricsView(
                isVisible: !showLyricsOnMobile && !showQueueOnMobile,
                onOpen: showImmersiveLyrics
            )
            .frame(maxWidth: .infinity, maxHeight: 96)
            Spacer(minLength: 0)
        }
    }

    private func immersiveArtworkSurface(isExpanded: Bool) -> some View {
        Group {
            if let artworkImage {
                Image(platformImage: artworkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.white.opacity(isExpanded ? 0.06 : 0.1))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: isExpanded ? 48 : 18, weight: .light))
                            .foregroundStyle(.white.opacity(isExpanded ? 0.3 : 0.45))
                    }
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: isExpanded ? 18 : 12,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(isExpanded ? 0.45 : 0.22),
            radius: isExpanded ? 36 : 10,
            y: isExpanded ? 18 : 4
        )
    }

    private func toggleImmersiveLyrics() {
        withAnimation(ImmersiveArtworkTransition.animation) {
            if showQueueOnMobile {
                showQueueOnMobile = false
                showLyricsOnMobile = true
            } else {
                showLyricsOnMobile.toggle()
            }
        }
    }

    private func showImmersiveLyrics() {
        withAnimation(ImmersiveArtworkTransition.animation) {
            showQueueOnMobile = false
            showLyricsOnMobile = true
        }
    }

    /// Tapping the top-left cover while lyrics/queue are up returns to the
    /// expanded artwork — the Apple Music gesture requested in #50. Idempotent,
    /// so a tap while already expanded is a harmless no-op.
    private func collapseImmersiveArtwork() {
        guard showLyricsOnMobile || showQueueOnMobile else { return }
        withAnimation(ImmersiveArtworkTransition.animation) {
            showLyricsOnMobile = false
            showQueueOnMobile = false
        }
    }

    private func toggleImmersiveQueue() {
        withAnimation(ImmersiveArtworkTransition.animation) {
            showQueueOnMobile.toggle()
        }
    }

    private func minimalCompactLayout(size: CGSize) -> some View {
        let contentWidth = max(size.width - 64, 0)
        let artworkDimension = min(contentWidth, size.height * 0.52, 378)

        return VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Color.clear
                MinimalTrackInfoRow(
                    onOpenDestination: onOpenDestination,
                    onOpenSoundEffects: { showSoundEffects = true },
                    metadataOnly: true
                )
                    .padding(.top, NowPlayingPresentationMetrics.immersiveHeaderTopInset)
                    .opacity(showLyricsOnMobile ? 1 : 0)
                    .accessibilityHidden(!showLyricsOnMobile)
            }
            .frame(height: 90)

            ZStack(alignment: .top) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: toggleMinimalLyrics)

                artworkView(size: artworkDimension)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: toggleMinimalLyrics)
                    .accessibilityIdentifier("immersiveArtwork")
                    .accessibilityLabel("显示歌词")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { toggleMinimalLyrics() }
                    .opacity(showLyricsOnMobile ? 0 : 1)
                    .allowsHitTesting(!showLyricsOnMobile)

                NowPlayingLyricsPager(isShown: showLyricsOnMobile, horizontalInset: 32) {
                    IOSMinimalLyricsColumn {
                        showLyricsOnMobile = false
                    }
                }
                .opacity(showLyricsOnMobile ? 1 : 0)
                .allowsHitTesting(showLyricsOnMobile)
                .accessibilityHidden(!showLyricsOnMobile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .simultaneousGesture(
                minimalDismissGesture,
                including: showLyricsOnMobile ? .none : .all
            )
            .padding(.bottom, 20)

            minimalControls
        }
        .frame(width: contentWidth)
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .animation(.easeInOut(duration: 0.22), value: showLyricsOnMobile)
    }

    private var minimalControls: some View {
        VStack(spacing: 22) {
            ZStack {
                MinimalTrackInfoRow(
                    onOpenDestination: onOpenDestination,
                    onOpenSoundEffects: { showSoundEffects = true }
                )
                    .opacity(showLyricsOnMobile ? 0 : 1)
                    .allowsHitTesting(!showLyricsOnMobile)
                    .accessibilityHidden(showLyricsOnMobile)
                MinimalTrackInfoRow(
                    onOpenDestination: onOpenDestination,
                    onOpenSoundEffects: { showSoundEffects = true },
                    actionsOnly: true
                )
                    .opacity(showLyricsOnMobile ? 1 : 0)
                    .allowsHitTesting(showLyricsOnMobile)
                    .accessibilityHidden(!showLyricsOnMobile)
            }
            .frame(height: 44)
            NowPlayingScrubber()
                .padding(.horizontal, 2)
                .padding(.top, 16)
            MinimalTransportControls(
                backdrop: colors,
                showQueue: $showQueueOnMobile,
                onOpenDestination: onOpenDestination
            )
                .padding(.horizontal, 2)
        }
        .accessibilityIdentifier("immersiveControls")
    }

    private func toggleMinimalLyrics() {
        guard showLyricsOnMobile || player.lyrics?.isEmpty == false else { return }
        showLyricsOnMobile.toggle()
    }

    private var minimalDismissGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                guard let dismissNowPlayingDragAction else { return }
                let translation = value.translation
                let isDownward = translation.height > 0
                    && abs(translation.height) > abs(translation.width)
                dismissNowPlayingDragAction.onChanged(isDownward ? translation.height : 0)
            }
            .onEnded { value in
                guard let dismissNowPlayingDragAction else { return }
                let translation = value.translation
                let isDownward = translation.height > 0
                    && abs(translation.height) > abs(translation.width)
                dismissNowPlayingDragAction.onEnded(
                    isDownward ? translation.height : 0,
                    isDownward ? value.predictedEndTranslation.height : 0
                )
            }
    }
    #endif

    // MARK: - Views

    private func artworkView(
        size: CGFloat,
        shadowRadius: CGFloat = 36,
        cornerRadius: CGFloat = 18
    ) -> some View {
        Group {
            if settings.openAlbumOnArtworkClick,
               let album = player.currentTrack?.album, album.id > 0, !album.name.isEmpty {
                Button {
                    onOpenDestination(.album(album.id))
                } label: {
                    artworkSurface(size: size, shadowRadius: shadowRadius, cornerRadius: cornerRadius)
                }
                .buttonStyle(.plain)
                .noFocusRing()
                .accessibilityLabel("打开专辑：\(album.name)")
            } else {
                artworkSurface(size: size, shadowRadius: shadowRadius, cornerRadius: cornerRadius)
            }
        }
    }

    private func artworkSurface(
        size: CGFloat,
        shadowRadius: CGFloat = 36,
        cornerRadius: CGFloat = 18
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(0.06))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.white.opacity(0.3))
                )
            if let artworkImage {
                Image(platformImage: artworkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: shadowRadius, y: shadowRadius * 0.5)
        .animation(.easeIn(duration: 0.25), value: artworkImage != nil)
        .scaleEffect(player.isPlaying ? 1 : 0.95)
        .animation(AppAnimation.bouncy, value: player.isPlaying)
    }

    private var trackMetaView: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Text(player.currentTrack?.name ?? "")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if player.currentTrack?.fee == 1 {
                    VIPBadge()
                }
            }
            if let track = player.currentTrack {
                NowPlayingTrackDestinationLinks(
                    track: track,
                    font: .system(size: 13.5),
                    color: .white.opacity(0.65),
                    onOpenDestination: onOpenDestination
                )
            }
        }
        .frame(maxWidth: 400)
    }

    private func leftColumn(artworkSize: CGFloat) -> some View {
        VStack(spacing: 26) {
            Spacer()

            if settings.nowPlayingMode == .vinyl {
                VinylTurntableView(
                    artworkImage: artworkImage,
                    isPlaying: player.isPlaying,
                    trackId: player.currentTrack?.id,
                    size: artworkSize,
                    onTap: {
                        player.togglePlayPause()
                    },
                    onNextTrack: {
                        player.next()
                    },
                    onPreviousTrack: {
                        player.previous()
                    }
                )
            } else {
                artworkView(size: artworkSize)
            }
            trackMetaView

            VStack(spacing: 14) {
                NowPlayingScrubber()
                    .frame(maxWidth: 380)
                controls(showsSoundEffects: true)
            }

            Spacer()
        }
        .padding(.trailing, hasLyricsColumn ? 30 : 0)
    }

    private func controls(showsSoundEffects: Bool = false) -> some View {
        // Equal-width slots so the row always fits the screen: fixed-size
        // buttons in a plain HStack summed wider than a phone (≈430pt with the
        // like button), overflowing the layout and shoving the overlays and
        // metadata off the right edge. `maxWidth: .infinity` per control makes
        // the row scale to any width instead.
        HStack(spacing: 0) {
            // The like slot stays even when the track is briefly unavailable:
            // adding or removing it re-divides the equal-width row, which made
            // every other control jump sideways during a track change.
            Group {
                if let track = player.currentTrack {
                    let liked = account.isLiked(track.id)
                    circleButton(
                        icon: liked ? "heart.fill" : "heart",
                        size: 15, tint: liked ? Theme.accent : nil
                    ) {
                        Task { await account.toggleLike(trackID: track.id) }
                    }
                    .accessibilityLabel(liked ? "取消喜欢" : "喜欢")
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
            }
            .frame(maxWidth: .infinity)

            if player.isFMMode {
                circleButton(icon: "trash", size: 14) {
                    player.fmTrash()
                }
                .accessibilityLabel("不喜欢")
                .frame(maxWidth: .infinity)
            } else {
                // All three queue orders on the one button; the cycle skips
                // AutoMix wherever it could do nothing (AutoMix off, order
                // off), so this row keeps its present width and its two-state
                // behaviour there — as it does on iOS, which has no AutoMix at
                // all. Only the three values below differ per platform.
                circleButton(
                    icon: queueOrderIcon, size: 14,
                    tint: queueOrderIsActive ? Theme.accent : nil,
                    action: cycleQueueOrder
                )
                #if os(macOS)
                .accessibilityLabel(player.queueOrder.controlHelp)
                #else
                .accessibilityLabel("随机播放")
                .accessibilityAddTraits(player.shuffleEnabled ? .isSelected : [])
                #endif
                .frame(maxWidth: .infinity)
                circleButton(icon: "backward.fill", size: 16) {
                    player.previous()
                }
                .accessibilityLabel("上一首")
                .frame(maxWidth: .infinity)
            }

            playPauseButton()
                .frame(maxWidth: .infinity)

            circleButton(icon: "forward.fill", size: 16) {
                player.next()
            }
            .accessibilityLabel("下一首")
            .frame(maxWidth: .infinity)

            RoutePickerButton(diameter: 40, glyphSize: 15)
                .frame(maxWidth: .infinity)

            #if os(iOS)
            if showsSoundEffects {
                SoundEffectsButton(
                    action: { showSoundEffects = true },
                    diameter: 40,
                    glyphSize: 15
                )
                .frame(maxWidth: .infinity)
            }
            #endif

            if player.isFMMode {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 40, height: 40)
                    .frame(maxWidth: .infinity)
            } else {
                circleButton(
                    icon: player.repeatMode == .one ? "repeat.1" : "repeat",
                    size: 14,
                    tint: player.repeatMode != .off ? Theme.accent : nil
                ) {
                    player.cycleRepeatMode()
                }
                .accessibilityLabel("循环播放")
                .accessibilityValue(repeatModeAccessibilityValue)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("nowPlayingTransport")
    }

    private func playPauseButton(diameter: CGFloat = 58, glyphSize: CGFloat = 21) -> some View {
        Button {
            player.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: diameter, height: diameter)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: glyphSize, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
                    .contentTransition(.opacity)
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
    }

    // MARK: - Queue-order control

    /// The queue-order button's three platform-dependent values. macOS cycles
    /// `listed → shuffled → autoMix`; iOS has no AutoMix and toggles shuffle.

    private var queueOrderIcon: String {
        #if os(macOS)
        player.queueOrder.symbolName
        #else
        "shuffle"
        #endif
    }

    /// Spoken state of the repeat button, which cycles three modes.
    private var repeatModeAccessibilityValue: Text {
        switch player.repeatMode {
        case .off: return Text("不循环")
        case .all: return Text("列表循环")
        case .one: return Text("单曲循环")
        }
    }

    private var queueOrderIsActive: Bool {
        #if os(macOS)
        player.queueOrder != .listed
        #else
        player.shuffleEnabled
        #endif
    }

    private func cycleQueueOrder() {
        #if os(macOS)
        player.cycleQueueOrder()
        #else
        player.toggleShuffle()
        #endif
    }

    private func circleButton(icon: String, size: CGFloat,
                              tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(tint ?? .white.opacity(0.8))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Lyrics column

    @ViewBuilder
    private var lyricsColumn: some View {
        lyricsScroll(topInset: 200, bottomInset: 240, horizontalPadding: 24)
    }

    // MARK: - Regular right column

    /// The song's comments sit beside its lyrics, one switch away, so a song
    /// without lyrics still has a right column when it has comments.
    private var hasRegularRightColumn: Bool {
        hasLyricsColumn || commentsTrack != nil
    }

    private var commentsTrack: Track? {
        guard let track = player.currentTrack,
              SongCommentsMenuButton.isAvailable(for: track) else { return nil }
        return track
    }

    private var regularRightColumn: some View {
        ZStack(alignment: .top) {
            Group {
                if regularColumnPage == .comments, let track = commentsTrack {
                    RegularCommentsPanel(track: track)
                        .id(track.id)
                        .padding(.top, 52)
                        .transition(.opacity)
                } else if hasLyricsColumn {
                    lyricsColumn
                        .transition(.opacity)
                } else {
                    Text("暂无歌词")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if commentsTrack != nil {
                RegularColumnSwitch(selection: $regularColumnPage)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: regularColumnPage)
    }

    /// The scrolling lyric list shared by the regular page and the
    /// landscape immersive page. Insets are the space parked above and below
    /// the lines so the active one can sit mid-viewport; the short landscape
    /// page needs them much smaller than a full-height window does.
    @ViewBuilder
    private func lyricsScroll(
        topInset: CGFloat,
        bottomInset: CGFloat,
        horizontalPadding: CGFloat
    ) -> some View {
        // 实现见 PlayerLyricsList：播放页与漫游横屏共用同一份歌词视图。
        PlayerLyricsList(
            topInset: topInset,
            bottomInset: bottomInset,
            horizontalPadding: horizontalPadding
        )
    }

}


/// The main lyric line. Renders karaoke-style per-character highlighting from
/// verbatim (`yrc`) timings, driven live by the player, when the line is active
/// and verbatim data exists; otherwise a plain line.
///
/// Whether the line carries furigana is `LyricText`'s decision; the wipe is
/// handed down as per-character opacity so it reads the same either way.
struct LyricMainText: View {
    let line: LyricLine
    let isActive: Bool
    let size: CGFloat
    let weight: Font.Weight
    let verbatim: Bool
    var inactiveOpacity: Double = 0.45
    var alignment: NSTextAlignment = .left
    var singleLine = false
    /// 擦亮（逐字跟随）那段文字的颜色；播放器白字，漫游浅底用黑字。
    var highlightColor: Color = .white

    @EnvironmentObject private var player: PlayerService
    @ObservedObject private var windowVisibility = MainWindowVisibility.shared

    var body: some View {
        if isActive, verbatim, let words = line.words, !words.isEmpty {
            #if os(macOS)
            // The wipe runs on a display link inside the host: a per-frame
            // SwiftUI value here re-measured the page's whole layout while a
            // verbatim line was up (see KaraokeLyricLine).
            KaraokeLyricLine(
                line: line,
                words: words,
                size: size,
                weight: weight,
                alignment: alignment,
                color: highlightColor,
                playing: player.isPlaying && windowVisibility.isVisible
            )
            #else
            TimelineView(.animation(
                minimumInterval: 1 / 30,
                paused: !player.isPlaying || !windowVisibility.isVisible
            )) { _ in
                let alphas = Self.alphas(for: line, words: words, at: player.livePlaybackTime)
                if singleLine {
                    Text(Self.compactWipe(line.text, alphas: alphas, color: highlightColor))
                        .font(.system(size: size, weight: weight))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                } else {
                    LyricText(
                        line: line, size: size, weight: weight, color: highlightColor,
                        alignment: alignment, alphas: alphas
                    )
                }
            }
            #endif
        } else {
            LyricText(
                line: line, size: size, weight: weight,
                color: highlightColor.opacity(isActive ? 1 : inactiveOpacity),
                alignment: alignment
            )
        }
    }

    #if os(iOS)
    // Text keeps the preview's one-line ellipsis even when the full lyric wraps.
    private static func compactWipe(_ text: String, alphas: [Double], color: Color = .white) -> AttributedString {
        var result = AttributedString()
        for (index, character) in text.enumerated() {
            var fragment = AttributedString(String(character))
            fragment.foregroundColor = color.opacity(index < alphas.count ? alphas[index] : 1)
            result.append(fragment)
        }
        return result
    }
    #endif

    /// One opacity per character of `line.text`: sung characters are bright,
    /// the current one fades in, unsung stay dim. A word's time is shared by
    /// its letters; punctuation and spaces take none and light up with the
    /// character before them (or the first one, when they open the line).
    static func alphas(for line: LyricLine, words: [LyricWord], at time: TimeInterval) -> [Double] {
        let unsung = 0.28
        var out: [Double] = []
        for word in words {
            let chars = Array(word.text)
            guard !chars.isEmpty else { continue }
            let letters = chars.indices.filter { chars[$0].isLetter || chars[$0].isNumber }
            let slots = letters.isEmpty ? Array(chars.indices) : letters
            // A token the service timed at nothing still ramps, over 50 ms.
            let per = max(word.duration, 0.05) / Double(slots.count)
            var lit: [Int: Double] = [:]
            for (slot, index) in slots.enumerated() {
                let frac = min(max((time - (word.start + per * Double(slot))) / per, 0), 1)
                lit[index] = unsung + (1 - unsung) * frac
            }
            let opening = lit[slots[0]] ?? unsung
            for index in chars.indices {
                out.append(lit[index] ?? out.last ?? opening)
            }
        }
        // The words' text joined is the line's text; should they ever differ,
        // keep one opacity per character of the line.
        let joined = words.map(\.text).joined()
        guard joined.count != line.text.count else { return out }
        let leading = joined.count - joined.drop(while: \.isWhitespace).count
        return Array(out.dropFirst(leading).prefix(line.text.count))
    }
}

#if os(iOS)
private struct IOSImmersiveLyricsColumn: View {
    var isVisible = true

    @EnvironmentObject private var player: PlayerService
    @ObservedObject private var lyricsCursor = PlayerService.shared.lyricsCursor
    @EnvironmentObject private var settings: SettingsManager

    @State private var activeIndex: Int?
    @State private var isUserScrolling = false

    var body: some View {
        Group {
            if let lyrics = player.lyrics, !lyrics.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            Color.clear.frame(height: 72)
                            ForEach(lyrics.lines) { line in
                                lyricLine(
                                    line,
                                    isActive: line.id == activeIndex
                                )
                                .id(line.id)
                            }
                            Color.clear.frame(height: 96)
                        }
                        .padding(.horizontal, 4)
                    }
                    .mask(edgeMask)
                    .accessibilityIdentifier("syncedLyricsScroll")
                    .onChange(of: lyricsCursor.activeIndex) { index in
                        guard index != activeIndex else { return }
                        activeIndex = index
                        guard !isUserScrolling, let index else { return }
                        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.38)) {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                    .onAppear {
                        adoptCursor(proxy: proxy)
                    }
                    .onChange(of: player.currentTrack?.id) { _ in
                        activeIndex = nil
                    }
                    .lyricsScrollTracking(isUserScrolling: $isUserScrolling) {
                        guard let activeIndex else { return }
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            proxy.scrollTo(activeIndex, anchor: .center)
                        }
                    }
                }
            } else if player.lyrics?.isInstrumental == true {
                VStack(spacing: 10) {
                    Image(systemName: "music.quarternote.3")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("纯音乐，请欣赏")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                proxy.scrollTo(index, anchor: .center)
            }
        }
    }

    private var edgeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.85),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func lyricLine(_ line: LyricLine, isActive: Bool) -> some View {
        Button {
            player.seek(to: line.time)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                if settings.lyricsAnnotation == .romaji, let romaji = line.romaji {
                    Text(romaji)
                        .font(.system(size: isActive ? 15 : 13, weight: .medium))
                        .foregroundStyle(.white.opacity(isActive ? 0.75 : 0.4))
                }

                LyricMainText(
                    line: line,
                    isActive: isActive,
                    size: isActive ? 26 : 21,
                    weight: isActive ? .bold : .semibold,
                    verbatim: isVisible && settings.verbatimLyrics
                )

                if settings.showLyricsTranslation, let translation = line.translation {
                    Text(translation)
                        .font(.system(size: isActive ? 16 : 14, weight: .medium))
                        .foregroundStyle(.white.opacity(isActive ? 0.75 : 0.4))
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(isActive || isUserScrolling ? 1 : 0.78)
            .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isActive)
        .animation(.easeOut(duration: 0.25), value: isUserScrolling)
    }
}

// MARK: - Compact now-playing sections

private enum ImmersiveArtworkTransition {
    /// A time-based ease-out curve stays fluid at the display's native refresh rate.
    static let animation = Animation.timingCurve(
        0.16,
        1,
        0.3,
        1,
        duration: 0.42
    )
    static let compactArtworkDimension: CGFloat = 62
    static let compactHeaderSpacing: CGFloat = 13
    static let expandedMetadataOffset = -(
        compactArtworkDimension + compactHeaderSpacing
    )
}

private enum ImmersiveArtworkFrame: Hashable {
    case compact
    case expanded
}

private struct ImmersiveArtworkFramePreferenceKey: PreferenceKey {
    static var defaultValue: [ImmersiveArtworkFrame: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [ImmersiveArtworkFrame: Anchor<CGRect>],
        nextValue: () -> [ImmersiveArtworkFrame: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct CompactTrackHeader: View {
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var account: AccountStore
    @State private var showAddToPlaylist = false
    @State private var commentsTrack: Track?

    let showsExpandedArtwork: Bool
    let onOpenDestination: (Destination) -> Void
    /// Tap handler for the compact cover (used to collapse lyrics back to
    /// artwork). The real image floats above this placeholder with hit-testing
    /// disabled, so taps land here.
    var onTapArtwork: (() -> Void)? = nil
    /// 音效与音量的入口从底部按钮搬到了右上角菜单，由页面注入。
    var onOpenSoundEffects: (() -> Void)? = nil
    var onToggleVolume: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: ImmersiveArtworkTransition.compactHeaderSpacing) {
            Color.clear
                .frame(
                    width: ImmersiveArtworkTransition.compactArtworkDimension,
                    height: ImmersiveArtworkTransition.compactArtworkDimension
                )
                .anchorPreference(
                    key: ImmersiveArtworkFramePreferenceKey.self,
                    value: .bounds
                ) { [.compact: $0] }
                .contentShape(Rectangle())
                .onTapGesture { onTapArtwork?() }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(player.currentTrack?.name ?? "")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if player.currentTrack?.fee == 1 {
                        VIPBadge()
                    }
                }
                if let track = player.currentTrack {
                    NowPlayingTrackDestinationLinks(
                        track: track,
                        font: .subheadline,
                        color: .white.opacity(0.62),
                        onOpenDestination: onOpenDestination
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(
                x: showsExpandedArtwork
                    ? ImmersiveArtworkTransition.expandedMetadataOffset
                    : 0
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("immersiveTrackMetadata")

            if let track = player.currentTrack {
                let liked = account.isLiked(track.id)
                HStack(spacing: 0) {
                    Button {
                        Task { await account.toggleLike(trackID: track.id) }
                    } label: {
                        Image(systemName: liked ? "heart.fill" : "heart")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(liked ? Theme.accent : .white.opacity(0.88))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(liked ? "取消收藏" : "收藏")
                    .accessibilityIdentifier("immersiveFavoriteButton")

                    Menu {
                        TrackDownloadActions(track: track, showsIcons: true)
                        TrackBlacklistMenu(track: track, showsIcons: true)
                        SongCommentsMenuButton(track: track, showsIcons: true) {
                            commentsTrack = track
                        }
                        Divider()
                        Button {
                            player.addToPlayNext(track)
                        } label: {
                            Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
                        }

                        Button {
                            showAddToPlaylist = true
                        } label: {
                            Label("加入歌单…", systemImage: "music.note.list")
                        }

                        Divider()

                        #if os(iOS)
                        if let onOpenSoundEffects {
                            Button {
                                onOpenSoundEffects()
                            } label: {
                                Label("音效", systemImage: "waveform")
                            }
                        }

                        Button {
                            player.toggleShuffle()
                        } label: {
                            Label(
                                player.shuffleEnabled ? "关闭随机播放" : "随机播放",
                                systemImage: "shuffle"
                            )
                        }

                        Button {
                            player.repeatMode = player.repeatMode == .all ? .off : .all
                        } label: {
                            Label("列表循环", systemImage: "repeat")
                        }

                        Button {
                            player.repeatMode = player.repeatMode == .one ? .off : .one
                        } label: {
                            Label("单曲循环", systemImage: "repeat.1")
                        }

                        if let onToggleVolume {
                            Button {
                                onToggleVolume()
                            } label: {
                                Label("音量", systemImage: "speaker.wave.2")
                            }
                        }

                        SleepTimerMenu(player: player)

                        Divider()
                        #endif

                        Button {
                            Platform.copyToPasteboard(
                                string: Upstream.songPageURL(id: track.id)?.absoluteString ?? ""
                            )
                            ToastCenter.shared.show(String(localized: "链接已复制"))
                        } label: {
                            Label("复制链接", systemImage: "link")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    #if os(iOS)
                    // Let the native menu animate from a stable source frame.
                    .buttonStyle(.plain)
                    #else
                    .buttonStyle(.pressable)
                    #endif
                    .accessibilityLabel("更多操作")
                    .accessibilityIdentifier("immersiveMoreMenu")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .addToPlaylistPicker(isPresented: $showAddToPlaylist) {
            player.currentTrack.map { AddToPlaylistSheet(track: $0) }
        }
        .sheet(item: $commentsTrack) { track in
            SongCommentsView(track: track)
        }
    }
}

private struct CompactTransportControls: View {
    @EnvironmentObject private var player: PlayerService

    var body: some View {
        HStack(spacing: 0) {
            Button(action: player.isFMMode ? player.fmTrash : player.previous) {
                Image(systemName: player.isFMMode ? "trash" : "backward.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .accessibilityLabel(player.isFMMode ? "不喜欢" : "上一首")

            Button(action: player.togglePlayPause) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 36, weight: .bold))
                    .contentTransition(.opacity)
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .accessibilityLabel(player.isPlaying ? "暂停" : "播放")

            Button(action: player.next) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .accessibilityLabel("下一首")
        }
        .foregroundStyle(.white)
        .buttonStyle(.pressable)
    }
}

#if os(iOS)
private struct CompactVolumePopover: View {
    @EnvironmentObject private var player: PlayerService
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 16, weight: .medium))

            GeometryReader { geo in
                let height = geo.size.height
                let fraction = min(max(CGFloat(player.volume), 0), 1)
                ZStack(alignment: .bottom) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule().fill(.white.opacity(0.82))
                        .frame(height: height * fraction)
                }
                .frame(width: isDragging ? 12 : 8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            updateVolume(at: value.location.y, height: height)
                        }
                        .onEnded { value in
                            updateVolume(at: value.location.y, height: height)
                            isDragging = false
                        }
                )
                .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isDragging)
            }
            .frame(width: 32, height: 132)
            .accessibilityElement()
            .accessibilityLabel("音量")
            .accessibilityValue("\(Int((player.volume * 100).rounded()))%")
            .accessibilityAdjustableAction(adjustVolume)

            Image(systemName: player.volume == 0 ? "speaker.slash.fill" : "speaker.fill")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(.white.opacity(0.18))
                .frame(width: 16, height: 8)
                .offset(y: 8)
        }
    }

    private func updateVolume(at location: CGFloat, height: CGFloat) {
        guard height > 0 else { return }
        player.volume = Float(min(max(1 - location / height, 0), 1))
    }

    private func adjustVolume(_ direction: AccessibilityAdjustmentDirection) {
        let step: Float = 0.05
        switch direction {
        case .increment:
            player.volume = min(player.volume + step, 1)
        case .decrement:
            player.volume = max(player.volume - step, 0)
        @unknown default:
            break
        }
    }
}

private struct CompactVolumeButtonAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

private struct CompactSecondaryControls: View {
    @EnvironmentObject private var player: PlayerService
    @Binding var showsVolumeControl: Bool
    let showsLyrics: Bool
    let showsQueue: Bool
    let onToggleLyrics: () -> Void
    let onToggleQueue: () -> Void
    let onOpenComments: () -> Void
    let onOpenSoundEffects: () -> Void

    var body: some View {
        // 底部只留三个：歌词 / 评论区 / 播放队列。
        // 其余入口（音效、播放模式、音量、睡眠定时、AirPlay）在右上角「⋯」菜单里。
        HStack(spacing: 0) {
            secondaryButton(
                icon: showsLyrics && !showsQueue ? "quote.bubble.fill" : "quote.bubble",
                label: showsLyrics ? "显示封面" : "显示歌词",
                isActive: showsLyrics && !showsQueue
            ) { onToggleLyrics() }

            secondaryButton(
                icon: "text.bubble",
                label: "评论区"
            ) { onOpenComments() }

            secondaryButton(
                icon: "list.bullet",
                label: showsQueue ? "关闭播放队列" : "显示播放队列",
                isActive: showsQueue
            ) { onToggleQueue() }
        }
    }

    private var volumeIcon: String {
        let volume = player.volume
        if volume == 0 { return "speaker.slash" }
        if volume < 0.5 { return "speaker.wave.1" }
        return "speaker.wave.2"
    }

    private func secondaryButton(
        icon: String,
        label: LocalizedStringKey,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? Theme.accent : .white.opacity(0.72))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.08), in: Circle())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}
#endif

private struct CompactQueueContent: View {
    @EnvironmentObject private var player: PlayerService

    var body: some View {
        let entries = player.playbackList
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                modeButton(
                    icon: "arrow.right",
                    label: "顺序播放",
                    isActive: !player.shuffleEnabled && player.repeatMode == .off,
                    action: enableSequentialPlayback
                )
                modeButton(
                    icon: "shuffle",
                    label: player.shuffleEnabled ? "关闭随机播放" : "随机播放",
                    isActive: player.shuffleEnabled,
                    action: player.toggleShuffle
                )
                modeButton(
                    icon: "repeat",
                    label: "列表循环",
                    isActive: player.repeatMode == .all
                ) {
                    player.repeatMode = player.repeatMode == .all ? .off : .all
                }
                modeButton(
                    icon: "repeat.1",
                    label: "单曲循环",
                    isActive: player.repeatMode == .one
                ) {
                    player.repeatMode = player.repeatMode == .one ? .off : .one
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text("播放列表")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(entries.count) 首")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.46))
            }

            if entries.isEmpty {
                VStack(spacing: 8) {
                    PlaybackHandoffList()
                    Image(systemName: "list.bullet")
                        .font(.system(size: 28, weight: .light))
                    Text("播放队列是空的")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        PlaybackHandoffList()
                            .padding(.bottom, 4)
                        ForEach(entries) { entry in
                            CompactQueueRow(entry: entry)
                        }
                    }
                }
                .mask(
                    LinearGradient(
                        colors: [.black, .black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .padding(.top, 6)
    }

    private func modeButton(
        icon: String,
        label: LocalizedStringKey,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isActive ? Color.black.opacity(0.76) : .white.opacity(0.76))
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(
                    isActive ? AnyShapeStyle(.white.opacity(0.66)) : AnyShapeStyle(.white.opacity(0.1)),
                    in: Capsule()
                )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func enableSequentialPlayback() {
        if player.shuffleEnabled {
            player.toggleShuffle()
        }
        player.repeatMode = .off
    }
}

private struct CompactQueueRow: View {
    let entry: PlaybackQueuePlan.ListEntry
    private var track: Track { entry.track }

    @EnvironmentObject private var player: PlayerService

    var body: some View {
        Button {
            player.jumpToPlaylistEntry(entry)
        } label: {
            HStack(spacing: 11) {
                CachedAsyncImage(url: track.album.picUrl?.resizedImageURL(120), animated: false)
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(entry.isCurrent ? Theme.accent : .white.opacity(0.9))
                        .lineLimit(1)
                    Text(track.artistNames)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if entry.isCurrent {
                    PlayingIndicator(animating: player.isPlaying)
                } else {
                    Text(Formatters.duration(track.duration))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.36))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(track.name)，\(track.artistNames)")
        .accessibilityAddTraits(entry.isCurrent ? .isSelected : [])
    }
}



private struct IOSMinimalLyricsColumn: View {
    @EnvironmentObject private var player: PlayerService
    @ObservedObject private var clock = PlayerService.shared.clock
    @EnvironmentObject private var settings: SettingsManager

    let onClose: () -> Void

    @State private var activeIndex: Int?
    @State private var selectedIndex: Int?
    @State private var nearestIndex: Int?
    @State private var lineCenters: [Int: CGFloat] = [:]
    @State private var isDragging = false
    @State private var suppressesAutoScroll = false
    @State private var scrollSettleTask: Task<Void, Never>?
    @State private var selectionTimeoutTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let lyrics = player.lyrics, !lyrics.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                Color.clear.frame(height: geometry.size.height / 2)
                                ForEach(lyrics.lines) { line in
                                    lyricLine(
                                        line,
                                        isActive: line.id == activeIndex,
                                        isSelected: line.id == selectedIndex,
                                        availableWidth: geometry.size.width
                                    ) {
                                        guard let selectedIndex else {
                                            closeLyrics()
                                            return
                                        }
                                        guard selectedIndex == line.id else {
                                            returnToActiveLine(proxy: proxy)
                                            return
                                        }
                                        selectionTimeoutTask?.cancel()
                                        selectionTimeoutTask = nil
                                        suppressesAutoScroll = true
                                        player.seek(to: line.time) {
                                            suppressesAutoScroll = false
                                        }
                                        activeIndex = line.id
                                        self.selectedIndex = nil
                                        nearestIndex = nil
                                    }
                                    .id(line.id)
                                    .background {
                                        GeometryReader { lineGeometry in
                                            Color.clear.preference(
                                                key: MinimalLyricCentersKey.self,
                                                value: [
                                                    line.id: lineGeometry.frame(
                                                        in: .named("immersiveLyrics")
                                                    ).midY
                                                ]
                                            )
                                        }
                                    }
                                }
                                Color.clear.frame(height: geometry.size.height / 2)
                            }
                            .padding(.horizontal, 2)
                        }
                        .coordinateSpace(name: "immersiveLyrics")
                        .mask(edgeMask)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: closeLyrics)
                        .accessibilityIdentifier("syncedLyricsScroll")
                        .onPreferenceChange(MinimalLyricCentersKey.self) { centers in
                            lineCenters = centers
                            guard isDragging || scrollSettleTask != nil else { return }
                            nearestIndex = nearestLine(
                                to: geometry.size.height / 2,
                                in: centers
                            )
                            guard !isDragging else { return }
                            scheduleScrollSelection(
                                guideY: geometry.size.height / 2,
                                proxy: proxy
                            )
                        }
                        .onAppear {
                            activeIndex = lyrics.activeIndex(at: clock.progress + 0.2)
                            if let activeIndex {
                                Task { @MainActor in
                                    await Task.yield()
                                    proxy.scrollTo(activeIndex, anchor: .center)
                                }
                            }
                        }
                        .onChange(of: clock.progress) { _ in
                            let index = lyrics.activeIndex(at: clock.progress + 0.2)
                            guard index != activeIndex else { return }
                            activeIndex = index
                            guard !suppressesAutoScroll,
                                  !isDragging, scrollSettleTask == nil,
                                  selectedIndex == nil, let index else { return }
                            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.38)) {
                                proxy.scrollTo(index, anchor: .center)
                            }
                        }
                        .onChange(of: player.currentTrack?.id) { _ in
                            activeIndex = nil
                            selectedIndex = nil
                            nearestIndex = nil
                            suppressesAutoScroll = false
                            scrollSettleTask?.cancel()
                            scrollSettleTask = nil
                            selectionTimeoutTask?.cancel()
                            selectionTimeoutTask = nil
                        }
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { _ in
                                    if !isDragging {
                                        scrollSettleTask?.cancel()
                                        scrollSettleTask = nil
                                        selectionTimeoutTask?.cancel()
                                        selectionTimeoutTask = nil
                                        selectedIndex = nil
                                        isDragging = true
                                    }
                                    nearestIndex = nearestLine(
                                        to: geometry.size.height / 2,
                                        in: lineCenters
                                    )
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    scheduleScrollSelection(
                                        guideY: geometry.size.height / 2,
                                        proxy: proxy
                                    )
                                }
                        )
                        .overlay {
                            selectionGuide(lyrics: lyrics)
                        }
                    }
                } else if player.lyrics?.isInstrumental == true {
                    VStack(spacing: 10) {
                        Image(systemName: "music.quarternote.3")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("纯音乐，请欣赏")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: closeLyrics)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onDisappear {
            scrollSettleTask?.cancel()
            selectionTimeoutTask?.cancel()
        }
    }

    @ViewBuilder
    private func selectionGuide(lyrics: ParsedLyrics) -> some View {
        let isScrolling = isDragging || scrollSettleTask != nil
        if let index = isScrolling ? nearestIndex : selectedIndex,
           lyrics.lines.indices.contains(index) {
            HStack(spacing: 8) {
                if isScrolling {
                    Canvas { context, size in
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: size.height / 2))
                        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                        context.stroke(
                            path,
                            with: .color(.white.opacity(0.45)),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )
                    }
                    .frame(height: 1)
                } else {
                    Spacer()
                }

                Text(Formatters.duration(lyrics.lines[index].time))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
                    .offset(x: 25)
            }
            .padding(.horizontal, 2)
            .allowsHitTesting(false)
        }
    }

    private func nearestLine(to guideY: CGFloat, in centers: [Int: CGFloat]) -> Int? {
        centers.min { abs($0.value - guideY) < abs($1.value - guideY) }?.key
    }

    private func scheduleScrollSelection(guideY: CGFloat, proxy: ScrollViewProxy) {
        scrollSettleTask?.cancel()
        // ponytail: iOS 16 has no scroll phase API; replace with onScrollPhaseChange
        // when the deployment target reaches iOS 18.
        scrollSettleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let selection = nearestLine(to: guideY, in: lineCenters) ?? nearestIndex
            selectedIndex = selection
            nearestIndex = selection
            scrollSettleTask = nil
            guard let selection else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                proxy.scrollTo(selection, anchor: .center)
            }
            scheduleSelectionTimeout(proxy: proxy)
        }
    }

    private func scheduleSelectionTimeout(proxy: ScrollViewProxy) {
        selectionTimeoutTask?.cancel()
        selectionTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, selectedIndex != nil else { return }
            returnToActiveLine(proxy: proxy)
        }
    }

    private func returnToActiveLine(proxy: ScrollViewProxy) {
        selectionTimeoutTask?.cancel()
        selectionTimeoutTask = nil
        selectedIndex = nil
        nearestIndex = nil
        guard let activeIndex else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            proxy.scrollTo(activeIndex, anchor: .center)
        }
    }

    private func closeLyrics() {
        scrollSettleTask?.cancel()
        scrollSettleTask = nil
        selectionTimeoutTask?.cancel()
        selectionTimeoutTask = nil
        selectedIndex = nil
        nearestIndex = nil
        isDragging = false
        onClose()
    }

    private var edgeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.85),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func lyricLine(
        _ line: LyricLine,
        isActive: Bool,
        isSelected: Bool,
        availableWidth: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                if settings.lyricsAnnotation == .romaji, let romaji = line.romaji {
                    Text(romaji)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(isActive ? 0.7 : 0.35))
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(isActive ? 1.02 : 12.0 / 13.0, anchor: .leading)
                }

                LyricMainText(
                    line: line, isActive: isActive,
                    size: 17, weight: .bold,
                    verbatim: settings.verbatimLyrics
                )
                    .fixedSize(horizontal: false, vertical: true)
                    .scaleEffect(isActive ? 1.02 : 16.0 / 17.0, anchor: .leading)

                if settings.showLyricsTranslation, let translation = line.translation {
                    Text(translation)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(isActive ? 0.7 : 0.35))
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(isActive ? 1.02 : 12.0 / 13.0, anchor: .leading)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.14 : 0))
            )
            .contentShape(Rectangle())
            .padding(.trailing, availableWidth * (1 - 1 / 1.02))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: isActive)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }
}

private struct MinimalLyricCentersKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

// MARK: - Minimal track info row

private struct MinimalTrackInfoRow: View {
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var account: AccountStore
    @State private var showAddToPlaylist = false
    @State private var commentsTrack: Track?
    @State private var airPlayRequest = 0
    let onOpenDestination: (Destination) -> Void
    let onOpenSoundEffects: () -> Void
    var metadataOnly = false
    var actionsOnly = false

    var body: some View {
        Group {
            if metadataOnly {
                metadata(alignment: .center, textAlignment: .center)
                    .padding(.horizontal, 48)
            } else if actionsOnly {
                if let track = player.currentTrack {
                    HStack {
                        favoriteButton(for: track)
                        Spacer()
                        SoundEffectsButton(
                            action: onOpenSoundEffects,
                            diameter: 44,
                            glyphSize: 18,
                            showsBackground: false
                        )
                        moreMenu(for: track)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    metadata(alignment: .leading, textAlignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let track = player.currentTrack {
                        favoriteButton(for: track)
                        SoundEffectsButton(
                            action: onOpenSoundEffects,
                            diameter: 44,
                            glyphSize: 18,
                            showsBackground: false
                        )
                        moreMenu(for: track)
                    }
                }
            }
        }
        .addToPlaylistPicker(isPresented: $showAddToPlaylist) {
            player.currentTrack.map { AddToPlaylistSheet(track: $0) }
        }
        .sheet(item: $commentsTrack) { track in
            SongCommentsView(track: track)
        }
    }

    private func metadata(
        alignment: HorizontalAlignment,
        textAlignment: TextAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 6) {
                Text(player.currentTrack?.name ?? "")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if player.currentTrack?.fee == 1 {
                    VIPBadge()
                }
            }
            if let track = player.currentTrack {
                NowPlayingTrackDestinationLinks(
                    track: track,
                    font: .footnote,
                    color: .white.opacity(0.62),
                    onOpenDestination: onOpenDestination
                )
            }
        }
        .multilineTextAlignment(textAlignment)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("immersiveTrackMetadata")
    }

    private func favoriteButton(for track: Track) -> some View {
        let liked = account.isLiked(track.id)
        return Button {
            Task { await account.toggleLike(trackID: track.id) }
        } label: {
            Image(systemName: liked ? "heart.fill" : "heart")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(liked ? Theme.accent : .white.opacity(0.88))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(liked ? "取消收藏" : "收藏")
        .accessibilityIdentifier("immersiveFavoriteButton")
    }

    private func moreMenu(for track: Track) -> some View {
        Menu {
            TrackDownloadActions(track: track, showsIcons: true)
            TrackBlacklistMenu(track: track, showsIcons: true)
            SongCommentsMenuButton(track: track, showsIcons: true) {
                commentsTrack = track
            }
            Divider()
            Button {
                airPlayRequest += 1
            } label: {
                Label("AirPlay", systemImage: "airplayaudio")
            }

            Button {
                player.addToPlayNext(track)
            } label: {
                Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
            }

            Button {
                showAddToPlaylist = true
            } label: {
                Label("加入歌单…", systemImage: "music.note.list")
            }

            Divider()

            #if os(iOS)
            SleepTimerMenu(player: player)

            Divider()
            #endif

            Button {
                Platform.copyToPasteboard(
                    string: Upstream.songPageURL(id: track.id)?.absoluteString ?? ""
                )
                ToastCenter.shared.show(String(localized: "链接已复制"))
            } label: {
                Label("复制链接", systemImage: "link")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        #if os(iOS)
        // Let the native menu animate from a stable source frame.
        .buttonStyle(.plain)
        #else
        .buttonStyle(.pressable)
        #endif
        .accessibilityLabel("更多操作")
        .accessibilityIdentifier("immersiveMoreMenu")
        .background {
            RoutePickerButton(
                diameter: 1, glyphSize: 1, request: airPlayRequest,
                tint: .clear, background: .clear
            )
            .opacity(0.01)
        }
    }
}

private struct MinimalTransportControls: View {
    @EnvironmentObject private var player: PlayerService
    let backdrop: ArtworkColors
    @Binding var showQueue: Bool
    let onOpenDestination: (Destination) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityLabel("播放列表")
            .accessibilityIdentifier("immersivePlaylistButton")
                .frame(maxWidth: .infinity)

            Button(action: player.isFMMode ? player.fmTrash : player.previous) {
                Image(systemName: player.isFMMode ? "trash" : "backward.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .accessibilityLabel(player.isFMMode ? "不喜欢" : "上一首")

            Button(action: player.togglePlayPause) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 38, weight: .bold))
                    .contentTransition(.opacity)
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .accessibilityLabel(player.isPlaying ? "暂停" : "播放")

            Button(action: player.next) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .accessibilityLabel("下一首")

            playbackModeButton
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .buttonStyle(.pressable)
        .sheet(isPresented: $showQueue) {
            queueSheet
                .modifier(OfflinePlaybackAlert(player: player, onDownloads: {
                    showQueue = false
                    onOpenDestination(.downloaded)
                }, enabled: showQueue && player.showNowPlaying))
                .modifier(MeteredDownloadAlert(enabled: showQueue && player.showNowPlaying))
        }
    }

    @ViewBuilder
    private var queueSheet: some View {
        if #available(iOS 16.4, *) {
            IOSPlaybackQueueView(backdrop: backdrop)
                .presentationDetents([.fraction(0.5)])
                .presentationBackgroundInteraction(.enabled)
        } else {
            IOSPlaybackQueueView(backdrop: backdrop)
                .presentationDetents([.fraction(0.5)])
        }
    }

    @ViewBuilder
    private var playbackModeButton: some View {
        if player.isFMMode {
            Color.clear
                .frame(height: 44)
        } else {
            Button(action: player.cyclePlaybackMode) {
                Image(systemName: playbackModeIcon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(playbackModeTint)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playbackModeLabel)
        }
    }

    private var playbackModeIcon: String {
        if player.shuffleEnabled { return "shuffle" }
        switch player.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    private var playbackModeTint: Color {
        (player.shuffleEnabled || player.repeatMode != .off)
            ? Theme.accent
            : .white.opacity(0.88)
    }

    private var playbackModeLabel: LocalizedStringKey {
        if player.shuffleEnabled { return "随机播放" }
        switch player.repeatMode {
        case .off: return "顺序播放"
        case .all: return "列表循环"
        case .one: return "单曲循环"
        }
    }
}


#endif


// MARK: - Scrubber (white-on-dark variant)

struct NowPlayingScrubber: View {
    @EnvironmentObject private var player: PlayerService
    @ObservedObject private var clock = PlayerService.shared.clock

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var fraction: Double {
        guard player.duration > 0 else { return 0 }
        let value = isDragging ? dragProgress : clock.progress
        return min(max(value / player.duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.25))
                        .frame(height: 4)
                    Capsule()
                        .fill(.white)
                        .frame(width: max(4, width * fraction), height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(x: width * fraction - thumbDiameter / 2)
                        .opacity(isHovering || isDragging ? 1 : 0)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard player.duration > 0 else { return }
                            isDragging = true
                            player.isScrubbing = true
                            dragProgress = min(max(value.location.x / width, 0), 1) * player.duration
                        }
                        .onEnded { _ in
                            player.seek(to: dragProgress)
                            isDragging = false
                            player.isScrubbing = false
                        }
                )
            }
            .frame(height: 14)
            .onHover { hovering in
                withAnimation(AppAnimation.quick) { isHovering = hovering }
            }

            HStack {
                Text(Formatters.duration(isDragging ? dragProgress : clock.progress))
                Spacer()
                Text(Formatters.duration(player.duration))
            }
            .font(.system(size: 10.5).monospacedDigit())
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var thumbDiameter: CGFloat {
        isDragging ? 13 : (isHovering ? 11 : 9)
    }
}

// MARK: - Mini lyrics (compact now-playing)

/// Three synced lyric lines (previous / current / next) filling the gap
/// between the track meta and the transport controls on compact layouts.
/// Tapping opens the full lyrics page.
struct MiniLyricsView: View {
    var isVisible = true
    let onOpen: () -> Void

    #if os(iOS)
    @EnvironmentObject private var settings: SettingsManager
    #endif

    @EnvironmentObject private var player: PlayerService
    @ObservedObject private var lyricsCursor = PlayerService.shared.lyricsCursor

    private var lines: (previous: LyricLine?, current: LyricLine?, next: LyricLine?) {
        guard let lyrics = player.lyrics, !lyrics.isEmpty else { return (nil, nil, nil) }
        guard let index = lyricsCursor.activeIndex else {
            return (nil, nil, lyrics.lines.first)
        }
        let all = lyrics.lines
        return (
            index > 0 ? all[index - 1] : nil,
            all[index],
            index + 1 < all.count ? all[index + 1] : nil
        )
    }

    var body: some View {
        let (previous, current, next) = lines
        Group {
            if current != nil || next != nil {
                VStack(spacing: 12) {
                    line(previous, emphasized: false)
                    line(current, emphasized: true)
                    line(next, emphasized: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: current?.id)
            } else {
                Color.clear
            }
        }
    }

    private func line(_ line: LyricLine?, emphasized: Bool) -> some View {
        Group {
            #if os(iOS)
            if isVisible, emphasized, let line, !line.text.isEmpty,
               settings.verbatimLyrics, line.words?.isEmpty == false {
                LyricMainText(
                    line: line, isActive: true, size: 17, weight: .bold,
                    verbatim: settings.verbatimLyrics, alignment: .center, singleLine: true
                )
            } else {
                plainLine(line, emphasized: emphasized)
            }
            #else
            plainLine(line, emphasized: emphasized)
            #endif
        }
        .padding(.horizontal, 28)
        .id(line?.id)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func plainLine(_ line: LyricLine?, emphasized: Bool) -> some View {
        Text(line?.text.isEmpty == false ? line!.text : " ")
            .font(.system(size: emphasized ? 17 : 14, weight: emphasized ? .bold : .medium))
            .foregroundStyle(.white.opacity(emphasized ? 1 : 0.45))
            .lineLimit(1)
            .multilineTextAlignment(.center)
    }
}
