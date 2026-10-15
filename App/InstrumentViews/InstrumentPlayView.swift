import SwiftUI
import FoldKit
import HingeL10n
import Instruments
import ThemeKit

struct InstrumentPlayView: View {
    let id: InstrumentID
    @EnvironmentObject private var model: AppModel
    @State private var crease: CreaseRegion?

    var body: some View {
        let theme = model.theme
        let hue = theme.ui(id.hueToken)
        ZStack(alignment: .top) {
            StageGlow(hue: hue, theme: theme)
            playSurface
                .animation(.easeOut(duration: InstrumentMotion.closeReleaseSeconds), value: model.foldState.posture)
            SparkField(
                rate: InstrumentMotion.sparkRate(velocityDegPerSec: model.lastSample?.velocityDegPerSec ?? 0),
                hue: hue,
                sparkAssetName: theme.imageAssetName(.particleSpark)
            )
            if let overlay = model.audioOverlay {
                AudioOverlayBanner(overlay: overlay)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.audioOverlay)
        .environment(\.colorScheme, .dark)
        .tint(hue)
        .navigationTitle(model.foldState.posture == .closed ? "" : id.titleKey.text(in: model.language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.ui(.stageBackground), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
                .padding(.bottom, 8)
            }
        }
    }

    private var showsRibbon: Bool {
        model.foldState.posture == .noHinge || model.foldState.posture == .closed
    }

    @ViewBuilder
    private var playSurface: some View {
        let left = { AnyView(leftHalf) }
        let right = { AnyView(rightHalf(nutLeading: !model.settings.leftHanded)) }
        switch model.foldState.posture {
        case .partiallyOpen:
            DuoSplitStack(
                horizontal: model.settings.splitAxesHorizontal,
                crease: crease,
                leftHanded: model.settings.leftHanded,
                accent: model.theme.ui(id.hueToken),
                left: left,
                right: right
            )
        case .closed:
            compactPlayer
                .transition(.opacity)
        case .fullyOpen:
            VStack(spacing: 4) {
                FoldHintPill(text: L10nKey.instrumentFoldHint.text(in: model.language), theme: model.theme)
                fullKeyboard
            }
        case .noHinge, .unknown:
            fullKeyboard
        }
    }

    private var fullKeyboard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                leftHalf.frame(minWidth: 320)
                rightHalf(nutLeading: true).frame(minWidth: 320)
            }
            ScrollView {
                VStack(spacing: 0) {
                    leftHalf
                    rightHalf(nutLeading: true)
                }
            }
        }
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
    private func rightHalf(nutLeading: Bool) -> some View {
        switch id {
        case .accordion: AccordionRightView()
        case .pitchBendGuitar: GuitarStrumPad(nutLeading: nutLeading)
        case .filterSweep: FilterSequencerView()
        case .theremin: ThereminPitchView()
        }
    }

    /// Outer cover: one-handed pocket player. The hinge is inactive here; the
    /// ribbon (bottom inset) drives the instrument.
    private var compactPlayer: some View {
        let theme = model.theme
        let hue = theme.ui(id.hueToken)
        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                InstrumentGlyph(id: id, hue: hue, theme: theme)
                    .frame(width: 56, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10nKey.instrumentCoverTitle.text(in: model.language))
                        .stageLabelStyle(theme)
                    Text(id.titleKey.text(in: model.language))
                        .font(StageFont.display(26))
                        .foregroundStyle(theme.ui(.primaryText))
                }
                Spacer(minLength: 0)
            }
            WaveformSlot(amplitude: model.currentParams.amplitude, language: model.language, height: 64)
            AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language, compact: true)
            Button {
                model.showLooper = true
            } label: {
                Label(L10nKey.looperTitle.text(in: model.language), systemImage: theme.systemImage(.looper))
                    .font(StageFont.display(17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(theme.ui(.onHue))
            Spacer(minLength: 0)
        }
        .padding(16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("instrument.cover")
    }

    @ToolbarContentBuilder
    private var playToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { model.showLooper = true } label: {
                Label(L10nKey.looperTitle.text(in: model.language), systemImage: model.theme.systemImage(.looper))
            }
            .accessibilityIdentifier("nav.looper")
            Button { model.showMIDI = true } label: {
                Label(L10nKey.midiTitle.text(in: model.language), systemImage: model.theme.systemImage(.midi))
            }
            .accessibilityIdentifier("nav.midi")
            Button { model.showSettings = true } label: {
                Label(L10nKey.settingsTitle.text(in: model.language), systemImage: model.theme.systemImage(.settings))
            }
            .accessibilityIdentifier("nav.settings")
        }
    }
}

/// Soft hue light from the top of the stage, the "performance glow".
private struct StageGlow: View {
    var hue: Color
    var theme: any ThemeProviding

    var body: some View {
        ZStack {
            theme.ui(.stageBackground)
            RadialGradient(colors: [hue.opacity(0.16), .clear], center: .top, startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct FoldHintPill: View {
    var text: String
    var theme: any ThemeProviding

    var body: some View {
        Label(text, systemImage: "rectangle.portrait.and.arrow.forward")
            .font(StageFont.label)
            .foregroundStyle(theme.ui(.primaryText))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.ui(.surfaceRaised), in: Capsule())
            .accessibilityIdentifier("instrument.foldHint")
    }
}

/// Interrupted / unplugged / no output / Bluetooth / overload banner.
private struct AudioOverlayBanner: View {
    var overlay: AppModel.AudioOverlay
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let theme = model.theme
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint(theme))
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(theme.ui(.primaryText))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.ui(.surfaceRaised), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(tint(theme).opacity(0.6)))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("audio.overlay")
    }

    private var text: String {
        switch overlay {
        case .interrupted: return L10nKey.instrumentInterrupted.text(in: model.language)
        case .headphonesUnplugged: return L10nKey.instrumentHeadphones.text(in: model.language)
        case .noOutput: return L10nKey.instrumentNoOutput.text(in: model.language)
        case .bluetoothLatency: return L10nKey.instrumentBluetooth.text(in: model.language)
        case .cpuOverload: return L10nKey.settingsBufferNormal.text(in: model.language)
        }
    }

    private var symbol: String {
        switch overlay {
        case .interrupted: return "pause.circle.fill"
        case .headphonesUnplugged: return "headphones"
        case .noOutput: return "speaker.slash.fill"
        case .bluetoothLatency: return "clock.badge.exclamationmark"
        case .cpuOverload: return "gauge.with.dots.needle.67percent"
        }
    }

    private func tint(_ theme: any ThemeProviding) -> Color {
        switch overlay {
        case .headphonesUnplugged, .noOutput: return theme.ui(.destructive)
        case .interrupted, .bluetoothLatency, .cpuOverload: return theme.ui(.guitarHue)
        }
    }
}
