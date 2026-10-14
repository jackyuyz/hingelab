import SwiftUI
import HingeL10n
import Looper

struct LooperView: View {
    @EnvironmentObject private var model: AppModel
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Text(statusText)
                    .accessibilityIdentifier("looper.status")
                if model.recorder.tracks.isEmpty {
                    Text(L10nKey.looperEmpty.text(in: model.language))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.recorder.tracks) { loop in
                        VStack(alignment: .leading) {
                            Text(loop.fileName).font(.caption.monospaced())
                            Text(String(format: "%.1fs · %.0f BPM", loop.durationSeconds, loop.bpm))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                Button(L10nKey.looperRecord.text(in: model.language)) {
                    if let error = model.recorder.beginRecording() {
                        message = L10nKey.pickerLocked.text(in: model.language)
                        if error.kind == .trackLimit { model.showPaywall = true }
                    }
                }
                .accessibilityIdentifier("looper.record")
                Button(L10nKey.looperStop.text(in: model.language)) {
                    _ = model.recorder.stopRecording()
                }
                Button(L10nKey.looperOverdub.text(in: model.language)) {
                    model.recorder.beginOverdub()
                }
                Button(L10nKey.looperExport.text(in: model.language)) {
                    export()
                }
                .disabled(!model.entitlements.audioExportEnabled)
            }
        }
        .navigationTitle(L10nKey.looperTitle.text(in: model.language))
        .alert(L10nKey.looperExportFailed.text(in: model.language), isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button(L10nKey.commonOK.text(in: model.language)) { message = nil }
        }
    }

    private var statusText: String {
        switch model.recorder.state {
        case .empty: return L10nKey.looperEmpty.text(in: model.language)
        case .recording: return L10nKey.looperRecording.text(in: model.language)
        case .overdubbing: return L10nKey.looperOverdub.text(in: model.language)
        case .saving: return L10nKey.looperSaving.text(in: model.language)
        case .exportFailed: return L10nKey.looperExportFailed.text(in: model.language)
        case .playing, .stopped: return L10nKey.looperPlay.text(in: model.language)
        }
    }

    private func export() {
        do {
            _ = try model.recorder.exportWAV()
        } catch {
            message = L10nKey.looperExportFailed.text(in: model.language)
        }
    }
}
