import Testing
import Foundation
import HingeInput
import FoldKit
import MIDIOut
import SettingsKit
@testable import Instruments

func sample(value01: Double, velocity: Double = 0, posture: FoldPosture = .partiallyOpen, angle: Double? = 90, dead: Bool = false) -> HingeSample {
    HingeSample(
        timestamp: 1,
        posture: posture,
        angleDegrees: angle,
        value01: value01,
        deltaDegrees: (value01 - 0.5) * 100,
        velocityDegPerSec: velocity,
        smoothedValue01: value01,
        isInDeadZone: dead,
        source: .hinge
    )
}

@Suite("Pitch bend mapping")
struct PitchBendMappingTests {
    @Test("Ends and center within ±5 cents for ±2 and ±12")
    func cents() {
        for range in [2.0, 12.0] {
            let low = PitchMapping.semitones(value01: 0, range: range)
            let mid = PitchMapping.semitones(value01: 0.5, range: range)
            let high = PitchMapping.semitones(value01: 1, range: range)
            #expect(abs(PitchMapping.centsError(actualSemitones: low, expectedSemitones: -range)) <= 5)
            #expect(abs(PitchMapping.centsError(actualSemitones: mid, expectedSemitones: 0)) <= 5)
            #expect(abs(PitchMapping.centsError(actualSemitones: high, expectedSemitones: range)) <= 5)
        }
        #expect(PitchMapping.midi14(value01: 0.5) == 8192)
    }
}

@Suite("Filter mapping")
struct FilterMappingTests {
    @Test("Exponential cutoff")
    func cutoff() {
        #expect(abs(FilterMapping.cutoffHz(value01: 0) - 20) < 0.001)
        #expect(abs(FilterMapping.cutoffHz(value01: 1) - 20_000) < 0.01)
        let mid = FilterMapping.cutoffHz(value01: 0.5)
        #expect(mid > 20 && mid < 20_000)
        #expect(abs(mid - sqrt(20.0 * 20_000.0)) < 0.1)
    }
}

@Suite("Accordion mapping")
struct AccordionMappingTests {
    @Test("Rest is silence, motion is pressure")
    func pressure() {
        #expect(AccordionMapping.pressure(velocityDegPerSec: 0) == 0)
        #expect(AccordionMapping.pressure(velocityDegPerSec: 1.5) == 0)
        #expect(AccordionMapping.pressure(velocityDegPerSec: 90) == 0.5)
        #expect(AccordionMapping.pressure(velocityDegPerSec: 400) == 1)
        #expect(AccordionMapping.isDirectionChange(previous: 10, current: -10))
        #expect(!AccordionMapping.isDirectionChange(previous: 10, current: 12))
    }
}

@Suite("Theremin mapping")
struct ThereminMappingTests {
    @Test("A4 tuning and quantization")
    func frequency() {
        #expect(abs(ThereminMapping.midiToHz(69, a4: 440) - 440) < 0.0001)
        #expect(abs(ThereminMapping.midiToHz(69, a4: 432) - 432) < 0.0001)
        let continuous = ThereminMapping.frequencyHz(value01: 0.5, minNote: 60, maxNote: 72, scale: .off)
        let quantized = ThereminMapping.frequencyHz(value01: 0.5, minNote: 60, maxNote: 72, scale: .chromatic)
        #expect(abs(continuous - ThereminMapping.midiToHz(66)) < 0.01)
        #expect(abs(quantized - ThereminMapping.midiToHz(66)) < 0.01)
    }
}

@Suite("Instrument behavior")
struct InstrumentBehaviorTests {
    @Test("Accordion silent without motion even with keys down")
    func accordionRest() {
        let accordion = AccordionInstrument()
        accordion.noteOn(60, velocity: 100)
        accordion.handle(sample(value01: 0.5, velocity: 0))
        #expect(accordion.params.amplitude == 0)
        accordion.handle(sample(value01: 0.6, velocity: 90))
        #expect(accordion.params.amplitude > 0)
    }

    @Test("Guitar dead zone holds center")
    func guitarDeadZone() {
        var settings = UserSettings.default
        settings.pitchBendRangeSemitones = 2
        let guitar = GuitarInstrument(settings: settings)
        guitar.handle(sample(value01: 0.7, dead: true))
        #expect(guitar.params.pitchBendSemitones == 0)
        guitar.handle(sample(value01: 1, dead: false))
        #expect(abs(guitar.params.pitchBendSemitones - 2) < 0.0001)
    }

    @Test("Closed posture zeros guitar bend")
    func closed() {
        let guitar = GuitarInstrument()
        guitar.handle(sample(value01: 1, posture: .closed, angle: 0, dead: false))
        #expect(guitar.params.pitchBendSemitones == 0)
    }

    @Test("Theremin volume is independent of hinge")
    func thereminVolume() {
        let theremin = ThereminInstrument()
        theremin.setVolume(0.25)
        theremin.handle(sample(value01: 0.8))
        #expect(theremin.params.amplitude == 0.25)
        #expect(theremin.params.frequencyHz != nil)
    }

    @Test("Filter drone stays audible")
    func filter() {
        let filter = FilterSweepInstrument()
        filter.handle(sample(value01: 0.1, velocity: 10))
        #expect(filter.params.amplitude > 0)
        #expect(filter.params.cutoffHz < FilterMapping.cutoffHz(value01: 0.9))
    }

    @Test("Filter step pads retune the drone and keep the hinge cutoff")
    func filterSteps() {
        let filter = FilterSweepInstrument()
        filter.noteOn(55, velocity: 100)
        #expect(filter.params.amplitude >= 0.4)
        #expect(abs((filter.params.frequencyHz ?? 0) - 195.998) < 0.01)
        filter.handle(sample(value01: 0.5))
        #expect(abs((filter.params.frequencyHz ?? 0) - 195.998) < 0.01, "hinge moves cutoff, not pitch")
        #expect(filter.params.cutoffHz > 20)
    }

    @Test("Free vs paid ids")
    func gating() {
        #expect(InstrumentID.accordion.isFree)
        #expect(!InstrumentID.theremin.isFree)
        #expect(InstrumentID.allCases.count == 4)
    }

    @Test("Ribbon sample drives the same guitar mapping")
    func ribbonParity() {
        let guitar = GuitarInstrument()
        var ribbon = sample(value01: 0.25)
        ribbon = HingeSample(
            timestamp: 1,
            posture: .noHinge,
            angleDegrees: nil,
            value01: 0.25,
            deltaDegrees: -25,
            velocityDegPerSec: 0,
            smoothedValue01: 0.25,
            isInDeadZone: false,
            source: .ribbon
        )
        guitar.handle(ribbon)
        #expect(abs(guitar.params.pitchBendSemitones - PitchMapping.semitones(value01: 0.25, range: 2)) < 0.0001)
    }
}
