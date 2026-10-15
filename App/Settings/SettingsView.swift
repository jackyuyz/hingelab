import SwiftUI
import HingeL10n
import SettingsKit

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section(L10nKey.settingsLanguage.text(in: model.language)) {
                Picker(L10nKey.settingsLanguage.text(in: model.language), selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.nativeName).tag(option)
                    }
                }
            }
            Section(L10nKey.settingsBuffer.text(in: model.language)) {
                Picker(L10nKey.settingsBuffer.text(in: model.language), selection: bufferBinding) {
                    Text(L10nKey.settingsBufferLow.text(in: model.language)).tag(AudioBufferMode.lowLatency)
                    Text(L10nKey.settingsBufferNormal.text(in: model.language)).tag(AudioBufferMode.normal)
                }
            }
            Section(L10nKey.settingsPitchBend.text(in: model.language)) {
                Picker(L10nKey.settingsPitchBend.text(in: model.language), selection: bendBinding) {
                    Text("±2").tag(2.0)
                    Text("±12").tag(12.0)
                }
            }
            Section(L10nKey.settingsScale.text(in: model.language)) {
                Picker(L10nKey.settingsScale.text(in: model.language), selection: scaleBinding) {
                    ForEach(ScaleMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }
            Section(L10nKey.settingsA4.text(in: model.language)) {
                Stepper(value: a4Binding, in: 415...466, step: 1) {
                    Text("\(Int(model.settings.a4Hz)) Hz")
                        .font(.body.monospacedDigit())
                }
            }
            Section {
                Toggle(L10nKey.settingsHaptics.text(in: model.language), isOn: hapticsBinding)
                Toggle(L10nKey.settingsLeftHanded.text(in: model.language), isOn: leftBinding)
            }
            Section(L10nKey.paywallRestore.text(in: model.language)) {
                Button(L10nKey.paywallRestore.text(in: model.language)) {
                    Task { await model.store.restore() }
                }
                Button(L10nKey.pickerCalibrate.text(in: model.language)) {
                    model.showCalibration = true
                }
            }
            Section(L10nKey.settingsAbout.text(in: model.language)) {
                HStack {
                    Text(L10nKey.settingsVersion.text(in: model.language))
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L10nKey.settingsBundle.text(in: model.language))
                    Spacer()
                    Text("com.jackyu.hingelab").foregroundStyle(.secondary).font(.caption)
                }
            }
        }
        .tint(model.theme.ui(model.selectedInstrument.hueToken))
        .navigationTitle(L10nKey.settingsTitle.text(in: model.language))
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { model.language },
            set: { lang in model.updateSettings { $0.languageCode = lang.rawValue } }
        )
    }

    private var bufferBinding: Binding<AudioBufferMode> {
        Binding(
            get: { model.settings.audioBuffer },
            set: { mode in model.updateSettings { $0.audioBuffer = mode } }
        )
    }

    private var bendBinding: Binding<Double> {
        Binding(
            get: { model.settings.pitchBendRangeSemitones },
            set: { value in model.updateSettings { $0.pitchBendRangeSemitones = value } }
        )
    }

    private var scaleBinding: Binding<ScaleMode> {
        Binding(
            get: { model.settings.scale },
            set: { value in model.updateSettings { $0.scale = value } }
        )
    }

    private var a4Binding: Binding<Double> {
        Binding(
            get: { model.settings.a4Hz },
            set: { value in model.updateSettings { $0.a4Hz = value } }
        )
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { model.settings.hapticsEnabled },
            set: { value in model.updateSettings { $0.hapticsEnabled = value } }
        )
    }

    private var leftBinding: Binding<Bool> {
        Binding(
            get: { model.settings.leftHanded },
            set: { value in model.updateSettings { $0.leftHanded = value } }
        )
    }
}
