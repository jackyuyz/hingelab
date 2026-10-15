import SwiftUI
import UIKit
import HingeL10n
import Instruments
import ThemeKit

// Shared instrument-surface components. Accessibility identifiers are the
// ones the foundation defined for each slot; do not rename them.

// MARK: - Geometry helpers

enum DialGeometry {
    /// Point on a half-dial: fraction 0 = left (closed), 1 = right (flat),
    /// sweeping over the top.
    static func point(center: CGPoint, radius: CGFloat, fraction: Double) -> CGPoint {
        let theta = Double.pi + fraction * Double.pi
        return CGPoint(x: center.x + radius * CGFloat(cos(theta)), y: center.y + radius * CGFloat(sin(theta)))
    }

    /// Arc as a polyline (avoids SwiftUI's flipped `clockwise` semantics).
    static func arc(center: CGPoint, radius: CGFloat, from: Double, to: Double, segments: Int = 64) -> Path {
        Path { path in
            let steps = max(1, Int(Double(segments) * abs(to - from)))
            for i in 0...steps {
                let f = from + (to - from) * Double(i) / Double(steps)
                let p = point(center: center, radius: radius, fraction: f)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
        }
    }
}

// MARK: - Angle gauge (slot.angleGauge)

/// Half-dial reading the hinge angle 0…180°, ivory ticks on a dark face with
/// the instrument hue as needle and sweep.
struct AngleGaugeSlot: View {
    var angle: Double?
    var language: AppLanguage
    var compact = false
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let theme = model.theme
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10nKey.slotAngleGauge.text(in: language))
                    .stageLabelStyle(theme)
                Spacer(minLength: 8)
                Text(readout)
                    .font(StageFont.readout(compact ? 15 : 20))
                    .foregroundStyle(theme.ui(.primaryText))
                    .contentTransition(.numericText())
            }
            AngleDial(
                fraction: InstrumentMotion.gaugeFraction(angleDegrees: angle),
                hasValue: angle != nil,
                tint: theme.ui(model.selectedInstrument.hueToken),
                theme: theme,
                showsNumerals: !compact
            )
            .frame(height: compact ? 54 : 88)
        }
        .padding(10)
        .background(theme.ui(.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("slot.angleGauge")
        .accessibilityLabel(L10nKey.slotAngleGauge.text(in: language))
        .accessibilityValue(readout)
    }

    private var readout: String {
        angle.map { String(format: "%.1f°", $0) } ?? "—"
    }
}

struct AngleDial: View {
    var fraction: Double
    var hasValue: Bool
    var tint: Color
    var theme: any ThemeProviding
    var showsNumerals = true

