import SwiftUI
import HingeL10n

struct ThereminVolumeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var volume = 0.6

    var body: some View {
        VStack(spacing: 12) {
            Text(L10nKey.instrumentLeft.text(in: model.language)).font(.caption)
            Text("Volume")
            Slider(value: $volume, in: 0...1)
                .accessibilityIdentifier("theremin.volume")
                .onChange(of: volume) { _, value in
                    model.setThereminVolume(value)
                }
            WaveformSlot(amplitude: model.currentParams.amplitude, language: model.language)
        }
        .padding()
        .onAppear { model.setThereminVolume(volume) }
    }
}

struct ThereminPitchView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            PlaceholderSlot(
                title: L10nKey.slotAntenna.text(in: model.language),
                systemImage: "waveform.path",
                accessibilityID: "slot.antenna"
            )
            AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language)
            Text(String(format: "%.1f Hz", model.currentParams.frequencyHz ?? 0))
                .font(.title3.monospacedDigit())
                .accessibilityIdentifier("theremin.frequency")
        }
        .padding()
    }
}
