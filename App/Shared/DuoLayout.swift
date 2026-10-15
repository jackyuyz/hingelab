import SwiftUI
import FoldKit
import HingeL10n
import ThemeKit

/// Duo-aware shell: inner unfolded, half-folded split, outer cover, no-hinge ribbon.
struct DuoAwareScaffold<Content: View>: View {
    let foldState: FoldState
    let metrics: DisplayMetrics
    let crease: CreaseRegion?
    let leftHanded: Bool
    let horizontalSplit: Bool
    @ViewBuilder var content: () -> Content
    @ViewBuilder var left: () -> Content
    @ViewBuilder var right: () -> Content
    var compact: () -> Content

    var body: some View {
        Group {
            switch foldState.posture {
            case .partiallyOpen:
                DuoSplitStack(
                    horizontal: horizontalSplit,
                    crease: crease,
                    leftHanded: leftHanded,
                    left: left,
                    right: right
                )
            case .closed:
                compact()
            case .fullyOpen, .unknown, .noHinge:
                content()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DuoSplitStack<Left: View, Right: View>: View {
    var horizontal: Bool
    var crease: CreaseRegion?
    var leftHanded: Bool
    var accent: Color = .secondary
    @ViewBuilder var left: () -> Left
    @ViewBuilder var right: () -> Right

    var body: some View {
        // TODO(verify-api): iOS 27.1 ArrangementView { } secondary: { }
        //     .arrangementViewStyle(.split)
        //     .split.axes(horizontal ? .horizontal : .vertical)
        // Put it inside a NavigationStack, never inside List / ScrollView.
        // Do not invent a different API name if this fails to compile.
        let first: AnyView = leftHanded ? AnyView(right()) : AnyView(left())
        let second: AnyView = leftHanded ? AnyView(left()) : AnyView(right())
        Group {
            if horizontal {
                HStack(spacing: 0) {
                    first.frame(maxWidth: .infinity, maxHeight: .infinity)
                    CreaseGuideSlot(region: crease, accent: accent)
                    second.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    first.frame(maxWidth: .infinity, maxHeight: .infinity)
                    CreaseGuideSlot(region: crease, vertical: true, accent: accent)
                    second.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

/// Named slot for the crease. Width comes from `CreaseRegionProviding`, never
/// hardcoded Duo pixels. The guide is drawn as a hinge line with knuckles so
/// the fold reads as part of the instrument; it overhangs a zero-width region
/// without taking layout space.
struct CreaseGuideSlot: View {
    var region: CreaseRegion?
    var vertical = false
    var accent: Color = .secondary
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let width = CGFloat(region?.width ?? 0)
        Color.clear
            .frame(width: vertical ? nil : width, height: vertical ? width : nil)
            .overlay {
                Canvas { ctx, size in
                    let length = vertical ? size.width : size.height
                    let line = model.theme.ui(.creaseGuide)
                    let mid = vertical ? size.height / 2 : size.width / 2
                    var path = Path()
                    if vertical {
                        path.move(to: CGPoint(x: 0, y: mid))
                        path.addLine(to: CGPoint(x: length, y: mid))
                    } else {
                        path.move(to: CGPoint(x: mid, y: 0))
                        path.addLine(to: CGPoint(x: mid, y: length))
                    }
                    ctx.stroke(path, with: .color(line), lineWidth: 2)
                    // Hinge knuckles every 18 % of the length.
                    for i in 0..<5 {
                        let t = (0.14 + 0.18 * CGFloat(i)) * length
                        let knuckle = vertical
                            ? CGRect(x: t - 9, y: mid - 3, width: 18, height: 6)
                            : CGRect(x: mid - 3, y: t - 9, width: 6, height: 18)
                        ctx.fill(Path(roundedRect: knuckle, cornerRadius: 3), with: .color(i == 2 ? accent : line))
                    }
                }
                .frame(width: vertical ? nil : max(width, 8), height: vertical ? max(width, 8) : nil)
                .allowsHitTesting(false)
            }
            .accessibilityElement()
            .accessibilityIdentifier("slot.crease")
            .accessibilityLabel(L10nKey.slotCrease.text(in: model.language))
    }
}

struct RuntimeGeometryReader: ViewModifier {
    @Binding var metrics: DisplayMetrics
    @Environment(\.displayScale) private var displayScale

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { publish(proxy) }
                    .onChange(of: proxy.size) { _, _ in publish(proxy) }
                    .onChange(of: proxy.safeAreaInsets) { _, _ in publish(proxy) }
            }
        }
    }

    private func publish(_ proxy: GeometryProxy) {
        let insets = proxy.safeAreaInsets
        metrics = DisplayMetrics(
            pointWidth: Double(proxy.size.width),
            pointHeight: Double(proxy.size.height),
            displayScale: Double(displayScale),
            safeAreaTop: Double(insets.top),
            safeAreaLeft: Double(insets.leading),
            safeAreaBottom: Double(insets.bottom),
            safeAreaRight: Double(insets.trailing)
        )
    }
}

extension View {
    func readDisplayMetrics(_ metrics: Binding<DisplayMetrics>) -> some View {
        modifier(RuntimeGeometryReader(metrics: metrics))
    }
}

/// TODO(verify-api): `GeometryProxy.reservedRegions(kind: .division)` exists only
/// while half-folded and is empty on the first layout pass — re-query with
/// `onGeometryChange`. Do not invent another API if this does not compile.
struct ReservedRegionProbe: ViewModifier {
    var posture: FoldPosture
    @Binding var crease: CreaseRegion?

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { update(size: proxy.size) }
                    .onChange(of: proxy.size) { _, size in update(size: size) }
                    .onChange(of: posture) { _, _ in update(size: proxy.size) }
            }
        }
    }

    private func update(size: CGSize) {
        // if #available(iOS 27.1, *) {
        //     let regions = proxy.reservedRegions(kind: .division)
        //     crease = regions.first.map { CreaseRegion(x: $0.x, ...) }
        // }
        let mock = MockCreaseRegionProvider(isHalfFolded: posture == .partiallyOpen)
        crease = mock.division(inWidth: Double(size.width), height: Double(size.height))
    }
}
