import Foundation
import MIDIOut

/// CoreMIDI / network / BLE scaffold. The virtual source name is always "HingeLab".
/// Real `MIDIClient` / `MIDISourceCreate` / `MIDINetworkSession` /
/// `CABTMIDILocalPeripheralViewController` live only in this file.
final class MIDIHost: MIDISending, @unchecked Sendable {
    private let inner = NullMIDISender()
    var virtualSourceName: String { inner.virtualSourceName }
    var isNetworkEnabled: Bool {
        get { inner.isNetworkEnabled }
        set { inner.isNetworkEnabled = newValue }
    }
    var isBluetoothAdvertising: Bool {
        get { inner.isBluetoothAdvertising }
        set { inner.isBluetoothAdvertising = newValue }
    }
    var destinationCount: Int { inner.destinationCount }
    var sent: [MIDIEvent] { inner.sent }

    func send(_ event: MIDIEvent) {
        inner.send(event)
        let _ = MIDIEncoder.encode(event)
        // TODO: MIDIReceived(virtualSource, packetList)
    }
}
