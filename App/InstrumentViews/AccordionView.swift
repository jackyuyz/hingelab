import SwiftUI
import HingeL10n
import Instruments

struct AccordionLeftView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            PlaceholderSlot(
                title: L10nKey.slotBellows.text(in: model.language),
                systemImage: "rectangle.split.2x1",
                accessibilityID: "slot.bellows"
            )
            Text(L10nKey.instrumentLeft.text(in: model.language))
                .font(.caption)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(AccordionLayout.leftChords.enumerated()), id: \.offset) { _, chord in
                    InstrumentKey(
                        title: chord.name,
                    accessibilityID: "accordion.chord.\(chord.name)",
                        note: chord.root
                    )
                }
            }
            if let accordion = model.instrumentHint {
                Text(accordion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }
}

struct AccordionRightView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language)
            WaveformSlot(amplitude: model.currentParams.amplitude, language: model.language)
            Text(L10nKey.instrumentRight.text(in: model.language))
                .font(.caption)
            ForEach(0..<AccordionLayout.melodyRows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<AccordionLayout.melodyColumns, id: \.self) { col in
                        let note = AccordionLayout.melodyStart + UInt8(row * AccordionLayout.melodyColumns + col)
                        InstrumentKey(
                            title: "\(note)",
                            accessibilityID: "accordion.key.\(note)",
                            note: note
                        )
                    }
                }
            }
        }
        .padding(8)
    }
}

extension AppModel {
    var instrumentHint: String? {
        guard selectedInstrument == .accordion else { return nil }
        if currentParams.amplitude == 0 {
            return L10nKey.instrumentBellowsHint.text(in: language)
        }
        return nil
    }
}

struct InstrumentKey: View {
    let title: String
    let accessibilityID: String
    let note: UInt8
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier(accessibilityID)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.allowsDirectInteraction)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in model.noteOn(note) }
                    .onEnded { _ in model.noteOff(note) }
            )
    }
}
