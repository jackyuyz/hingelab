import SwiftUI
import HingeL10n
import Instruments
import ThemeKit

// Vector instrument art. Everything is drawn from theme tokens and runtime
// size so it follows the hinge and fits any panel; no Duo pixel constants.

// MARK: - Accordion bellows (slot.bellows, AnimationSlot.bellowsPulse)

struct BellowsVisualizer: View {
    /// Calibrated hinge openness 0…1.
    var openness: Double
    /// Bellows pressure 0…1 (from hinge speed).
    var pressure: Double
    var hue: Color
    var theme: any ThemeProviding

    var body: some View {
        Canvas { ctx, size in
            let edges = InstrumentMotion.bellowsPleatEdges(openness: openness, pleats: 10)
            let board = max(10, size.width * 0.04)
            let track = size.width - board * 2
            let top: CGFloat = 6
            let bottom = size.height - 6
            let depth = size.height * CGFloat(0.10 + 0.10 * (1 - openness))
            func x(_ e: Double) -> CGFloat { board + CGFloat(e) * track }
            let left = x(edges.first ?? 0)
            let right = x(edges.last ?? 1)

            if pressure > 0 {
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 22))
                    layer.fill(Path(CGRect(x: left, y: top + depth, width: right - left, height: bottom - top - depth * 2)),
                               with: .color(hue.opacity(0.25 + 0.55 * pressure)))
                }
            }
            let ridge = theme.ui(.gauge)
            for i in 0..<(edges.count - 1) {
                let x0 = x(edges[i])
                let x1 = x(edges[i + 1])
                let xm = (x0 + x1) / 2
                var lit = Path()
                lit.move(to: CGPoint(x: x0, y: top))
                lit.addLine(to: CGPoint(x: xm, y: top + depth))
                lit.addLine(to: CGPoint(x: xm, y: bottom - depth))
                lit.addLine(to: CGPoint(x: x0, y: bottom))
                lit.closeSubpath()
                var shade = Path()
                shade.move(to: CGPoint(x: xm, y: top + depth))
                shade.addLine(to: CGPoint(x: x1, y: top))
                shade.addLine(to: CGPoint(x: x1, y: bottom))
                shade.addLine(to: CGPoint(x: xm, y: bottom - depth))
                shade.closeSubpath()
                ctx.fill(lit, with: .color(hue.opacity(0.75 + 0.25 * pressure)))
                ctx.fill(shade, with: .color(hue.opacity(0.42)))
                // Brass corner guards on each ridge.
                let corner = min(10, (x1 - x0) * 0.6)
                ctx.fill(Path { p in
                    p.move(to: CGPoint(x: x0 - corner / 2, y: top))
                    p.addLine(to: CGPoint(x: x0 + corner / 2, y: top))
                    p.addLine(to: CGPoint(x: x0, y: top + corner))
                    p.closeSubpath()
                    p.move(to: CGPoint(x: x0 - corner / 2, y: bottom))
                    p.addLine(to: CGPoint(x: x0 + corner / 2, y: bottom))
                    p.addLine(to: CGPoint(x: x0, y: bottom - corner))
                    p.closeSubpath()
                }, with: .color(ridge.opacity(0.9)))
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: x0, y: top))
                    p.addLine(to: CGPoint(x: x0, y: bottom))
                }, with: .color(ridge.opacity(0.55)), lineWidth: 1)
            }
            let boardColor = theme.ui(.surfaceRaised)
            let boardStroke = theme.ui(.hairline)
            for bx in [left - board, right] {
                let rect = CGRect(x: bx, y: 0, width: board, height: size.height)
                let path = Path(roundedRect: rect, cornerRadius: 4)
                ctx.fill(path, with: .color(boardColor))
                ctx.stroke(path, with: .color(boardStroke), lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Guitar fretboard + strum pad (slot.fretboard, AnimationSlot.stringVibrate)

/// Six strings over a fretboard; the nut sits on the crease side so the hinge
/// line reads as the guitar nut. Drag across strings to strum. Strings bow
/// with the hinge bend and vibrate after each pluck.
struct FretboardStrumPad: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plucked: [Int: Date] = [:]
    @State private var activeString: Int?
    @State private var sounding: Set<UInt8> = []
    /// Nut on the leading edge (true when this pane sits right of the crease).
    var nutLeading = true

    private let notes = Array(GuitarLayout.defaultChords.prefix(GuitarLayout.stringCount))
    private let gauges: [CGFloat] = [2.8, 2.3, 1.9, 1.5, 1.15, 0.9]

    var body: some View {
        let theme = model.theme
        let hue = theme.ui(.guitarHue)
        let bend = InstrumentMotion.bendOffset(
            semitones: model.currentParams.pitchBendSemitones,
            range: model.settings.pitchBendRangeSemitones
        )
        GeometryReader { proxy in
            let rowHeight = proxy.size.height / CGFloat(GuitarLayout.stringCount)
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [theme.ui(.surfaceRaised), theme.ui(.surface)], startPoint: .top, endPoint: .bottom))
                Canvas { ctx, canvasSize in
                    drawFrets(&ctx, size: canvasSize, theme: theme)
                }
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || !isRinging)) { timeline in
                    Canvas { ctx, canvasSize in
                        drawStrings(&ctx, size: canvasSize, now: timeline.date, bend: bend, hue: hue, theme: theme)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(0..<GuitarLayout.stringCount, id: \.self) { index in
                        Color.clear
                            .contentShape(Rectangle())
                            .accessibilityElement()
                            .accessibilityIdentifier("guitar.string.\(index)")
                            .accessibilityLabel(L10nKey.guitarStringA11y.text(in: model.language, NoteName.name(midi: Int(notes[index]))))
                            .accessibilityAddTraits([.isButton, .allowsDirectInteraction])
                            .accessibilityAction { pluckFromAccessibility(index) }
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let row = min(GuitarLayout.stringCount - 1, max(0, Int(drag.location.y / rowHeight)))
                        if row != activeString {
                            activeString = row
                            pluck(row)
                        }
                    }
                    .onEnded { _ in
                        activeString = nil
                        releaseAll()
                    }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("slot.fretboard")
        .accessibilityLabel(L10nKey.slotFretboard.text(in: model.language))
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: activeString) { _, row in
            row != nil && model.settings.hapticsEnabled
        }
    }

    private var isRinging: Bool {
        let now = Date()
        return plucked.values.contains { now.timeIntervalSince($0) < 1 } || model.currentParams.pitchBendSemitones != 0
    }

    private func pluck(_ index: Int) {
        let note = notes[index]
        plucked[index] = Date()
        sounding.insert(note)
        model.noteOn(note)
    }

    private func releaseAll() {
        for note in sounding { model.noteOff(note) }
        sounding.removeAll()
    }

    private func pluckFromAccessibility(_ index: Int) {
        pluck(index)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            releaseAll()
        }
    }

    private func nutX(_ width: CGFloat) -> CGFloat { nutLeading ? 10 : width - 10 }

    private func fretX(_ k: Int, width: CGFloat) -> CGFloat {
        // Equal-tempered spacing, 12 frets across the pad.
        let usable = width - 20
        let f = (1 - pow(2, -Double(k) / 12)) / 0.5
        let offset = usable * CGFloat(f) * 0.98
        return nutLeading ? 10 + offset : width - 10 - offset
    }

    private func drawFrets(_ ctx: inout GraphicsContext, size: CGSize, theme: any ThemeProviding) {
        let ivory = theme.ui(.gauge)
        let nut = nutX(size.width)
        ctx.fill(Path(CGRect(x: nut - 3, y: 6, width: 6, height: size.height - 12)), with: .color(ivory.opacity(0.9)))
        for k in 1...12 {
            let x = fretX(k, width: size.width)
            ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 8)); $0.addLine(to: CGPoint(x: x, y: size.height - 8)) },
                       with: .color(ivory.opacity(0.28)), lineWidth: 1.5)
        }
        for k in [3, 5, 7, 9, 12] {
            let x = (fretX(k - 1, width: size.width) + fretX(k, width: size.width)) / 2
            let ys: [CGFloat] = k == 12 ? [size.height * 0.33, size.height * 0.67] : [size.height / 2]
            for y in ys {
                ctx.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)), with: .color(ivory.opacity(0.22)))
            }
        }
    }

    private func drawStrings(_ ctx: inout GraphicsContext, size: CGSize, now: Date, bend: Double, hue: Color, theme: any ThemeProviding) {
        let rowHeight = size.height / CGFloat(GuitarLayout.stringCount)
        let t = now.timeIntervalSinceReferenceDate
        for index in 0..<GuitarLayout.stringCount {
            let y = rowHeight * (CGFloat(index) + 0.5)
            let since = plucked[index].map { now.timeIntervalSince($0) } ?? 10
            let ring = InstrumentMotion.stringVibration(secondsSincePluck: since, velocity: 1, reduceMotion: reduceMotion)
            let wobble = CGFloat(ring * sin(t * 2 * .pi * (17 + Double(index) * 3))) * rowHeight * 0.16
            let bow = CGFloat(bend) * rowHeight * 0.32
            var string = Path()
            string.move(to: CGPoint(x: 6, y: y))
            string.addQuadCurve(to: CGPoint(x: size.width - 6, y: y), control: CGPoint(x: size.width / 2, y: y - bow * 2 + wobble * 2))
            let base = index < 3 ? theme.ui(.gauge) : theme.ui(.primaryText)
            if ring > 0.02 {
                ctx.stroke(string, with: .color(hue.opacity(0.45 * ring)), lineWidth: gauges[index] + 6)
            }
            ctx.stroke(string, with: .color(ring > 0.02 ? hue : base.opacity(0.85)), lineWidth: gauges[index])
        }
    }
}

