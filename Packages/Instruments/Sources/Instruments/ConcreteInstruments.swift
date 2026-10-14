import Foundation
import HingeInput
import MIDIOut
import SettingsKit
import Synth

public final class InstrumentCore: @unchecked Sendable {
    public let id: InstrumentID
    public private(set) var params: InstrumentParams
    public private(set) var midiEvents: [MIDIEvent] = []
    public var settings: UserSettings
    public var heldNotes: Set<UInt8> = []
    public var touchAmplitude: Double = 1
    private var previousVelocity: Double = 0
    private var restStartedAt: TimeInterval?
    public var needsBellowsHint: Bool = false
    public var articulation: Double = 0

    public init(id: InstrumentID, settings: UserSettings = .default) {
        self.id = id
        self.settings = settings
        self.params = InstrumentParams()
    }

    public func handle(_ sample: HingeSample) {
        midiEvents.removeAll(keepingCapacity: true)
        switch id {
        case .accordion:
            handleAccordion(sample)
        case .pitchBendGuitar:
            handleGuitar(sample)
        case .filterSweep:
            handleFilter(sample)
        case .theremin:
            handleTheremin(sample)
        }
        emitHingeMIDI(sample)
    }

    public func noteOn(_ note: UInt8, velocity: UInt8) {
        heldNotes.insert(note)
        midiEvents.append(.noteOn(channel: settings.midiMapping.channel, note: note, velocity: velocity))
        if id == .pitchBendGuitar || id == .accordion {
            params.frequencyHz = ThereminMapping.midiToHz(Double(note), a4: settings.a4Hz)
            if id == .pitchBendGuitar {
                params.amplitude = Double(velocity) / 127
            }
        }
        if id == .accordion, params.amplitude == 0 {
            restStartedAt = restStartedAt ?? Date().timeIntervalSince1970
        }
    }

    public func noteOff(_ note: UInt8) {
        heldNotes.remove(note)
        midiEvents.append(.noteOff(channel: settings.midiMapping.channel, note: note))
        if heldNotes.isEmpty, id != .theremin, id != .filterSweep {
            if id == .pitchBendGuitar {
                params.amplitude = 0
            }
        }
    }

    public func allNotesOff(release: Bool) {
        for note in heldNotes {
            midiEvents.append(.noteOff(channel: settings.midiMapping.channel, note: note))
        }
        heldNotes.removeAll()
        if release {
            params.amplitude = 0
        }
    }

    public func setTouchAmplitude(_ value: Double) {
        touchAmplitude = min(1, max(0, value))
        if id == .theremin {
            params.amplitude = touchAmplitude
        }
    }

    private func handleAccordion(_ sample: HingeSample) {
        let pressure = AccordionMapping.pressure(velocityDegPerSec: sample.velocityDegPerSec)
        articulation = AccordionMapping.isDirectionChange(previous: previousVelocity, current: sample.velocityDegPerSec) ? 1 : max(0, articulation - 0.2)
        previousVelocity = sample.velocityDegPerSec
        params.amplitude = heldNotes.isEmpty ? 0 : min(1, pressure + articulation * 0.15)
        params.frequencyHz = ThereminMapping.midiToHz(Double(heldNotes.min() ?? AccordionLayout.melodyStart), a4: settings.a4Hz)
        if pressure == 0, !heldNotes.isEmpty {
            if restStartedAt == nil { restStartedAt = sample.timestamp }
            needsBellowsHint = sample.timestamp - (restStartedAt ?? sample.timestamp) >= 3
        } else {
            restStartedAt = nil
            needsBellowsHint = false
        }
    }

    private func handleGuitar(_ sample: HingeSample) {
        let value = sample.isInDeadZone ? 0.5 : sample.smoothedValue01
        params.pitchBendSemitones = PitchMapping.semitones(
            value01: value,
            range: settings.pitchBendRangeSemitones
        )
        if sample.posture == .closed {
            params.pitchBendSemitones = 0
        }
    }

    private func handleFilter(_ sample: HingeSample) {
        params.cutoffHz = FilterMapping.cutoffHz(value01: sample.smoothedValue01)
        params.resonance = FilterMapping.resonance(velocityDegPerSec: sample.velocityDegPerSec)
        if !heldNotes.isEmpty || params.amplitude > 0 {
            params.amplitude = max(params.amplitude, 0.4)
        } else {
            params.amplitude = 0.4
            params.frequencyHz = ThereminMapping.midiToHz(48, a4: settings.a4Hz)
        }
    }

