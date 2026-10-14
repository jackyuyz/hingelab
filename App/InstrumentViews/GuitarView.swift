import SwiftUI
import HingeL10n
import Instruments

struct GuitarChordGrid: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            Text(L10nKey.instrumentLeft.text(in: model.language)).font(.caption)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(GuitarLayout.defaultChords.enumerated()), id: \.offset) { index, note in
                    InstrumentKey(
                        title: "Chord \(index + 1)",
                        accessibilityID: "guitar.chord.\(index)",
                        note: note
                    )
                }
            }
        }
        .padding(8)
    }
}

struct GuitarStrumPad: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            PlaceholderSlot(
                title: L10nKey.slotFretboard.text(in: model.language),
                systemImage: "guitars",
                accessibilityID: "slot.fretboard"
            )
            AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language)
            Text(String(format: "%+.2f st", model.currentParams.pitchBendSemitones))
                .font(.title3.monospacedDigit())
                .accessibilityIdentifier("guitar.bend")
            ForEach(0..<GuitarLayout.stringCount, id: \.self) { string in
                let note = GuitarLayout.defaultChords[min(string, GuitarLayout.defaultChords.count - 1)]
                Rectangle()
                    .fill(.secondary.opacity(0.4))
                    .frame(height: 28)
                    .overlay(Text("String \(string + 1)").font(.caption))
                    .accessibilityIdentifier("guitar.string.\(string)")
                    .accessibilityAddTraits(.allowsDirectInteraction)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in model.noteOn(note) }
                            .onEnded { _ in model.noteOff(note) }
                    )
            }
        }
        .padding(8)
    }
}
