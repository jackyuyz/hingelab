import SwiftUI
import HingeL10n
import Looper
import ThemeKit

struct LooperView: View {
    @EnvironmentObject private var model: AppModel
    @State private var message: String?

    var body: some View {
        let theme = model.theme
        let hue = theme.ui(model.selectedInstrument.hueToken)
        List {
            Section {
                HStack(spacing: 16) {
                    RecordButton(
                        state: model.recorder.state,
                        theme: theme,
                        recordLabel: L10nKey.looperRecord.text(in: model.language),
                        stopLabel: L10nKey.looperStop.text(in: model.language)
                    ) {
                        if model.recorder.state == .recording || model.recorder.state == .overdubbing {
                            model.stopLoopRecording()
                        } else if let error = model.beginLoopRecording() {
                            message = L10nKey.pickerLocked.text(in: model.language)
                            if error.kind == .trackLimit { model.showPaywall = true }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusText)
                            .font(.system(.headline, design: .rounded))
                            .accessibilityIdentifier("looper.status")
                        Text(L10nKey.looperTracksUsed.text(in: model.language, "\(model.recorder.tracks.count)", "\(model.recorder.maxTracks)"))
                            .font(.system(.subheadline, design: .rounded).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            Section {
                if model.recorder.tracks.isEmpty {
                    Text(L10nKey.looperEmpty.text(in: model.language))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.recorder.tracks.enumerated()), id: \.element.id) { index, loop in
                        LoopTrackRow(index: index, loop: loop, hue: hue, language: model.language)
                    }
                }
            }
            Section {
                Button {
                    if let error = model.beginLoopRecording() {
                        message = L10nKey.pickerLocked.text(in: model.language)
                        if error.kind == .trackLimit { model.showPaywall = true }
                    }
                } label: {
                    Label(L10nKey.looperRecord.text(in: model.language), systemImage: "record.circle")
                }
                .accessibilityIdentifier("looper.record")
                Button {
                    model.stopLoopRecording()
                } label: {
                    Label(L10nKey.looperStop.text(in: model.language), systemImage: "stop.fill")
                }
                Button {
                    model.beginLoopOverdub()
                } label: {
                    Label(L10nKey.looperOverdub.text(in: model.language), systemImage: "square.stack.3d.up")
                }
                Button {
                    export()
                } label: {
                    Label(L10nKey.looperExport.text(in: model.language), systemImage: theme.systemImage(.export))
                }
                .disabled(!model.entitlements.audioExportEnabled)
            }
        }
        .tint(hue)
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
            _ = try model.exportLoop()
        } catch {
            message = L10nKey.looperExportFailed.text(in: model.language)
        }
    }
}

/// Big round record/stop control. Red while recording, pulsing ring
/// (static with Reduce Motion).
private struct RecordButton: View {
    var state: LoopState
    var theme: any ThemeProviding
    var recordLabel: String
    var stopLabel: String
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isRecording: Bool { state == .recording || state == .overdubbing }

    var body: some View {
        let red = theme.ui(.destructive)
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(red.opacity(0.35), lineWidth: 3)
                if isRecording {
                    RoundedRectangle(cornerRadius: 6).fill(red).frame(width: 24, height: 24)
                } else {
                    Circle().fill(red).frame(width: 34, height: 34)
                }
            }
            .frame(width: 60, height: 60)
            .scaleEffect(isRecording && !reduceMotion ? 1.06 : 1)
            .animation(isRecording && !reduceMotion ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? stopLabel : recordLabel)
    }
}

/// One loop: index, name, duration · BPM, with a mini meter bar.
struct LoopTrackRow: View {
    var index: Int
    var loop: Loop
    var hue: Color
    var language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(.headline, design: .monospaced))
                .frame(width: 32, height: 32)
                .background(hue.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(hue)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10nKey.looperTrack.text(in: language, "\(index + 1)"))
                    .font(.system(.body, design: .rounded).weight(.medium))
                Text(String(format: "%.1fs · %.0f BPM", loop.durationSeconds, loop.bpm))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Capsule()
                .fill(hue.opacity(0.6))
                .frame(width: CGFloat(min(80, max(8, loop.durationSeconds * 8))), height: 6)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}
