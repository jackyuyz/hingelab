import SwiftUI
import FoldKit
import HingeL10n
import Instruments
import ThemeKit

struct InstrumentPickerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if model.foldState.posture == .closed {
                    compactCover
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(InstrumentID.allCases, id: \.self) { id in
                            InstrumentCard(id: id)
                        }
                    }
                }
                if model.foldState.posture == .noHinge {
                    RibbonFallback(value: ribbonBinding, language: model.language)
                }
            }
            .padding()
        }
        .navigationTitle(L10nKey.appName.text(in: model.language))
        .toolbar { toolbar }
    }

    private var ribbonBinding: Binding<Double> {
        Binding(
            get: { model.ribbon.value01 },
            set: { model.ingestRibbon($0) }
        )
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: model.theme.systemImage(.accordion))
                .font(.system(size: 44))
            Text(L10nKey.appSubtitle.text(in: model.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            AngleGaugeSlot(angle: model.foldState.angleDegrees, language: model.language)
        }
    }

    private var compactCover: some View {
        VStack(spacing: 12) {
            Text(L10nKey.instrumentCoverTitle.text(in: model.language))
                .font(.headline)
            NavigationLink {
                InstrumentPlayView(id: .accordion)
            } label: {
                Label(L10nKey.instrumentAccordion.text(in: model.language), systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            Button(L10nKey.looperTitle.text(in: model.language)) { model.showLooper = true }
            RibbonFallback(value: ribbonBinding, language: model.language)
        }
        .accessibilityIdentifier("cover.compact")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                model.showCalibration = true
            } label: {
                Label(L10nKey.pickerCalibrate.text(in: model.language), systemImage: model.theme.systemImage(.calibrate))
            }
            .accessibilityIdentifier("picker.calibrate")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                model.showSettings = true
            } label: {
                Image(systemName: model.theme.systemImage(.settings))
            }
            .accessibilityIdentifier("picker.settings")
        }
    }
}

struct InstrumentCard: View {
    let id: InstrumentID
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let locked = !model.isUnlocked(id)
        NavigationLink {
            InstrumentPlayView(id: id)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title)
                Text(title)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                if locked {
                    Label(L10nKey.pickerLocked.text(in: model.language), systemImage: model.theme.systemImage(.lock))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if id.isFree {
                    Text(L10nKey.pickerFree.text(in: model.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(locked)
        .simultaneousGesture(TapGesture().onEnded {
            if locked { model.showPaywall = true }
        })
        .accessibilityIdentifier("picker.\(id.rawValue)")
    }

    private var title: String {
        switch id {
        case .accordion: return L10nKey.instrumentAccordion.text(in: model.language)
        case .pitchBendGuitar: return L10nKey.instrumentGuitar.text(in: model.language)
        case .filterSweep: return L10nKey.instrumentFilter.text(in: model.language)
        case .theremin: return L10nKey.instrumentTheremin.text(in: model.language)
        }
    }

    private var symbol: String {
        switch id {
        case .accordion: return model.theme.systemImage(.accordion)
        case .pitchBendGuitar: return model.theme.systemImage(.guitar)
        case .filterSweep: return model.theme.systemImage(.filter)
        case .theremin: return model.theme.systemImage(.theremin)
        }
    }
}