    var body: some View {
        Canvas { ctx, size in
            let radius = min(size.width / 2, size.height) * 0.94
            let center = CGPoint(x: size.width / 2, y: size.height - 1)
            let ink = theme.ui(.gauge)

            ctx.stroke(DialGeometry.arc(center: center, radius: radius * 0.95, from: 0, to: 1),
                       with: .color(theme.ui(.hairline)), lineWidth: 1)
            if hasValue, fraction > 0 {
                ctx.stroke(DialGeometry.arc(center: center, radius: radius * 0.95, from: 0, to: fraction),
                           with: .color(tint.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            for tick in InstrumentMotion.gaugeTicks() {
                let f = tick.degrees / 180
                let inner = DialGeometry.point(center: center, radius: radius * (tick.isMajor ? 0.72 : 0.82), fraction: f)
                let outer = DialGeometry.point(center: center, radius: radius * 0.88, fraction: f)
                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                ctx.stroke(path, with: .color(ink.opacity(tick.isMajor ? 0.9 : 0.4)), lineWidth: tick.isMajor ? 1.6 : 1)
            }
            if showsNumerals {
                for degrees in [0.0, 90, 180] {
                    let p = DialGeometry.point(center: center, radius: radius * 0.56, fraction: degrees / 180)
                    let label = Text("\(Int(degrees))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.65))
                    ctx.draw(label, at: CGPoint(x: p.x, y: min(p.y, center.y - 7)))
                }
            }
            if hasValue {
                let tip = DialGeometry.point(center: center, radius: radius * 0.86, fraction: fraction)
                var needle = Path()
                needle.move(to: center)
                needle.addLine(to: tip)
                ctx.stroke(needle, with: .color(tint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            let pivot = CGRect(x: center.x - 4.5, y: center.y - 4.5, width: 9, height: 9)
            ctx.fill(Path(ellipseIn: pivot), with: .color(ink))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Scope (slot.waveform)

/// Phosphor oscilloscope. The trace shape follows the instrument's voice and
/// its height follows the output amplitude. Static with Reduce Motion.
struct WaveformSlot: View {
    var amplitude: Double
    var language: AppLanguage
    var height: CGFloat = 52
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let theme = model.theme
        let shape = model.selectedInstrument.scopeShape
        let level = amplitude
        VStack(alignment: .leading, spacing: 6) {
            Text(L10nKey.slotWaveform.text(in: language))
                .stageLabelStyle(theme)
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || level <= 0.001)) { timeline in
                let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1_000) * 1.3
                Canvas { ctx, size in
                    let grid = theme.ui(.hairline)
                    for i in 1..<8 {
                        let x = size.width * CGFloat(i) / 8
                        ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: size.height)) },
                                   with: .color(grid.opacity(0.7)), lineWidth: 0.5)
                    }
                    let mid = size.height / 2
                    ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: mid)); $0.addLine(to: CGPoint(x: size.width, y: mid)) },
                               with: .color(grid), lineWidth: 0.75)
                    let count = max(16, Int(size.width / 3))
                    let values = InstrumentMotion.scopeTrace(points: count, cycles: 3, amplitude: level, shape: shape, phase: phase)
                    let trace = Path { path in
                        for (i, v) in values.enumerated() {
                            let p = CGPoint(x: size.width * CGFloat(i) / CGFloat(count - 1), y: mid - CGFloat(v) * size.height * 0.42)
                            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                        }
                    }
                    let phosphor = theme.ui(.waveform)
                    ctx.stroke(trace, with: .color(phosphor.opacity(0.18)), style: StrokeStyle(lineWidth: 5, lineJoin: .round))
                    ctx.stroke(trace, with: .color(phosphor), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                }
            }
            .frame(height: height)
            .background(theme.ui(.stageBackground).opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(10)
        .background(theme.ui(.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("slot.waveform")
        .accessibilityLabel(L10nKey.slotWaveform.text(in: language))
        .accessibilityValue(String(format: "%.2f", amplitude))
    }
}

// MARK: - Ribbon (no-hinge fallback)

/// Lit ribbon that replaces the hinge on non-Duo devices and on the cover.
/// Same 0…1 value as the hinge. VoiceOver sees a standard slider.
struct RibbonFallback: View {
    @Binding var value: Double
    var language: AppLanguage
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let theme = model.theme
        let hue = theme.ui(model.selectedInstrument.hueToken)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L10nKey.instrumentRibbon.text(in: language), systemImage: theme.systemImage(.ribbon))
                    .stageLabelStyle(theme)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(StageFont.readout(14))
                    .foregroundStyle(theme.ui(.primaryText))
            }
            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let thumb: CGFloat = 26
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.ui(.surfaceRaised))
                    Capsule()
                        .fill(LinearGradient(colors: [hue.opacity(0.15), hue.opacity(0.65)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: thumb + (width - thumb) * CGFloat(value))
                    Canvas { ctx, size in
                        for i in 1..<12 {
                            let x = size.width * CGFloat(i) / 12
                            let h: CGFloat = i % 3 == 0 ? 10 : 5
                            ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: size.height / 2 - h / 2)); $0.addLine(to: CGPoint(x: x, y: size.height / 2 + h / 2)) },
                                       with: .color(theme.ui(.gauge).opacity(0.35)), lineWidth: 1)
                        }
                    }
                    .allowsHitTesting(false)
                    Circle()
                        .fill(theme.ui(.primaryText))
                        .frame(width: thumb, height: thumb)
                        .shadow(color: hue.opacity(0.8), radius: 8)
                        .offset(x: (width - thumb) * CGFloat(value))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            value = Double(min(1, max(0, (drag.location.x - thumb / 2) / (width - thumb))))
                        }
                )
            }
            .frame(height: 34)
            Text(L10nKey.instrumentRibbonHint.text(in: language))
                .font(StageFont.caption)
                .foregroundStyle(theme.ui(.secondaryText))
        }
        .padding(12)
        .background(theme.ui(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityRepresentation {
            Slider(value: $value, in: 0...1) {
                Text(L10nKey.instrumentRibbon.text(in: language))
            }
            .accessibilityIdentifier("ribbon.slider")
        }
        .accessibilityIdentifier("ribbon.slider")
    }
}

// MARK: - Keys

/// One playable key. Fires `noteOn` once per touch (not on every drag
/// event), lights in the instrument hue while held, and gives VoiceOver /
/// Switch Control a default action.
struct InstrumentKey: View {
    enum Face {
        /// Bass/chord button.
        case chord
        /// Natural melody note (ivory).
        case natural
        /// Sharp melody note (ebony).
        case sharp
        /// Sequencer step.
        case step
    }

