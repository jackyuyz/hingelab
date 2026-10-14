import SwiftUI
import FoldKit
import HingeL10n
import Instruments

struct InstrumentPlayView: View {
    let id: InstrumentID
    @EnvironmentObject private var model: AppModel
    @State private var crease: CreaseRegion?

    var body: some View {
        ZStack {
            playSurface
            if let overlay = model.audioOverlay {
                audioOverlay(overlay)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { playToolbar }
        .onAppear {
            model.select(id)
        }
        .modifier(ReservedRegionProbe(posture: model.foldState.posture, crease: $crease))
        .safeAreaInset(edge: .bottom) {
            if showsRibbon {
                RibbonFallback(
                    value: Binding(
                        get: { model.ribbon.value01 },
                        set: { model.ingestRibbon($0) }
                    ),
                    language: model.language
                )
                .padding(.horizontal)
            }
        }
    }

    private var showsRibbon: Bool {
        model.foldState.posture == .noHinge || model.foldState.posture == .closed
    }

    @ViewBuilder
    private var playSurface: some View {
        let left = { AnyView(leftHalf) }
        let right = { AnyView(rightHalf) }
        switch model.foldState.posture {
        case .partiallyOpen:
            DuoSplitStack(
                horizontal: model.settings.splitAxesHorizontal,
                crease: crease,
                leftHanded: model.settings.leftHanded,
                left: left,
                right: right
            )
        case .closed:
            compactPlayer
        case .fullyOpen:
            VStack {
                Text(L10nKey.instrumentFoldHint.text(in: model.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("instrument.foldHint")
                fullKeyboard
            }
        case .noHinge, .unknown:
            fullKeyboard
        }
    }

    private var fullKeyboard: some View {
        HStack(spacing: 8) {
            leftHalf
            rightHalf
        }
        .padding()
    }

    @ViewBuilder
    private var leftHalf: some View {
        switch id {
        case .accordion: AccordionLeftView()
        case .pitchBendGuitar: GuitarChordGrid()
        case .filterSweep: FilterControlsView()
        case .theremin: ThereminVolumeView()
        }
    }

    @ViewBuilder
    private var rightHalf: some View {
        switch id {
        case .accordion: AccordionRightView()
        case .pitchBendGuitar: GuitarStrumPad()
        case .filterSweep: FilterSequencerView()
        case .theremin: ThereminPitchView()
        }
    }

    private var compactPlayer: some View {
        VStack(spacing: 12) {
            Text(L10nKey.instrumentCoverTitle.text(in: model.language))
            AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language)
            WaveformSlot(amplitude: model.currentParams.amplitude, language: model.language)
            Button(L10nKey.looperTitle.text(in: model.language)) { model.showLooper = true }
        }
        .padding()
        .accessibilityIdentifier("instrument.cover")
    }

    @ToolbarContentBuilder
    private var playToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(L10nKey.looperTitle.text(in: model.language)) { model.showLooper = true }
                .accessibilityIdentifier("nav.looper")
            Button(L10nKey.midiTitle.text(in: model.language)) { model.showMIDI = true }
                .accessibilityIdentifier("nav.midi")
            Button {
                model.showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityIdentifier("nav.settings")
        }
    }

    private var title: String {
        switch id {
        case .accordion: return L10nKey.instrumentAccordion.text(in: model.language)
        case .pitchBendGuitar: return L10nKey.instrumentGuitar.text(in: model.language)
        case .filterSweep: return L10nKey.instrumentFilter.text(in: model.language)
        case .theremin: return L10nKey.instrumentTheremin.text(in: model.language)
        }
    }

    private func audioOverlay(_ overlay: AppModel.AudioOverlay) -> some View {
        let text: String
        switch overlay {
        case .interrupted: text = L10nKey.instrumentInterrupted.text(in: model.language)
        case .headphonesUnplugged: text = L10nKey.instrumentHeadphones.text(in: model.language)
        case .noOutput: text = L10nKey.instrumentNoOutput.text(in: model.language)
        case .bluetoothLatency: text = L10nKey.instrumentBluetooth.text(in: model.language)
        case .cpuOverload: text = L10nKey.settingsBufferNormal.text(in: model.language)
        }
        return Text(text)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("audio.overlay")
    }
}