    private func handleTheremin(_ sample: HingeSample) {
        let hz = ThereminMapping.frequencyHz(
            value01: sample.smoothedValue01,
            a4: settings.a4Hz,
            scale: settings.scale
        )
        params.frequencyHz = hz
        params.amplitude = touchAmplitude
        params.pitchBendSemitones = 0
    }

    private func emitHingeMIDI(_ sample: HingeSample) {
        guard sample.posture != .closed else { return }
        midiEvents.append(settings.midiMapping.event(value01: sample.smoothedValue01))
    }
}

public final class AccordionInstrument: Instrument, @unchecked Sendable {
    public static let id: InstrumentID = .accordion
    private let core: InstrumentCore
    public var params: InstrumentParams { core.params }
    public var midiEvents: [MIDIEvent] { core.midiEvents }
    public var needsBellowsHint: Bool { core.needsBellowsHint }

    public init(settings: UserSettings = .default) {
        core = InstrumentCore(id: .accordion, settings: settings)
    }

    public func handle(_ sample: HingeSample) { core.handle(sample) }
    public func noteOn(_ n: UInt8, velocity: UInt8) { core.noteOn(n, velocity: velocity) }
    public func noteOff(_ n: UInt8) { core.noteOff(n) }
    public func allNotesOff(release: Bool) { core.allNotesOff(release: release) }
}

public final class GuitarInstrument: Instrument, @unchecked Sendable {
    public static let id: InstrumentID = .pitchBendGuitar
    private let core: InstrumentCore
    public var params: InstrumentParams { core.params }
    public var midiEvents: [MIDIEvent] { core.midiEvents }

    public init(settings: UserSettings = .default) {
        core = InstrumentCore(id: .pitchBendGuitar, settings: settings)
    }

    public func handle(_ sample: HingeSample) { core.handle(sample) }
    public func noteOn(_ n: UInt8, velocity: UInt8) { core.noteOn(n, velocity: velocity) }
    public func noteOff(_ n: UInt8) { core.noteOff(n) }
    public func allNotesOff(release: Bool) { core.allNotesOff(release: release) }
}

public final class FilterSweepInstrument: Instrument, @unchecked Sendable {
    public static let id: InstrumentID = .filterSweep
    private let core: InstrumentCore
    public var params: InstrumentParams { core.params }
    public var midiEvents: [MIDIEvent] { core.midiEvents }

    public init(settings: UserSettings = .default) {
        core = InstrumentCore(id: .filterSweep, settings: settings)
    }

    public func handle(_ sample: HingeSample) { core.handle(sample) }
    public func noteOn(_ n: UInt8, velocity: UInt8) { core.noteOn(n, velocity: velocity) }
    public func noteOff(_ n: UInt8) { core.noteOff(n) }
    public func allNotesOff(release: Bool) { core.allNotesOff(release: release) }
}

public final class ThereminInstrument: Instrument, @unchecked Sendable {
    public static let id: InstrumentID = .theremin
    private let core: InstrumentCore
    public var params: InstrumentParams { core.params }
    public var midiEvents: [MIDIEvent] { core.midiEvents }

    public init(settings: UserSettings = .default) {
        core = InstrumentCore(id: .theremin, settings: settings)
    }

    public func handle(_ sample: HingeSample) { core.handle(sample) }
    public func noteOn(_ n: UInt8, velocity: UInt8) { core.noteOn(n, velocity: velocity) }
    public func noteOff(_ n: UInt8) { core.noteOff(n) }
    public func allNotesOff(release: Bool) { core.allNotesOff(release: release) }
    public func setVolume(_ value: Double) { core.setTouchAmplitude(value) }
}

public enum InstrumentFactory {
    public static func make(_ id: InstrumentID, settings: UserSettings = .default) -> any Instrument {
        switch id {
        case .accordion: return AccordionInstrument(settings: settings)
        case .pitchBendGuitar: return GuitarInstrument(settings: settings)
        case .filterSweep: return FilterSweepInstrument(settings: settings)
        case .theremin: return ThereminInstrument(settings: settings)
        }
    }
}