    let title: String
    var subtitle: String?
    var spokenLabel: String?
    let accessibilityID: String
    let note: UInt8
    var face: Face = .chord
    var minHeight: CGFloat = 60
    @EnvironmentObject private var model: AppModel
    @State private var isPressed = false

    var body: some View {
        let theme = model.theme
        let hue = theme.ui(model.selectedInstrument.hueToken)
        let shape = RoundedRectangle(cornerRadius: face == .chord ? 18 : 12, style: .continuous)
        VStack(spacing: 1) {
            Text(title)
                .font(StageFont.keyFace(face == .chord ? 24 : 18))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let subtitle {
                Text(subtitle)
                    .font(StageFont.caption)
                    .opacity(0.75)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(isPressed ? theme.ui(.onHue) : foreground(theme))
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .background {
            shape.fill(isPressed ? hue : fill(theme))
            shape.strokeBorder(isPressed ? hue : theme.ui(.hairline), lineWidth: 1)
        }
        .shadow(color: isPressed ? hue.opacity(0.6) : .clear, radius: 14)
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.08), value: isPressed)
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel(spokenLabel ?? title)
        .accessibilityAddTraits([.isButton, .allowsDirectInteraction])
        .accessibilityAction {
            model.noteOn(note)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                model.noteOff(note)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    model.noteOn(note)
                }
                .onEnded { _ in
                    isPressed = false
                    model.noteOff(note)
                }
        )
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: isPressed) { _, pressed in
            pressed && model.settings.hapticsEnabled
        }
    }

    private func fill(_ theme: any ThemeProviding) -> Color {
        switch face {
        case .chord: return theme.ui(.surfaceRaised)
        case .natural: return theme.ui(.gauge)
        case .sharp: return theme.ui(.stageBackground)
        case .step: return theme.ui(.surface)
        }
    }

    private func foreground(_ theme: any ThemeProviding) -> Color {
        face == .natural ? theme.ui(.onHue) : theme.ui(.primaryText)
    }
}

// MARK: - Fold sparks (AnimationSlot.foldParticle)

/// Sparks thrown off the crease while the hinge moves. Emission follows
/// hinge speed; nothing is drawn at rest or with Reduce Motion. Particles are
/// a pure function of time, so there is no per-frame state.
struct SparkField: View {
    var rate: Double
    var hue: Color
    var sparkAssetName: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let active = rate > 0 && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 45, paused: !active)) { timeline in
            Canvas { ctx, size in
                guard active else { return }
                let sprite = sparkAssetName.isEmpty || UIImage(named: sparkAssetName) == nil
                    ? nil
                    : ctx.resolve(Image(sparkAssetName).renderingMode(.template))
                let now = timeline.date.timeIntervalSinceReferenceDate
                let maxRate = 48.0
                let life = 0.9
                let newest = floor(now * maxRate)
                for k in 0..<Int(life * maxRate) {
                    let id = newest - Double(k)
                    let age = now - id / maxRate
                    guard age >= 0, age < life, Self.noise(id, 0) < rate / maxRate else { continue }
                    let t = age / life
                    let direction = Self.noise(id, 1) < 0.5 ? -1.0 : 1.0
                    let x = size.width / 2 + CGFloat((Self.noise(id, 2) - 0.5) * 0.12 + direction * t * (0.18 + 0.22 * Self.noise(id, 3))) * size.width
                    let y = size.height * CGFloat(0.12 + 0.76 * Self.noise(id, 4)) - CGFloat(t * t) * size.height * 0.12
                    let radius = CGFloat(2 + 4 * (1 - t))
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    ctx.opacity = 1 - t
                    if var sprite {
                        sprite.shading = .color(hue)
                        ctx.draw(sprite, in: rect.insetBy(dx: -radius, dy: -radius))
                    } else {
                        ctx.fill(Path(ellipseIn: rect), with: .color(hue))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func noise(_ id: Double, _ channel: Double) -> Double {
        let v = sin(id * 12.9898 + channel * 78.233) * 43_758.5453
        return v - floor(v)
    }
}

// MARK: - Small chrome

/// Section header used on instrument halves.
struct SurfaceHeader: View {
    var title: String
    var trailing: String?
    var theme: any ThemeProviding

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).stageLabelStyle(theme)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(StageFont.readout(13))
                    .foregroundStyle(theme.ui(.secondaryText))
            }
        }
    }
}

/// Label/value readout with monospaced digits.
struct Readout: View {
    var label: String
    var value: String
    var tint: Color
    var theme: any ThemeProviding
    var size: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).stageLabelStyle(theme)
            Text(value)
                .font(StageFont.readout(size))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
