import SwiftUI

/// Design tokens: color, radius, spacing, layout metrics.
enum Theme {
    /// Accent red, tuned slightly warmer for macOS.
    static let accent = Color(red: 0.925, green: 0.286, blue: 0.286) // #EC4949
    static let accentDeep = Color(red: 0.788, green: 0.161, blue: 0.161) // #C92929

    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.973, green: 0.357, blue: 0.357), accentDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    enum Radius {
        static let badge: CGFloat = 4
        static let small: CGFloat = 6
        static let standard: CGFloat = 8
        static let large: CGFloat = 12
        static let panel: CGFloat = 20
    }

    enum Layout {
        static let contentInset: CGFloat = 24
        static let cardSize: CGFloat = 160
        static func fittedShelfCardSize(availableWidth: CGFloat, leadingInset: CGFloat, spacing: CGFloat = 16) -> CGFloat {
            let usableWidth = availableWidth - leadingInset - spacing
            // A zero-width proposal while the split view is resizing still needs one 1pt card.
            let visibleCount = max(1, Int(ceil((usableWidth + spacing) / (cardSize + spacing))))
            return max(1, (usableWidth - CGFloat(visibleCount - 1) * spacing) / CGFloat(visibleCount))
        }
        #if os(iOS)
        /// Row height for a shelf of cover cards: artwork, one line of title
        /// and one of subtitle. Shelf titles are single-line on iOS
        /// (`shelfTitleLineLimit`), so the row carries no slack below them.
        static let coverShelfHeight: CGFloat = 206
        /// Row height for a shelf of artist cards: circular artwork, one name.
        static let artistShelfHeight: CGFloat = 160
        static let shelfTitleLineLimit = 1
        /// Top inset of a browsing page; the large navigation title already
        /// separates it from the status bar.
        static let pageTopPadding: CGFloat = 4
        #else
        /// Row height for a shelf of cover cards: artwork, then up to two lines
        /// of title and one of subtitle.
        static let coverShelfHeight: CGFloat = 226
        /// Row height for a shelf of artist cards: circular artwork, one name.
        static let artistShelfHeight: CGFloat = 196
        static let shelfTitleLineLimit = 2
        static let pageTopPadding: CGFloat = contentInset - 8
        #endif
        static let sidebarWidth: CGFloat = 220
        static let playerBarHeight: CGFloat = 56
        /// Gap between the floating player bar and the window's bottom edge.
        /// Must match the bar's own `.padding(.bottom,)` in PlayerBar.
        static let playerBarBottomMargin: CGFloat = 16
        /// Bottom inset pages need so scrolled content clears the floating bar.
        static var playerChromeClearance: CGFloat { playerBarHeight + playerBarBottomMargin }
        /// Extra breathing margin for scrollable content clearing chrome.
        static let scrollBreathingMargin: CGFloat = 8

        /// Vertical gap between the sections of a browsing page, and between a
        /// section header and its cards. iOS shows one column on a short
        /// screen, so its sections sit tighter than the desktop ones.
        #if os(iOS)
        static let sectionSpacing: CGFloat = 20
        static let sectionHeaderSpacing: CGFloat = 10
        #else
        static let sectionSpacing: CGFloat = 34
        static let sectionHeaderSpacing: CGFloat = 14
        #endif

        #if os(iOS)
        enum FloatingChrome {
            /// Total height of GlassTabBar: 56pt content + 2 * 4pt inset.
            static let tabBarHeight: CGFloat = 64
            /// Total height of legacy mini player bar: 44pt button + 2 * 4pt vertical padding.
            static let miniPlayerHeight: CGFloat = 52
            /// Spacing between mini player and tab bar in customTabInterface.
            static let barSpacing: CGFloat = 8
            /// Bottom padding under the tab bar.
            static let bottomMargin: CGFloat = 6
            /// Breathing margin ensuring content clears above the floating bars.
            static let extraPadding: CGFloat = 12

            /// Clearance needed when only the tab bar is visible.
            static var tabBarClearance: CGFloat {
                tabBarHeight + bottomMargin + extraPadding
            }

            /// Clearance needed when both mini player and tab bar are visible.
            static var fullChromeClearance: CGFloat {
                miniPlayerHeight + barSpacing + tabBarHeight + bottomMargin + extraPadding
            }
        }
        #endif
        static let minWindowWidth: CGFloat = 1020
        static let minWindowHeight: CGFloat = 640
        static let defaultWindowWidth: CGFloat = 1200
        static let defaultWindowHeight: CGFloat = 780
    }
}