// MARK: - Theremin (slot.antenna, AnimationSlot.thereminGlow)

struct ThereminAntenna: View {
    var frequencyHz: Double?
    var amplitude: Double
    var hue: Color
    var theme: any ThemeProviding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let glow = InstrumentMotion.thereminGlow(frequencyHz: frequencyHz, amplitude: amplitude)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || glow.intensity <= 0.01)) { timeline in
            Canvas { ctx, size in
                let x = size.width * 0.5
                let top = size.height * 0.06
                let bottom = size.height * 0.94
                let y = bottom - CGFloat(glow.position) * (bottom - top)
                let ivory = theme.ui(.gauge)

                // Octave marks C3…C6 on the same log scale as the glow.
                for (i, name) in ["C3", "C4", "C5", "C6"].enumerated() {
                    let my = bottom - CGFloat(Double(i) / 3) * (bottom - top)
                    ctx.stroke(Path { $0.move(to: CGPoint(x: x + 12, y: my)); $0.addLine(to: CGPoint(x: x + 22, y: my)) },
                               with: .color(ivory.opacity(0.5)), lineWidth: 1)
                    ctx.draw(Text(name).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(ivory.opacity(0.6)),
                             at: CGPoint(x: x + 36, y: my))
                }
                if glow.intensity > 0.01 {
                    let pulse = reduceMotion ? 0 : (sin(timeline.date.timeIntervalSinceReferenceDate * 5.3 * 2 * .pi) + 1) / 2
                    for ring in 1...3 {
                        let r = CGFloat(18 + ring * 16) + CGFloat(pulse) * 4
                        ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.55, width: r * 2, height: r * 1.1)),
                                   with: .color(hue.opacity(glow.intensity * (0.5 - Double(ring) * 0.12))), lineWidth: 1.5)
                    }
                    let r = CGFloat(26 + 36 * glow.intensity)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(colors: [hue.opacity(0.9 * glow.intensity), hue.opacity(0)]),
                                                   center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
                }
                let rod = Path(roundedRect: CGRect(x: x - 3, y: top - 8, width: 6, height: bottom - top + 16), cornerRadius: 3)
                ctx.fill(rod, with: .linearGradient(Gradient(colors: [ivory, theme.ui(.secondaryText), ivory]),
                                                     startPoint: CGPoint(x: x - 3, y: 0), endPoint: CGPoint(x: x + 3, y: 0)))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 7, y: top - 14, width: 14, height: 14)), with: .color(ivory))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Volume plate for the theremin's other hand: touch height sets volume.
