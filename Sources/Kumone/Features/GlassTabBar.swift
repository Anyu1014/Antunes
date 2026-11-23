#if os(iOS)
import SwiftUI

/// Tab content (56pt + 4pt inset = 64pt) inside the bottom row's persistent
/// glass capsule, holding a sliding selection lens and the tab items.
///   • the lens is the system's own Liquid Glass (`glassEffect`), not a drawn
///     tint, so it refracts like every other glass surface on iOS 26/27;
///   • items use a 23pt filled icon and a 10pt semibold label in one colour —
///     primary @ 80% at rest, accent for whichever tab the lens is over;
///   • the lens can be dragged: it tracks the finger, and the app only
///     switches pages when the finger lifts, the way a system control commits
///     on release rather than mid-gesture.
struct GlassTabBar: View {
    struct Item: Identifiable {
        let tab: IOSTab
        let title: LocalizedStringKey
        let icon: String
        var id: IOSTab { tab }
    }

    let items: [Item]
    @Binding var selection: IOSTab
    var onReselect: (IOSTab) -> Void = { _ in }

    @AppStorage("tabBarShowsLabels") private var showsLabels = false

    /// Finger x (in content space) while actively dragging the pill; nil at rest.
    @State private var dragX: CGFloat?
    @State private var isDragging = false
    /// 切换板块的「最后一步说话」：新点击直接打断上一次的收尾任务，
    /// 状态立刻改成新目标（SwiftUI 会让同一条动画重定向，不会叠出新轨），
    /// 上一次挂的清理任务被 cancel，绝不和这一次并行。
    @State private var switchTask: Task<Void, Never>?
    /// 机械抖动保护：同一瞬间的重复触摸直接丢掉，避免同一帧里连开两条动画。
    @State private var lastSwitchAt = Date.distantPast

    private let innerInset: CGFloat = 4
    private let contentHeight: CGFloat = 56
    private let settle = Animation.spring(response: 0.35, dampingFraction: 0.82)