/// Motion tokens (mirrors kaset's `AppAnimation`).
enum AppAnimation {
    static let quick = Animation.easeOut(duration: 0.15)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let smooth = Animation.easeInOut(duration: 0.35)
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.8)

    static let staggerDelay = 0.04
    static let maxStaggerDelay = 0.4

    static func stagger(for index: Int) -> Double {
        min(Double(index) * staggerDelay, maxStaggerDelay)
    }
}

extension View {
    /// `scrollClipDisabled` is iOS 17 / macOS 14; older systems clip normally.
    @ViewBuilder
    func compatScrollClipDisabled() -> some View {
        if #available(iOS 17.0, macOS 14.0, *) { scrollClipDisabled() } else { self }
    }

    /// Hides the toolbar background; `toolbarBackgroundVisibility` is
    /// macOS 15+/iOS 18+, so iOS 17 falls back to `toolbarBackground`.
    @ViewBuilder
    func compatHiddenToolbarBackground() -> some View {
        #if os(macOS)
        toolbarBackgroundVisibility(.hidden, for: .automatic)
        #else
        if #available(iOS 18.0, *) {
            toolbarBackgroundVisibility(.hidden, for: .automatic)
        } else {
            toolbarBackground(.hidden, for: .navigationBar)
        }
        #endif
    }

    /// iOS 顶部吸顶条。
    ///
    /// 竖屏：整条磨砂，列表从下面滑过时还能透出一点，和安卓端顶栏的
    /// `backdrop-filter` 同一观感。横屏：不再给顶栏铺底色，只留一层自建的
    /// 渐进模糊（向下渐隐），按钮位置不变——和安卓端横屏那层遮罩对齐。
    /// macOS 保持系统工具栏不动。
    func frostedNavigationBar() -> some View {
        modifier(TopBarBackground(portraitFrosted: true))
    }

    /// 只在横屏生效的顶栏处理：去掉系统导航栏的实底，换成自建渐进模糊；
    /// 竖屏原样返回，不碰任何默认样式。
    func progressiveTopBarInLandscape() -> some View {
        modifier(TopBarBackground(portraitFrosted: false))
    }

    /// Glass background with a graceful material fallback on macOS 15.
    @ViewBuilder
    func compatGlass(interactive: Bool = false, in shape: some Shape) -> some View {
        #if os(macOS)
        if #available(macOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
        #elseif os(iOS)
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
        #else
        self.background(.ultraThinMaterial, in: shape)
        #endif
    }
}

/// 横屏标记：由 `IOSMainWindow` 在窗口方向变化时写进环境，供顶栏决定要不要
/// 换成渐进模糊。
private struct LandscapeWindowKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isLandscapeWindow: Bool {
        get { self[LandscapeWindowKey.self] }
        set { self[LandscapeWindowKey.self] = newValue }
    }
}

/// 顶部一层向下渐隐的磨砂，代替不透明顶栏。和 Android 端
/// `#page::before` 的遮罩同一种做法：顶部最实，到 `fadeStart` 开始变透明。
/// 每页自己的底色（和窗口/inner 内容一致），顶栏渐变吃它才不会出现色差。
private struct PageBaseColorKey: EnvironmentKey {
    static let defaultValue = Color(uiColor: .systemBackground)
}

extension EnvironmentValues {
    var pageBaseColor: Color {
        get { self[PageBaseColorKey.self] }
        set { self[PageBaseColorKey.self] = newValue }
    }
}

struct ProgressiveTopBlur: View {
    var height: CGFloat = 96
    var fadeStart: CGFloat = 0.34
    @Environment(\.pageBaseColor) private var baseColor

    var body: some View {
        // 用页面底色本身做渐隐：顶栏区域和屏幕底层完全同色，
        // 内容滚到下面时再逐渐淡出，不会像材质那样把颜色抬亮一档。
        Rectangle()
            .fill(baseColor)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: fadeStart),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            // 横屏时左右也要贯穿整屏，否则只在安全区里那一条有模糊。
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

struct TopBarBackground: ViewModifier {
    /// 竖屏是否保留原来的整条磨砂导航栏。
    var portraitFrosted: Bool
    @Environment(\.isLandscapeWindow) private var isLandscape

    func body(content: Content) -> some View {
        #if os(iOS)
        if isLandscape {
            content
                .compatHiddenToolbarBackground()
                .overlay(alignment: .top) {
                    ProgressiveTopBlur()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
        } else if portraitFrosted {
            content
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
