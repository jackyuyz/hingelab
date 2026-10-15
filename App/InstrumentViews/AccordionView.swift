import SwiftUI
import HingeL10n
import Instruments
import ThemeKit

/// Left half: bellows on top, Stradella-style chord buttons below.
struct AccordionLeftView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let theme = model.theme
        let hue = theme.ui(.accordionHue)
        VStack(alignment: .leading, spacing: 10) {
            SurfaceHeader(title: L10nKey.slotBellows.text(in: model.language), trailing: nil, theme: theme)
            BellowsVisualizer(
                openness: model.lastSample?.smoothedValue01 ?? 0.5,
                pressure: InstrumentMotion.bellowsPressure(velocityDegPerSec: model.lastSample?.velocityDegPerSec ?? 0),
                hue: hue,
                theme: theme
            )
            .frame(height: 112)
            .accessibilityElement()
            .accessibilityIdentifier("slot.bellows")
            .accessibilityLabel(L10nKey.slotBellows.text(in: model.language))
            .accessibilityValue(String(format: "%.0f%%", (model.currentParams.amplitude * 100).rounded()))

            BellowsHint()

            SurfaceHeader(title: L10nKey.instrumentChords.text(in: model.language), trailing: nil, theme: theme)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(AccordionLayout.leftChords.enumerated()), id: \.offset) { _, chord in
                    let label = ChordLabel(symbol: chord.name)
                    InstrumentKey(
                        title: label.symbol,
                        subtitle: label.qualityName(in: model.language),
                        spokenLabel: label.accessibilityLabel(in: model.language),
                        accessibilityID: "accordion.chord.\(chord.name)",
                        note: chord.root,
                        face: .chord
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .instrumentSurfaceTypeLimit()
    }
}

/// Right half: gauge + scope, then 2×6 melody buttons from C4 (ivory
/// naturals, ebony sharps).
struct AccordionRightView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let theme = model.theme
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language, compact: true)
                WaveformSlot(amplitude: model.currentParams.amplitude, language: model.language, height: 38)
            }
            SurfaceHeader(title: L10nKey.instrumentMelody.text(in: model.language), trailing: nil, theme: theme)
            VStack(spacing: 8) {
                ForEach(0..<AccordionLayout.melodyRows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<AccordionLayout.melodyColumns, id: \.self) { col in
                            let note = AccordionLayout.melodyStart + UInt8(row * AccordionLayout.melodyColumns + col)
                            let name = NoteName.name(midi: Int(note))
                            InstrumentKey(
                                title: NoteName.letter(midi: Int(note)),
                                subtitle: name,
                                spokenLabel: name,
                                accessibilityID: "accordion.key.\(note)",
                                note: note,
                                face: name.contains("♯") ? .sharp : .natural,
                                minHeight: 64
                            )
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .instrumentSurfaceTypeLimit()
    }
}

/// "Flex the hinge" hint after 3 s of keys without bellows motion.
private struct BellowsHint: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            if model.showsBellowsHint {
                Label(L10nKey.instrumentBellowsHint.text(in: model.language), systemImage: "arrow.left.and.right")
                    .font(StageFont.label)
                    .foregroundStyle(model.theme.ui(.accordionHue))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(model.theme.ui(.accordionHue).opacity(0.14), in: Capsule())
                    .accessibilityIdentifier("instrument.bellowsHint")
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.showsBellowsHint)
    }
}

extension AppModel {
    /// Kept for callers of the foundation API.
    var instrumentHint: String? {
        showsBellowsHint ? L10nKey.instrumentBellowsHint.text(in: language) : nil
    }
}
