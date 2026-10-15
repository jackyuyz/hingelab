import SwiftUI
import HingeL10n
import Instruments
import ThemeKit

/// Left half: eight chord roots.
struct GuitarChordGrid: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let theme = model.theme
        VStack(alignment: .leading, spacing: 10) {
            SurfaceHeader(title: L10nKey.instrumentChords.text(in: model.language), trailing: nil, theme: theme)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(GuitarLayout.defaultChords.enumerated()), id: \.offset) { index, note in
                    let name = NoteName.name(midi: Int(note))
                    InstrumentKey(
                        title: NoteName.letter(midi: Int(note)),
                        subtitle: name,
                        spokenLabel: name,
                        accessibilityID: "guitar.chord.\(index)",
                        note: note,
                        face: .chord
                    )
                }
            }
            Spacer(minLength: 0)
            WaveformSlot(amplitude: model.currentParams.amplitude, language: model.language, height: 40)
        }
        .padding(14)
        .instrumentSurfaceTypeLimit()
    }
}

/// Right half: bend readout + gauge, then the fretboard strum pad.
struct GuitarStrumPad: View {
    @EnvironmentObject private var model: AppModel
    var nutLeading = true

    var body: some View {
        let theme = model.theme
        let hue = theme.ui(.guitarHue)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Readout(
                    label: L10nKey.guitarBend.text(in: model.language),
                    value: String(format: "%+.2f st", model.currentParams.pitchBendSemitones),
                    tint: hue,
                    theme: theme,
                    size: 26
                )
                .padding(10)
                .background(theme.ui(.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("guitar.bend")
                AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language, compact: true)
            }
            SurfaceHeader(title: L10nKey.guitarStrings.text(in: model.language), trailing: nil, theme: theme)
            FretboardStrumPad(nutLeading: nutLeading)
                .frame(minHeight: 6 * 44)
        }
        .padding(14)
        .instrumentSurfaceTypeLimit()
    }
}
