import SwiftUI

#if os(iOS)

struct CollectionCoverPreference: DynamicProperty {
    @AppStorage("collectionCoverStyle") private var portrait = "classic"
    @AppStorage("collectionCoverStyleLandscape") private var landscape = ""

    var portraitSelection: Binding<String> {
        Binding(get: { style(landscape: false) }, set: { value in
            // Freeze the old shared choice before the first portrait edit.
            if landscape.isEmpty { landscape = portrait }
            portrait = value
        })
    }

    var landscapeSelection: Binding<String> {
        Binding(get: { style(landscape: true) }, set: { landscape = $0 })
    }

    func style(landscape: Bool) -> String {
        if landscape { return self.landscape.isEmpty ? portrait : self.landscape }
        return portrait == CollectionGradientStyle.flow.rawValue ? CollectionGradientStyle.soft.rawValue : portrait
    }
}

/// Shared composition for playlist and album detail pages.
struct GradientCollectionPage<Tools: View, Rows: View>: View {
    let width: CGFloat
    let landscapeLeftWidth: CGFloat?
    let coverURL: URL?
    let style: CollectionGradientStyle
    var portraitSquareCover = false
    let title: String
    let author: String?
    var authorLink: Destination? = nil
    let description: String?
    var editDescription: (() -> Void)? = nil
    var isFavorite = false
    var canPlay = true
    let play: () -> Void
    var favorite: (() -> Void)? = nil
    var searchLabel: LocalizedStringKey = "在歌单内查找"
    var search: (() -> Void)? = nil
    @ViewBuilder var tools: () -> Tools
    @ViewBuilder var rows: () -> Rows

    @State private var image: PlatformImage? = nil
    @State private var palette = ArtworkColors.collectionFallback
    @State private var flowCoverAspect = 0
    @State private var showDescription = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 迷你播放条矩形（屏幕坐标）：封面正方形取底边，文字块停在它上沿。
    @Environment(\.miniPlayerFrame) private var miniPlayerFrame

    private var heroAccent: Color { portraitSquareCover ? (palette.heroAccent ?? palette.secondary) : palette.secondary }
    private var coverHeight: CGFloat { min(max(260, width), 520) }
    private var hasFlow: Bool { style == .flow && palette.flowEdges.count == 4 }
    private var coverAspect: Int {
        if landscapeLeftWidth != nil { return style == .flow && !portraitSquareCover ? flowCoverAspect : 100 }
        if portraitSquareCover { return 100 }
        return max(1, Int((width / coverHeight * 100).rounded()))
    }