struct ThereminVolumePlate: View {
    @Binding var volume: Double
    var hue: Color
    var theme: any ThemeProviding
    var label: String

    var body: some View {
        GeometryReader { proxy in
            let h = max(proxy.size.height, 1)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.ui(.surface))
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [hue.opacity(0.9), hue.opacity(0.25)], startPoint: .bottom, endPoint: .top))
                    .frame(height: h * CGFloat(volume))
                Canvas { ctx, size in
                    for i in 1..<10 {
                        let y = size.height * CGFloat(i) / 10
                        ctx.stroke(Path { $0.move(to: CGPoint(x: 18, y: y)); $0.addLine(to: CGPoint(x: size.width - 18, y: y)) },
                                   with: .color(theme.ui(.gauge).opacity(i == 5 ? 0.35 : 0.15)), lineWidth: 1)
                    }
                }
                .allowsHitTesting(false)
                Text("\(Int((volume * 100).rounded()))")
                    .font(StageFont.readout(28))
                    .foregroundStyle(theme.ui(.primaryText))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(theme.ui(.hairline)))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        volume = Double(min(1, max(0, 1 - drag.location.y / h)))
                    }
            )
        }
        .accessibilityRepresentation {
            Slider(value: $volume, in: 0...1) { Text(label) }
                .accessibilityIdentifier("theremin.volume")
        }
        .accessibilityIdentifier("theremin.volume")
    }
}

