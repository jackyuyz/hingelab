import SwiftUI
import HingeL10n
import SettingsKit
import ThemeKit

/// Left half: the volume plate for the other hand.
struct ThereminVolumeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var volume = 0.6

    var body: some View {
        let theme = model.theme
        let hue = theme.ui(.thereminHue)
        VStack(alignment: .leading, spacing: 10) {
            SurfaceHeader(title: L10nKey.instrumentVolume.text(in: model.language), trailing: nil, theme: theme)
            ThereminVolumePlate(
                volume: $volume,
                hue: hue,
                theme: theme,
                label: L10nKey.instrumentVolume.text(in: model.language)
            )
            .frame(minHeight: 200)
            WaveformSlot(amplitude: model.currentParams.amplitude, language: model.language, height: 40)
        }
        .padding(14)
        .instrumentSurfaceTypeLimit()
        .onChange(of: volume) { _, value in
            model.setThereminVolume(value)
        }
        .onAppear { model.setThereminVolume(volume) }
    }
}

/// Right half: antenna with the pitch glow, Hz and nearest-note readout.
struct ThereminPitchView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let theme = model.theme
        let hue = theme.ui(.thereminHue)
        let hz = model.currentParams.frequencyHz ?? 0
        let nearest = NoteName.nearest(hz: hz, a4: model.settings.a4Hz)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Readout(label: L10nKey.instrumentPitch.text(in: model.language), value: String(format: "%.1f Hz", hz), tint: hue, theme: theme)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("theremin.frequency")
                    Text(hz > 0 ? String(format: "%@ %+.0f¢", NoteName.name(midi: nearest.midi), nearest.cents) : "—")
                        .font(StageFont.readout(15))
                        .foregroundStyle(theme.ui(.secondaryText))
                }
                .padding(10)
                .background(theme.ui(.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language, compact: true)
            }
            ThereminAntenna(frequencyHz: model.currentParams.frequencyHz, amplitude: model.currentParams.amplitude, hue: hue, theme: theme)
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(theme.ui(.surface).opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityElement()
                .accessibilityIdentifier("slot.antenna")
                .accessibilityLabel(L10nKey.slotAntenna.text(in: model.language))
                .accessibilityValue(hz > 0 ? NoteName.name(midi: nearest.midi) : "")
        }
        .padding(14)
        .instrumentSurfaceTypeLimit()
        // Haptic tick when the quantized note changes (spec: optional, off
        // with Reduce Motion or when haptics are disabled).
        .sensoryFeedback(.selection, trigger: nearest.midi) { _, _ in
            !reduceMotion && model.settings.hapticsEnabled && model.settings.scale != .off && model.currentParams.amplitude > 0.05
        }
    }
}
