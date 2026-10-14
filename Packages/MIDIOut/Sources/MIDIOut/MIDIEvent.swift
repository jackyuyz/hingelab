import Foundation

public enum MIDIEvent: Equatable, Sendable {
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8)
    case controlChange(channel: UInt8, number: UInt8, value: UInt8)
    case pitchBend(channel: UInt8, value14: UInt16)
}

public enum HingeMIDITarget: Codable, Equatable, Sendable {
    case pitchBend
    case cc(UInt8)

    public static let modulation = HingeMIDITarget.cc(1)
    public static let expression = HingeMIDITarget.cc(11)
    public static let brightness = HingeMIDITarget.cc(74)
}

public struct MIDIMapping: Codable, Equatable, Sendable {
    public var hingeTarget: HingeMIDITarget
    public var channel: UInt8
    public var rangeLower: Double
    public var rangeUpper: Double

    public init(
        hingeTarget: HingeMIDITarget = .pitchBend,
        channel: UInt8 = 0,
        range: ClosedRange<Double> = 0...1
    ) {
        self.hingeTarget = hingeTarget
        self.channel = min(channel, 15)
        self.rangeLower = range.lowerBound
        self.rangeUpper = range.upperBound
    }

    public var range: ClosedRange<Double> { rangeLower...rangeUpper }

    public func event(value01: Double) -> MIDIEvent {
        let span = max(rangeUpper - rangeLower, 0.0001)
        let scaled = min(1, max(0, (value01 - rangeLower) / span))
        switch hingeTarget {
        case .pitchBend:
            return .pitchBend(channel: channel, value14: MIDIEncoder.pitchBend14(value01: scaled))
        case .cc(let number):
            let value = UInt8((scaled * 127).rounded())
            return .controlChange(channel: channel, number: number, value: min(127, value))
        }
    }
}

public enum MIDIEncoder {
    public static let pitchBendCenter: UInt16 = 8192
    public static let pitchBendMax: UInt16 = 16383

    public static func pitchBend14(value01: Double) -> UInt16 {
        let v = min(1, max(0, value01))
        return UInt16((v * Double(pitchBendMax)).rounded())
    }

    public static func encode(_ event: MIDIEvent) -> [UInt8] {
        switch event {
        case .noteOn(let ch, let note, let vel):
            return [0x90 | (ch & 0x0F), note & 0x7F, vel & 0x7F]
        case .noteOff(let ch, let note):
            return [0x80 | (ch & 0x0F), note & 0x7F, 0]
        case .controlChange(let ch, let number, let value):
            return [0xB0 | (ch & 0x0F), number & 0x7F, value & 0x7F]
        case .pitchBend(let ch, let value14):
            let clamped = min(pitchBendMax, value14)
            let lsb = UInt8(clamped & 0x7F)
            let msb = UInt8((clamped >> 7) & 0x7F)
            return [0xE0 | (ch & 0x0F), lsb, msb]
        }
    }
}

public protocol MIDISending: AnyObject, Sendable {
    var virtualSourceName: String { get }
    var isNetworkEnabled: Bool { get set }
    var isBluetoothAdvertising: Bool { get set }
    var destinationCount: Int { get }
    var sent: [MIDIEvent] { get }
    func send(_ event: MIDIEvent)
}

/// Linux / unit-test stand-in. The CoreMIDI virtual source "HingeLab" is
/// created by the iOS app host.
public final class NullMIDISender: MIDISending, @unchecked Sendable {
    public let virtualSourceName = "HingeLab"
    public var isNetworkEnabled = false
    public var isBluetoothAdvertising = false
    public var destinationCount = 0
    public private(set) var sent: [MIDIEvent] = []

    public init() {}

    public func send(_ event: MIDIEvent) {
        sent.append(event)
    }
}