    var body: some View {
        Group {
            if let fallbackLeftWidth = landscapeLeftWidth {
                GeometryReader { proxy in
                    // 歌单封面从屏幕顶延伸到播放控制器底边，保持正方形。
                    let side = landscapeSide(available: proxy.size.width,
                                             topInset: proxy.safeAreaInsets.top,
                                             fallback: fallbackLeftWidth)
                    let contentLeft = proxy.frame(in: .global).minX
                    let flowOffset = portraitSquareCover && hasFlow ? max(0, (miniPlayerFrame?.minX ?? contentLeft) - contentLeft) : 0
                    let copyWidth = landscapeCopyWidth(available: proxy.size.width,
                                                       fallback: fallbackLeftWidth)
                    // 文字宽度保持不变，中心与实际封面一致（流光封面可能向右偏移）。
                    let copyOffset = portraitSquareCover ? (side - copyWidth) / 2 + flowOffset : 0
                    HStack(alignment: .top, spacing: 0) {
                        landscapeHero(copyWidth: copyWidth).frame(width: side)
                            .offset(x: copyOffset)
                        ScrollView {
                            collectionSongs
                            PlayerClearanceSpacer()
                        }
                        .scrollIndicators(.hidden)
                    }
                    .background {
                        GeometryReader { viewport in
                            let viewportLeft = viewport.frame(in: .global).minX
                            let left = max(0, contentLeft - viewportLeft)
                            let flowLeft = left + flowOffset
                            let inset = min(12, viewport.size.height * 0.03)
                            let cover = portraitSquareCover
                                ? CGRect(x: flowLeft, y: 0, width: side, height: side)
                                : CGRect(x: left, y: 0, width: side, height: viewport.size.height).insetBy(dx: inset, dy: inset)
                            ZStack(alignment: .topLeading) {
                                if hasFlow {
                                    CollectionFlowBackdrop(edges: palette.flowEdges, isLight: palette.isLight, cover: cover)
                                    flowLandscapeArtwork(size: cover.size).offset(x: cover.minX, y: cover.minY)
                                } else {
                                    landscapeArtwork(side: side).offset(x: left)
                                }
                            }
                            .frame(width: viewport.size.width, height: viewport.size.height, alignment: .topLeading)
                            .onGeometryChange(for: Int.self) { _ in
                                guard cover.height > 0, cover.width > 0 else { return 0 }
                                return max(1, Int((cover.width / cover.height * 100).rounded()))
                            } action: { flowCoverAspect = $0 }
                        }
                        .ignoresSafeArea(.container)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }
            } else {
                ScrollView {
                    if portraitSquareCover {
                        squarePlaylistHero
                    } else {
                        hero
                    }
                    collectionSongs
                }
                .ignoresSafeArea(.container, edges: .top)
            }
        }
        .background(palette.primary.ignoresSafeArea())
        .environment(\.colorScheme, palette.isLight ? .light : .dark)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(palette.isLight ? .light : .dark, for: .navigationBar)
        .compatSymmetricTopEdgeEffect()
        .toolbar {
            if landscapeLeftWidth != nil {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: play) {
                        Label("播放全部", systemImage: "play.fill")
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!canPlay)
                    Button { favorite?() } label: {
                        Label(isFavorite ? "取消收藏" : "收藏", systemImage: isFavorite ? "heart.fill" : "heart")
                    }
                    .labelStyle(.iconOnly)
                    .disabled(favorite == nil)
                    if let search {
                        Button(action: search) {
                            Label(searchLabel, systemImage: "magnifyingglass")
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("playlistSearchButton")
                    }
                }
            }
        }
        .task(id: "\(coverURL?.absoluteString ?? "")|\(coverAspect)|\(style.rawValue)") {
            guard let coverURL else {
                image = nil
                palette = .collectionFallback
                return
            }
            let aspect = coverAspect
            guard aspect > 0 else { return }
            let decoded = await ImageCache.shared.image(for: coverURL)
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                image = decoded
                palette = decoded.map { ArtworkPalette.collection(from: $0, cacheKey: coverURL.absoluteString, aspect: aspect, style: style) }
                    ?? .collectionFallback
            }
        }
        .sheet(isPresented: $showDescription) {
            NavigationStack {
                ScrollView { Text(description ?? "").padding(20).frame(maxWidth: .infinity, alignment: .leading) }
                    .navigationTitle("简介")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showDescription = false } } }
            }
        }
    }

    private var collectionSongs: some View {
        VStack(spacing: 0) {
            tools().padding(.horizontal, 16)
            rows()
        }
    }

    private func landscapeHero(copyWidth: CGFloat) -> some View {
        GeometryReader { geo in
            // 标题 / 作者 / 简介：底边停在播放条上沿之上，避免被控制器盖住。
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                collectionCopy
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .frame(width: copyWidth,
                   height: copyHeight(column: geo.size, topInset: geo.safeAreaInsets.top),
                   alignment: .bottom)
        }
    }

    private func flowLandscapeArtwork(size: CGSize) -> some View {
        coverArt(size: size)
            .mask {
                flowEdgeFade(.leading, .trailing, softenRight: true)
                    .mask {
                        if portraitSquareCover {
                            flowEdgeFade(.top, .bottom)
                        } else {
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.14),
                                .init(color: .black, location: 0.57),
                                .init(color: .black.opacity(0.80), location: 0.69),
                                .init(color: .black.opacity(0.24), location: 0.86),
                                .init(color: .clear, location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                        }
                    }
            }
    }

    private func flowEdgeFade(_ start: UnitPoint, _ end: UnitPoint, softenRight: Bool = false) -> some View {
        let trailing: [Gradient.Stop] = softenRight ? [
            .init(color: .black, location: 0.89),
            .init(color: .black.opacity(0.95), location: 0.905),
            .init(color: .black.opacity(0.82), location: 0.92),
            .init(color: .black.opacity(0.57), location: 0.94),
            .init(color: .black.opacity(0.30), location: 0.96),
            .init(color: .black.opacity(0.09), location: 0.98),
            .init(color: .black.opacity(0.02), location: 0.99),
            .init(color: .clear, location: 1)
        ] : [
            .init(color: .black, location: 0.92),
            .init(color: .black.opacity(0.84), location: 0.94),
            .init(color: .black.opacity(0.16), location: 0.98),
            .init(color: .clear, location: 1)
        ]
        return LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .black.opacity(0.16), location: 0.02),
            .init(color: .black.opacity(0.84), location: 0.06),
            .init(color: .black, location: 0.08)
        ] + trailing, startPoint: start, endPoint: end)
    }

    private func landscapeArtwork(side: CGFloat) -> some View {
        coverArt(size: CGSize(width: side, height: side))
            .overlay(alignment: .bottom) {
                LinearGradient(stops: [
                    .init(color: palette.primary.opacity(0), location: 0),
                    .init(color: palette.primary.opacity(0.70), location: 0.58),
                    .init(color: palette.primary, location: 1)
                ], startPoint: .top, endPoint: .bottom)
                .frame(height: side * 0.68)
            }
            .mask {
                edgeFade(.leading, .trailing)
                    .mask { edgeFade(.top, .bottom) }
            }
    }

    /// 横屏封面边长：屏幕顶 → 播放条**底部**（屏幕坐标），封面底边与控制器底边齐平，
    /// 边长比原来（到中线）多出半个控制器的高度，宽度同步变大、右半跟着右移。
    private func landscapeSide(available: CGFloat, topInset: CGFloat, fallback: CGFloat) -> CGFloat {
        guard let frame = miniPlayerFrame, frame.maxY > 0 else { return fallback }
        let side = frame.maxY
        // 极端窄屏时别把右半挤没：最多占可用宽度的 62%。
        return min(side, max(120, available * 0.62))
    }

    /// 保留按播放控制器中线计算的文字块宽度，不改变换行。
    private func landscapeCopyWidth(available: CGFloat, fallback: CGFloat) -> CGFloat {
        guard let frame = miniPlayerFrame, frame.midY > 0 else { return fallback }
        return min(frame.midY, max(120, available * 0.62))
    }

    /// 文字块可用的高度：屏幕顶到播放条上沿，再留 12pt 间隙。
    private func copyHeight(column: CGSize, topInset: CGFloat) -> CGFloat {
        guard let frame = miniPlayerFrame, frame.minY > 0 else {
            return max(120, column.height - Theme.Layout.FloatingChrome.miniPlayerHeight - 12)
        }
        // 播放条上沿再让 8pt，文字才不会被压在控制器下面。
        return max(120, frame.minY - topInset - 8)
    }

    /// 边缘淡出：横屏封面左右各让出一小段，多段插值让过渡更软。
    private func edgeFade(_ start: UnitPoint, _ end: UnitPoint) -> some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .black.opacity(0.28), location: 0.022),
            .init(color: .black.opacity(0.55), location: 0.047),
            .init(color: .black.opacity(0.80), location: 0.074),
            .init(color: .black, location: 0.105),
            .init(color: .black, location: 0.895),
            .init(color: .black.opacity(0.80), location: 0.926),
            .init(color: .black.opacity(0.55), location: 0.953),
            .init(color: .black.opacity(0.28), location: 0.978),
            .init(color: .clear, location: 1)
        ], startPoint: start, endPoint: end)
    }

    private func coverArt(size: CGSize) -> some View {
        ZStack {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var collectionCopy: some View {
        VStack(spacing: landscapeLeftWidth == nil ? (portraitSquareCover ? 8 : 13) : 7) {
            Text(title)
                .font(.system(size: landscapeLeftWidth == nil ? 28 : 24, weight: .bold))
                .lineLimit(landscapeLeftWidth == nil && !portraitSquareCover ? nil : 2)
                .foregroundStyle(portraitSquareCover ? (palette.isLight ? Color.black : Color.white) : palette.secondary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            let hasDescription = !(description ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if author?.isEmpty == false || (!hasDescription && editDescription != nil) {
                HStack(spacing: 5) {
                    if let author, !author.isEmpty {
                        Text(verbatim: "by").foregroundStyle(.secondary)
                        if let authorLink {
                            NavigationLink(value: authorLink) { Text(author).foregroundStyle(.primary) }
                                .buttonStyle(.plain)
                        } else { Text(author).lineLimit(1) }
                    }
                    if !hasDescription, let editDescription {
                        Button(action: editDescription) {
                            Image(systemName: "arrow.right")
                                .font(.footnote)
                                .frame(minWidth: 24, minHeight: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("打开歌单编辑")
                    }
                }
                .font(.subheadline)
            }
            if let description, hasDescription {
                Button {
                    if let editDescription { editDescription() } else { showDescription = true }
                } label: {
                    HStack(spacing: 5) {
                        Text(description.replacingOccurrences(of: "\n", with: " "))
                            .lineLimit(2)
                            .multilineTextAlignment(portraitSquareCover ? .center : .leading)
                        Image(systemName: "arrow.right")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看简介")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var actionPills: some View {
        HStack(spacing: 10) {
            Button(action: play) {
                Image(systemName: "play.fill")
                    .foregroundStyle(palette.primary)
                    .frame(width: 90, height: 44)
                    .background(heroAccent, in: Capsule())
            }
            .disabled(!canPlay)
            .opacity(canPlay ? 1 : 0.5)
            .accessibilityLabel("播放全部")
            Button { favorite?() } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? palette.secondary : Color.primary)
                    .frame(width: 90, height: 44)
                    .background(palette.secondary.opacity(0.12), in: Capsule())
            }
            .disabled(favorite == nil)
            .opacity(favorite == nil ? 0.5 : 1)
            .accessibilityLabel(isFavorite ? "取消收藏" : "收藏")
        }
        .font(.system(size: 21, weight: .medium))
        .buttonStyle(.pressable)
        .padding(.top, 6)
    }

    private var squarePlaylistHero: some View {
        VStack(spacing: 0) {
            coverArt(size: CGSize(width: width, height: width))
                .overlay(alignment: .bottom) {
                    collectionCopy
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                        .background {
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: palette.primary.opacity(0.72), location: 0.52),
                                .init(color: palette.primary, location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                            .padding(.top, -10)
                        }
                }
            actionPills
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
    }

    private var hero: some View {
        VStack(spacing: 13) {
            collectionCopy
            actionPills
        }
        .padding(.horizontal, 20)
        .padding(.top, coverHeight * 0.76)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            ZStack {
                coverArt(size: CGSize(width: width, height: coverHeight))
                // 竖屏：降低衔接处的底色覆盖，封面主体保留更多细节。
                LinearGradient(stops: [
                    .init(color: (style == .dimmed ? Color.black : palette.primary).opacity(0.28), location: 0),
                    .init(color: .clear, location: 0.34),
                    .init(color: palette.primary.opacity(0), location: 0.62),
                    .init(color: palette.primary.opacity(0.06), location: 0.67),
                    .init(color: palette.primary.opacity(0.28), location: 0.73),
                    .init(color: palette.primary.opacity(0.60), location: 0.79),
                    .init(color: palette.primary.opacity(0.84), location: 0.85),
                    .init(color: palette.primary.opacity(0.96), location: 0.93),
                    .init(color: palette.primary, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
            .frame(width: width, height: coverHeight)
        }
    }
}

/// A single curved field under both columns keeps the cover-to-list transition continuous.
private struct CollectionFlowBackdrop: View {
    let edges: [[SIMD3<Double>]]
    let isLight: Bool
    let cover: CGRect

    private struct Input: Equatable {
        let edges: [[SIMD3<Double>]]
        let isLight: Bool
        let cover: CGRect
        let viewport: CGSize
    }

    @State private var texture: CGImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let input = Input(edges: edges, isLight: isLight, cover: cover, viewport: geo.size)
            Color.clear
                .overlay {
                    if let texture {
                        flowImage(texture)
                            .overlay {
                                if !reduceMotion {
                                    TimelineView(.animation(minimumInterval: 1 / 30, paused: scenePhase != .active)) { timeline in
                                        // 流光：走闭合椭圆（x=±4.2%、y=±2.8%），9s 一圈匀速推进。
                                        // 相位 0 与 2π 完全重合，首尾帧一致，循环接缝不可见；缩放 1.14 兜住极值边缘。
                                        let time = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 9)
                                        let phase = time / 9 * 2 * .pi
                                        flowImage(texture)
                                            .scaleEffect(1.14)
                                            .offset(x: input.viewport.width * 0.042 * CGFloat(sin(phase)),
                                                    y: input.viewport.height * 0.028 * CGFloat(-cos(phase)))
                                    }
                                    .mask { motionMask(viewport: input.viewport) }
                                }
                            }
                            .clipped()
                            .compositingGroup()
                            .opacity(0.94)
                    }
                }
                .task(id: input) {
                    texture = ArtworkPalette.flowTexture(input.edges, viewport: input.viewport,
                                                         cover: input.cover, isLight: input.isLight)
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func flowImage(_ texture: CGImage) -> some View {
        Image(decorative: texture, scale: 1)
            .resizable()
            .interpolation(.high)
    }

    private func motionMask(viewport: CGSize) -> some View {
        // Fully transparent over the cover; blend the moving copy in only beyond its edges.
        let x = min(1, max(0, cover.maxX / max(1, viewport.width)))
        let y = min(1, max(0, cover.maxY / max(1, viewport.height)))
        return ZStack {
            LinearGradient(stops: [.init(color: .clear, location: x),
                                   .init(color: .black, location: min(1, x + 0.18))],
                           startPoint: .leading, endPoint: .trailing)
            LinearGradient(stops: [.init(color: .clear, location: y),
                                   .init(color: .black, location: min(1, y + 0.18))],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}
#endif
