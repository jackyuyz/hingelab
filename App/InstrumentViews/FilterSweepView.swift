import SwiftUI
import HingeL10n

struct FilterControlsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10nKey.instrumentFilter.text(in: model.language)).font(.headline)
            Text(String(format: "Cutoff %.0f Hz", model.currentParams.cutoffHz))
                .font(.body.monospacedDigit())
                .accessibilityIdentifier("filter.cutoff")
            Text(String(format: "Res %.2f", model.currentParams.resonance))
                .font(.body.monospacedDigit())
            AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language)
        }
        .padding()
        .onAppear {
            model.noteOn(48, velocity: 80)
        }
    }
}

struct FilterSequencerView: View {
    @EnvironmentObject private var model: AppModel
    private let steps: [UInt8] = [48, 51, 55, 58, 60, 63, 67, 70]

    var body: some View {
        VStack(spacing: 8) {
            Text("Sequencer (placeholder)").font(.caption)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, note in
                    InstrumentKey(
                        title: "\(index + 1)",
                        accessibilityID: "filter.step.\(index)",
                        note: note
                    )
                }
            }
            WaveformSlot(amplitude: model.currentParams.amplitude, language: model.language)
        }
        .padding()
    }
}