// MARK: - Filter bloom (AnimationSlot.filterBloom)

struct FilterBloom: View {
    var cutoffHz: Double
    var resonance: Double
    var hue: Color
    var theme: any ThemeProviding

    var body: some View {
        Canvas { ctx, size in
            let bloom = InstrumentMotion.bloom(cutoffHz: cutoffHz)
            let axisY = size.height - 16
            let center = CGPoint(x: size.width / 2, y: (axisY - 8) / 2)
            let maxR = min(size.width, axisY - 8) / 2
            let r = maxR * CGFloat(0.18 + 0.82 * bloom)
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                     with: .radialGradient(Gradient(colors: [hue.opacity(0.85), hue.opacity(0.25), hue.opacity(0)]),
                                           center: center, startRadius: 0, endRadius: r))
            let ringWidth = CGFloat(1 + 6 * resonance)
            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                       with: .color(hue.opacity(0.35 + 0.65 * resonance)), lineWidth: ringWidth)

            // Log frequency axis 20 Hz…20 kHz with the cutoff marker.
            let ivory = theme.ui(.gauge)
            ctx.stroke(Path { $0.move(to: CGPoint(x: 8, y: axisY)); $0.addLine(to: CGPoint(x: size.width - 8, y: axisY)) },
                       with: .color(theme.ui(.hairline)), lineWidth: 1)
            for (label, hz) in [("20", 20.0), ("200", 200.0), ("2k", 2_000.0), ("20k", 20_000.0)] {
                let x = 8 + (size.width - 16) * CGFloat(InstrumentMotion.bloom(cutoffHz: hz))
                ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: axisY - 4)); $0.addLine(to: CGPoint(x: x, y: axisY + 4)) },
                           with: .color(ivory.opacity(0.5)), lineWidth: 1)
                ctx.draw(Text(label).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(ivory.opacity(0.55)),
                         at: CGPoint(x: x, y: axisY + 11))
            }
            let mx = 8 + (size.width - 16) * CGFloat(bloom)
            ctx.fill(Path(ellipseIn: CGRect(x: mx - 5, y: axisY - 5, width: 10, height: 10)), with: .color(hue))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Picker glyphs

/// Small drawing of each instrument for the picker cards and paywall hero.
struct InstrumentGlyph: View {
    var id: InstrumentID
    var hue: Color
    var theme: any ThemeProviding

