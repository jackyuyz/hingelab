import SwiftUI
import HingeL10n

struct MIDIView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section {
                HStack {
                    Text(L10nKey.midiVirtualSource.text(in: model.language))
                    Spacer()
                    Text(model.midi.virtualSourceName)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("midi.source")
                }
                if model.midi.destinationCount == 0 {
                    Text(L10nKey.midiNoDestinations.text(in: model.language))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10nKey.midiConnected.text(in: model.language))
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
            if !model.entitlements.midiEnabled {
                Section {
                    Button(L10nKey.pickerLocked.text(in: model.language)) {
                        model.showPaywall = true
                    }
                }
            }
        }
        .navigationTitle(L10nKey.midiTitle.text(in: model.language))
        // TODO(verify-api): CABTMIDILocalPeripheralViewController still supported on iOS 27?
        // Present it only from this screen after the user enables Bluetooth MIDI.
        // MIDINetworkSession is requested only here (NSLocalNetworkUsageDescription).
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
