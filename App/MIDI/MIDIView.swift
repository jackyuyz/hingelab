import SwiftUI
import HingeL10n
import MIDIOut
import ThemeKit

struct MIDIView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let theme = model.theme
        List {
            Section {
                HStack {
                    Label(L10nKey.midiVirtualSource.text(in: model.language), systemImage: theme.systemImage(.midi))
                    Spacer()
                    Text(model.midi.virtualSourceName)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("midi.source")
                }
                MIDIStatusPill(status: status, language: model.language, theme: theme)
                if model.midi.destinationCount == 0 {
                    Text(L10nKey.midiNoDestinations.text(in: model.language))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle(L10nKey.midiNetwork.text(in: model.language), isOn: networkBinding)
                    .disabled(!model.entitlements.midiEnabled)
                Toggle(L10nKey.midiBluetooth.text(in: model.language), isOn: bluetoothBinding)
                    .disabled(!model.entitlements.midiEnabled)
            } footer: {
                Text(L10nKey.midiConnectMac.text(in: model.language))
            }
            Section(L10nKey.midiMapping.text(in: model.language)) {
                HStack {
                    Text(L10nKey.midiChannel.text(in: model.language))
                    Spacer()
                    Text("\(Int(model.settings.midiMapping.channel) + 1)")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L10nKey.midiMapping.text(in: model.language))
                    Spacer()
                    Text(mappingName)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            if !model.entitlements.midiEnabled {
                Section {
                    Button {
                        model.showPaywall = true
                    } label: {
                        Label(L10nKey.pickerLocked.text(in: model.language), systemImage: theme.systemImage(.lock))
                    }
                }
            }
        }
        .tint(theme.ui(model.selectedInstrument.hueToken))
        .navigationTitle(L10nKey.midiTitle.text(in: model.language))
        // TODO(verify-api): CABTMIDILocalPeripheralViewController still supported on iOS 27?
        // Present it only from this screen after the user enables Bluetooth MIDI.
        // MIDINetworkSession is requested only here (NSLocalNetworkUsageDescription).
    }

    private var status: MIDIStatusPill.Status {
        if model.midi.isBluetoothAdvertising { return .advertising }
        return model.midi.destinationCount > 0 ? .connected : .waiting
    }

    private var mappingName: String {
        switch model.settings.midiMapping.hingeTarget {
        case .pitchBend: return L10nKey.midiPitchBend.text(in: model.language)
        case .cc(let number): return "CC\(number)"
        }
    }

    private var networkBinding: Binding<Bool> {
        Binding(
            get: { model.midi.isNetworkEnabled },
            set: { model.midi.isNetworkEnabled = $0 }
        )
    }

    private var bluetoothBinding: Binding<Bool> {
        Binding(
            get: { model.midi.isBluetoothAdvertising },
            set: { model.midi.isBluetoothAdvertising = $0 }
        )
    }
}

/// Connection state chip: color and label together, never color alone.
struct MIDIStatusPill: View {
    enum Status { case waiting, connected, advertising }

    var status: Status
    var language: AppLanguage
    var theme: any ThemeProviding

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.16), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("midi.status")
    }

    private var color: Color {
        switch status {
        case .waiting: return theme.ui(.guitarHue)
        case .connected: return theme.ui(.waveform)
        case .advertising: return theme.ui(.thereminHue)
        }
    }

    private var text: String {
        switch status {
        case .waiting: return L10nKey.midiConnectMac.text(in: language)
        case .connected: return L10nKey.midiConnected.text(in: language)
        case .advertising: return L10nKey.midiBluetooth.text(in: language)
        }
    }
}