    var body: some View {
        GeometryReader { geo in
            let count = max(items.count, 1)
            let cellW = geo.size.width / CGFloat(count)
            let selectedIndex = items.firstIndex { $0.tab == selection } ?? 0
            let restX = cellW * (CGFloat(selectedIndex) + 0.5)
            let pillX = isDragging
                ? min(max(dragX ?? restX, cellW / 2), geo.size.width - cellW / 2)
                : restX
            // While the pill is in hand the nearest tab lights up, but the
            // page only follows once the finger lifts — the native feel.
            let litIndex = isDragging
                ? index(for: pillX, cellW: cellW, count: count)
                : selectedIndex

            ZStack(alignment: .leading) {
                // Behind the labels, the way the system tab bar layers its
                // glass: the lens tints the bar, the labels stay sharp on top.
                selectionPill
                    .frame(width: cellW - 8, height: contentHeight)
                    .position(x: pillX, y: geo.size.height / 2)
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                        itemLabel(item, lit: offset == litIndex)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(item.title))
                            .accessibilityIdentifier("section-tab-\(item.tab.rawValue)")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAddTraits(item.tab == selection ? .isSelected : [])
                            .accessibilityAction {
                                if item.tab == selection { onReselect(item.tab) }
                                else { requestSwitch(to: item.tab) }
                            }
                    }
                }
            }
            .contentShape(Rectangle())
            // High priority: nothing behind the bar may claim the drag and
            // page the content while the lens is still in hand.
            .highPriorityGesture(dragGesture(cellW: cellW, count: count))
        }
        .frame(height: contentHeight)
        .padding(innerInset)
    }

    private func itemLabel(_ item: GlassTabBar.Item, lit: Bool) -> some View {
        return VStack(spacing: showsLabels ? 3 : 0) {
            Image(systemName: item.icon)
                .font(.system(size: 23, weight: .semibold))
                .symbolVariant(lit ? .fill : .none)
            if showsLabels {
                Text(item.title)
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(lit
                         ? AnyShapeStyle(Theme.accent)
                         : AnyShapeStyle(Color.primary.opacity(0.8)))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }


    /// 选中镜片：系统 Liquid Glass，无 tint、无描边、无阴影，靠材质自己的
    /// 边缘折射和顶部高光读出来。
    @ViewBuilder
    private var selectionPill: some View {
        if #available(iOS 26.0, *) {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: Capsule(style: .continuous))
        } else {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.34), .white.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom))
                        .blendMode(.plusLighter)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.30), lineWidth: 0.6)
                }
        }
    }

    private func index(for x: CGFloat, cellW: CGFloat, count: Int) -> Int {
        min(max(Int(x / cellW), 0), count - 1)
    }

    /// 一次胶囊滑动的时间（与上面 `settle` 的弹簧大致对齐）。
    private let switchDuration: Double = 0.32

    private func requestSwitch(to tab: IOSTab) {
        guard tab != selection else { return }
        // 20ms 内的重复触摸视为同一次（触控抖动），直接丢。
        let now = Date()
        guard now.timeIntervalSince(lastSwitchAt) > 0.02 else { return }
        lastSwitchAt = now

        // 打断上一次：把它挂的收尾任务取消，本次动作独立成立。
        switchTask?.cancel()

        withAnimation(settle) { selection = tab }

        switchTask = Task { @MainActor in
            let ns = UInt64(switchDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            // 本次动作彻底结束：停掉清理任务，后续不再有任何残留工作。
            switchTask = nil
        }
    }

    private func dragGesture(cellW: CGFloat, count: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging && abs(value.translation.width) < 8 { return }
                isDragging = true
                dragX = value.location.x
                // The page deliberately does not change here: dragging only
                // moves the lens, exactly as the system tab bar behaves.
            }
            .onEnded { value in
                let tab = items[index(for: value.location.x, cellW: cellW, count: count)].tab
                if isDragging {
                    withAnimation(settle) { selection = tab; dragX = nil }
                } else if tab == selection {
                    onReselect(tab)
                } else {
                    requestSwitch(to: tab)
                }
                isDragging = false
            }
    }
}
#endif

#if os(iOS)
/// 系统液态玻璃（iOS 26+），旧系统退回 `regularMaterial`。
/// 注意：玻璃会折射它背后的内容，在浅色底栏上「无色玻璃」几乎等于隐形，
/// 需要 `Glass.tint` 才看得出是一颗球——这是之前底栏像没有球的原因。
///
/// `.interactive()`：按住时由系统给玻璃本身加高光并轻微缩放回弹，和工具栏里
/// 搜索/设置那两颗液态按钮用的是同一套反馈。底栏这三块是容器、不是 `Button`，
/// 不加这个就只剩材质、没有按压态——按下去是死的。
private struct NativeGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content.background(Capsule().fill(.regularMaterial))
        }
    }
}

private struct NativeGlassCircle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content.background(Circle().fill(.regularMaterial))
        }
    }
}

/// 同一个 `GlassEffectContainer` 里的两片玻璃靠得够近时会自己连成一片，
/// 就是原生底栏里「选中胶囊和旁边那颗圆按钮吸在一起」的那道颈。
/// 只有挂在容器里的形状才认这个 id；旧系统原样返回。
private struct GlassMorphID: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}

extension View {
    func nativeGlassCapsule() -> some View { modifier(NativeGlassCapsule()) }
    func nativeGlassCircle() -> some View { modifier(NativeGlassCircle()) }
    func glassMorphID(_ id: String, in namespace: Namespace.ID) -> some View {
        modifier(GlassMorphID(id: id, namespace: namespace))
    }

    /// 只有调用方明确给了命名空间才挂 id（迷你播放条在竖屏不参与合并）。
    @ViewBuilder
    func glassMorphID(_ id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            glassMorphID(id, in: namespace)
        } else {
            self
        }
    }
}

#endif
