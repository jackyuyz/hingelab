import SwiftUI
import HingeL10n
import ThemeKit

/// Clearly named placeholder slots. Claude Design replaces the internals,
/// not the identifiers.
struct PlaceholderSlot: View {
    let title: String
    var systemImage: String = "square.dashed"
    var accessibilityID: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel(title)
    }
}

struct AngleGaugeSlot: View {
    var angle: Double?
    var language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10nKey.slotAngleGauge.text(in: language))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(angle.map { String(format: "%.1f°", $0) } ?? "—")
                .font(.title3.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("slot.angleGauge")
    }
}

struct WaveformSlot: View {
    var amplitude: Double
    var language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10nKey.slotWaveform.text(in: language))
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                Capsule()
                    .fill(.primary.opacity(0.35))
                    .frame(width: max(4, proxy.size.width * amplitude), height: 8)
            }
            .frame(height: 8)
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("slot.waveform")
        .accessibilityValue(String(format: "%.2f", amplitude))
    }
}

struct RibbonFallback: View {
    @Binding var value: Double
    var language: AppLanguage

    var body: some View {
        VStack {
            Text(L10nKey.instrumentRibbon.text(in: language))
                .font(.caption)
            Slider(value: $value, in: 0...1)
                .accessibilityIdentifier("ribbon.slider")
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