    var body: some View {
        Canvas { ctx, size in
            let ivory = theme.ui(.gauge)
            switch id {
            case .accordion:
                let pleats = 7
                let w = size.width * 0.8
                let x0 = (size.width - w) / 2
                for i in 0..<pleats {
                    let a = x0 + w * CGFloat(i) / CGFloat(pleats)
                    let b = x0 + w * CGFloat(i + 1) / CGFloat(pleats)
                    let m = (a + b) / 2
                    let d = size.height * 0.16
                    ctx.fill(Path { p in
                        p.move(to: CGPoint(x: a, y: 4)); p.addLine(to: CGPoint(x: m, y: 4 + d))
                        p.addLine(to: CGPoint(x: m, y: size.height - 4 - d)); p.addLine(to: CGPoint(x: a, y: size.height - 4)); p.closeSubpath()
                    }, with: .color(hue))
                    ctx.fill(Path { p in
                        p.move(to: CGPoint(x: m, y: 4 + d)); p.addLine(to: CGPoint(x: b, y: 4))
                        p.addLine(to: CGPoint(x: b, y: size.height - 4)); p.addLine(to: CGPoint(x: m, y: size.height - 4 - d)); p.closeSubpath()
                    }, with: .color(hue.opacity(0.5)))
                    ctx.stroke(Path { $0.move(to: CGPoint(x: a, y: 4)); $0.addLine(to: CGPoint(x: a, y: size.height - 4)) },
                               with: .color(ivory.opacity(0.7)), lineWidth: 1)
                }
            case .pitchBendGuitar:
                for i in 0..<6 {
                    let y = size.height * (0.15 + 0.14 * CGFloat(i))
                    let bow: CGFloat = i == 2 ? size.height * 0.16 : 0
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: 4, y: y))
                        p.addQuadCurve(to: CGPoint(x: size.width - 4, y: y), control: CGPoint(x: size.width * 0.55, y: y - bow * 2))
                    }, with: .color(i == 2 ? hue : ivory.opacity(0.7)), lineWidth: i == 2 ? 2.5 : CGFloat(2.2 - Double(i) * 0.25))
                }
                ctx.fill(Path(CGRect(x: 6, y: size.height * 0.08, width: 4, height: size.height * 0.84)), with: .color(ivory))
            case .filterSweep:
                // Low-pass response with a resonant bump.
                let path = Path { p in
                    for i in 0...48 {
                        let f = Double(i) / 48
                        let bump = exp(-pow((f - 0.55) / 0.06, 2)) * 0.35
                        let fall = f < 0.55 ? 0 : pow((f - 0.55) / 0.45, 1.4) * 0.9
                        let v = 0.55 - bump + fall
                        let pt = CGPoint(x: 4 + (size.width - 8) * CGFloat(f), y: size.height * CGFloat(min(0.95, max(0.08, v))))
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                ctx.stroke(path, with: .color(hue.opacity(0.25)), lineWidth: 8)
                ctx.stroke(path, with: .color(hue), lineWidth: 2.5)
            case .theremin:
                let x = size.width * 0.38
                ctx.fill(Path(roundedRect: CGRect(x: x - 2.5, y: 4, width: 5, height: size.height - 8), cornerRadius: 2.5), with: .color(ivory))
                let c = CGPoint(x: x, y: size.height * 0.42)
                for ring in 1...3 {
                    let r = CGFloat(ring) * size.height * 0.13
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.6, width: r * 2, height: r * 1.2)),
                               with: .color(hue.opacity(0.9 - Double(ring) * 0.22)), lineWidth: 2)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Brand mark

/// The app icon's mark drawn live: hinge barrel as note head, panels as stem
/// and flag, bellows between them in the four instrument hues.
struct HingeLabMark: View {
    var theme: any ThemeProviding
    var openDegrees: Double = 54

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 1024
            let pivot = CGPoint(x: size.width / 2 - 98 * s, y: size.height / 2 + 210 * s)
            func at(_ deg: Double, _ r: Double) -> CGPoint {
                let a = (deg - 90) * .pi / 180
                return CGPoint(x: pivot.x + CGFloat(r * cos(a)) * s, y: pivot.y + CGFloat(r * sin(a)) * s)
            }
            let hues: [ColorToken] = [.accordionHue, .guitarHue, .filterHue, .thereminHue]
            let pleats = 8
            let step = openDegrees / Double(pleats)
            for i in 0..<pleats {
                let a0 = Double(i) * step
                let am = a0 + step / 2
                let a1 = a0 + step
                let hue = theme.ui(hues[i / 2])
                ctx.fill(Path { p in
                    p.move(to: at(a0, 170)); p.addLine(to: at(a0, 492)); p.addLine(to: at(am, 440)); p.addLine(to: at(am, 146)); p.closeSubpath()
                }, with: .color(hue))
                ctx.fill(Path { p in
                    p.move(to: at(am, 146)); p.addLine(to: at(am, 440)); p.addLine(to: at(a1, 492)); p.addLine(to: at(a1, 170)); p.closeSubpath()
                }, with: .color(hue.opacity(0.62)))
            }
            let ivory = theme.ui(.gauge)
            for deg in [openDegrees, 0] {
                var panel = ctx
                panel.translateBy(x: pivot.x, y: pivot.y)
                panel.rotate(by: .degrees(deg))
                panel.fill(Path(roundedRect: CGRect(x: -40 * s, y: -520 * s, width: 80 * s, height: 520 * s), cornerRadius: 24 * s), with: .color(ivory))
            }
            var head = ctx
            head.translateBy(x: pivot.x - 70 * s, y: pivot.y + 26 * s)
            head.rotate(by: .degrees(-22))
            head.fill(Path(ellipseIn: CGRect(x: -134 * s, y: -100 * s, width: 268 * s, height: 200 * s)), with: .color(ivory))
        }
        .accessibilityHidden(true)
    }
}
