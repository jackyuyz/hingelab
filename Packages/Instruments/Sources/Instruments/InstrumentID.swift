import Foundation
import HingeInput
import MIDIOut
import Synth

public enum InstrumentID: String, CaseIterable, Codable, Sendable {
    case accordion
    case pitchBendGuitar
    case filterSweep
    case theremin

    public var isFree: Bool { self == .accordion }

    public var defaultVoice: SynthVoiceKind {
        switch self {
        case .accordion: return .reed
        case .pitchBendGuitar: return .karplusStrong
        case .filterSweep: return .subtractive
        case .theremin: return .theremin
        }
    }
}

public struct InstrumentParams: Equatable, Sendable {
    public var pitchBendSemitones: Double
    public var amplitude: Double
    public var cutoffHz: Double
    public var resonance: Double
    public var frequencyHz: Double?

    public init(
        pitchBendSemitones: Double = 0,
        amplitude: Double = 0,
        cutoffHz: Double = 8_000,
        resonance: Double = 0.2,
        frequencyHz: Double? = nil
    ) {
        self.pitchBendSemitones = pitchBendSemitones
        self.amplitude = amplitude
        self.cutoffHz = cutoffHz
        self.resonance = resonance
        self.frequencyHz = frequencyHz
    }

    public var asVoice: VoiceParams {
        VoiceParams(
            amplitude: amplitude,
            frequencyHz: frequencyHz ?? 440,
            cutoffHz: cutoffHz,
            resonance: resonance,
            pitchBendSemitones: pitchBendSemitones
        )
    }
}

public protocol Instrument: AnyObject, Sendable {
    static var id: InstrumentID { get }
    var params: InstrumentParams { get }
    var midiEvents: [MIDIEvent] { get }
    func handle(_ sample: HingeSample)
    func noteOn(_ note: UInt8, velocity: UInt8)
    func noteOff(_ note: UInt8)
    func allNotesOff(release: Bool)
}
