import SwiftUI
import HingeL10n
import ThemeKit

/// Left half: the bloom (cutoff) and resonance ring, with readouts.
struct FilterControlsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let theme = model.theme
        let hue = theme.ui(.filterHue)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Readout(label: L10nKey.filterCutoff.text(in: model.language), value: Self.format(hz: model.currentParams.cutoffHz), tint: hue, theme: theme)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("filter.cutoff")
                Readout(label: L10nKey.filterResonance.text(in: model.language), value: String(format: "%.2f", model.currentParams.resonance), tint: theme.ui(.primaryText), theme: theme)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("filter.resonance")
            }
            .padding(10)
            .background(theme.ui(.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            FilterBloom(cutoffHz: model.currentParams.cutoffHz, resonance: model.currentParams.resonance, hue: hue, theme: theme)
                .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 260)

            AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language, compact: true)
        }
        .padding(14)
        .instrumentSurfaceTypeLimit()
        .onAppear {
            model.noteOn(48, velocity: 80)
        }
    }

    static func format(hz: Double) -> String {
        hz >= 1_000 ? String(format: "%.2f kHz", hz / 1_000) : String(format: "%.0f Hz", hz)
    }
}

/// Right half: eight step pads (C minor pentatonic-ish, MIDI 48…70).
struct FilterSequencerView: View {
    @EnvironmentObject private var model: AppModel
    private let steps: [UInt8] = [48, 51, 55, 58, 60, 63, 67, 70]

    var body: some View {
        let theme = model.theme
        VStack(alignment: .leading, spacing: 10) {
            SurfaceHeader(title: L10nKey.filterSteps.text(in: model.language), trailing: nil, theme: theme)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, note in
                    InstrumentKey(
                        title: NoteName.name(midi: Int(note)),
                        subtitle: "\(index + 1)",
                        spokenLabel: L10nKey.filterStepA11y.text(in: model.language, "\(index + 1)") + ", " + NoteName.name(midi: Int(note)),
                        accessibilityID: "filter.step.\(index)",
                        note: note,
                        face: .step,
                        minHeight: 72
                    )
                }
            }
            Spacer(minLength: 0)
            WaveformSlot(amplitude: model.currentParams.amplitude, language: model.language, height: 56)
        }
        .padding(14)
        .instrumentSurfaceTypeLimit()
    }
}
