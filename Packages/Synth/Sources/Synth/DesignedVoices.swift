import Foundation

// Designed patches for the four instruments. Each voice keeps the public
// surface the placeholder had (init, apply, smoothers) so mappings, MIDI and
// tests are untouched. All buffers are allocated in `init`; `render` never
// allocates.

// MARK: - Accordion

/// Free-reed accordion. Three band-limited reeds tuned to a constant musette
/// beat (the way accordion tuners set tremolo), a body formant, and a little
/// bellows breath. When built-in reed samples are loaded, the sampler replaces
/// the synthesized reeds and the envelope stays the same.
public struct ReedVoice: SynthRendering {
    private var center = BLEPOscillator(phase: 0)
    private var low = BLEPOscillator(phase: 0.31)
    private var high = BLEPOscillator(phase: 0.67)
    private var formant = StateVariableFilter()
    private var breathFilter = StateVariableFilter()
    private var tone = OnePoleLowPass()
    private var breathNoise = SeededRNG(seed: 0xACC0_2D10)
    public var sampler = LoopingSampler()
    public var ampSmoother: AudioParameterSmoother
    public var freqSmoother: AudioParameterSmoother
    public var active = false
    /// Musette beat between the middle reed and each side reed, in Hz.
    public var musetteBeatHz: Double = 1.25

    public init(sampleRate: Double = AudioConstants.defaultSampleRate) {
        ampSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 0)
        freqSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 440)
    }

    public mutating func apply(_ params: VoiceParams) {
        ampSmoother.setTarget(params.amplitude)
        freqSmoother.setTarget(params.bentFrequencyHz)
        active = params.amplitude > 0.0001
    }

    public mutating func noteOn(frequencyHz: Double, velocity: Double) {
        apply(VoiceParams(amplitude: velocity, frequencyHz: frequencyHz))
    }

    public mutating func noteOff() {
        ampSmoother.setTarget(0)
        active = false
    }

    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, sampleRate: Double) {
        let sr = max(sampleRate, 1)
        for i in 0..<buffer.count {
            let amp = ampSmoother.next()
            let freq = freqSmoother.next()
            var reed: Double
            if sampler.hasSamples {
                reed = sampler.next(frequencyHz: freq, sampleRate: sr) * 1.1
            } else {
                let a = center.sawAndPulse(frequencyHz: freq, sampleRate: sr, width: 0.32)
                let b = low.sawAndPulse(frequencyHz: max(1, freq - musetteBeatHz), sampleRate: sr, width: 0.32)
                let c = high.sawAndPulse(frequencyHz: freq + musetteBeatHz, sampleRate: sr, width: 0.32)
                let mid = 0.72 * a.saw + 0.28 * a.pulse
                let side = 0.72 * (b.saw + c.saw) + 0.28 * (b.pulse + c.pulse)
                let mix = 0.5 * mid + 0.25 * side
                let body = formant.process(mix, cutoffHz: 1_350, q: 1.3, sampleRate: sr).band
                reed = tone.process(0.62 * mix + 0.55 * body, cutoffHz: 6_500, sampleRate: sr)
            }
            let breath = breathFilter.process(breathNoise.nextSigned(), cutoffHz: 3_200, q: 0.9, sampleRate: sr).band
            let out = (reed + breath * 0.035) * amp * 0.66
            buffer[i] = Float(softClip(out))
        }
    }
}

// MARK: - Pitch-bend guitar

/// One plucked string: fractional delay line (so the hinge can bend it while
/// it rings), a two-point loop filter, and per-pass decay.
public struct PluckedString: Sendable {
    private var line: [Float]
    private var write = 0
    private var lastRead = 0.0
    public private(set) var baseHz = 110.0
    public private(set) var level = 0.0
    private var decayPerSample = 0.9999
    private var decayPerPass = 0.99
    public var isSounding: Bool { level > 0.0002 }

    public init(capacity: Int) {
        line = [Float](repeating: 0, count: max(capacity, 8))
    }

    /// Main/control thread. Fills the existing delay line (no allocation).
    public mutating func pluck(
        frequencyHz: Double,
        velocity: Double,
        sampleRate: Double,
        rng: inout SeededRNG,
        excitation: SampleBuffer?
    ) {
        let hz = max(frequencyHz, sampleRate / Double(line.count - 4))
        baseHz = hz
        let length = min(line.count - 2, max(2, Int(sampleRate / hz)))
        let vel = min(1, max(0.05, velocity))
        // Softer plucks are darker, like a real pick.
        let brightness = 0.25 + 0.7 * vel
        var lp = 0.0
        let pickOffset = max(1, Int(Double(length) * 0.18))
        for j in 0..<line.count { line[j] = 0 }
        for j in 0..<length {
            var x: Double
            if let excitation, !excitation.frames.isEmpty {
                x = Double(excitation.frames[j % excitation.frames.count])
            } else {
                x = rng.nextSigned()
            }
            lp += brightness * (x - lp)
            line[j] = Float(lp)
        }
        // Pick-position comb: removes harmonics that have a node at the pick.
        for j in stride(from: length - 1, through: pickOffset, by: -1) {
            line[j] -= line[j - pickOffset] * 0.9
        }
        var peak: Float = 0
        for j in 0..<length { peak = max(peak, abs(line[j])) }
        let gain = peak > 0 ? Float(vel) / peak : 0
        for j in 0..<length { line[j] *= gain }
        write = length
        lastRead = 0
        level = vel
        setRing(seconds: 4.5, sampleRate: sampleRate)
    }

    /// Ring time to -60 dB.
    public mutating func setRing(seconds: Double, sampleRate: Double) {
        let t60 = max(seconds, 0.02)
        decayPerSample = pow(10, -3 / (t60 * max(sampleRate, 1)))
        decayPerPass = pow(10, -3 / (t60 * baseHz))
    }

    public mutating func next(bendRatio: Double, sampleRate: Double) -> Double {
        guard level > 0.0002 else { return 0 }
        let n = line.count
        let delay = min(Double(n - 3), max(2, sampleRate / (baseHz * bendRatio) - 0.5))
        var readPos = Double(write) - delay
        if readPos < 0 { readPos += Double(n) }
        let i0 = Int(readPos)
        let frac = readPos - Double(i0)
        let a = Double(line[i0 % n])
        let b = Double(line[(i0 + 1) % n])
        let current = a + (b - a) * frac
        let filtered = 0.5 * (current + lastRead) * decayPerPass
        lastRead = current
        line[write] = Float(filtered)
        write += 1
        if write >= n { write = 0 }
        level *= decayPerSample
        return current
    }
}

/// Six-string Karplus-Strong guitar. Strings are plucked round-robin so a
/// strum rings together; the hinge bend applies to every ringing string.
public struct KarplusStrongVoice: SynthRendering {
    public static let stringCount = 6
    private var strings: [PluckedString]
    private var nextString = 0
    private var bodyLow = StateVariableFilter()
    private var bodyHigh = StateVariableFilter()
    private var dc = DCBlocker()
    private var bendSmoother: AudioParameterSmoother
    public var ampSmoother: AudioParameterSmoother
    public var rng: SeededRNG
    public var excitation: SampleBuffer?
    public var active = false
    public var damping: Double = 0.996

    public init(sampleRate: Double = AudioConstants.defaultSampleRate, seed: UInt64 = 1) {
        ampSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 0)
        bendSmoother = AudioParameterSmoother(sampleRate: sampleRate, timeSeconds: 0.012, value: 0)
        rng = SeededRNG(seed: seed)
        let capacity = Int(sampleRate / 30) + 8
        strings = (0..<Self.stringCount).map { _ in PluckedString(capacity: capacity) }
    }

    public var sampleRate: Double { ampSmoother.sampleRate }

    public mutating func pluck(frequencyHz: Double, velocity: Double, sampleRate: Double) {
        // Prefer a silent string, else the oldest.
        var index = nextString
        for offset in 0..<strings.count {
            let candidate = (nextString + offset) % strings.count
            if !strings[candidate].isSounding {
                index = candidate
                break
            }
        }
        strings[index].pluck(
            frequencyHz: frequencyHz,
            velocity: velocity,
            sampleRate: sampleRate,
            rng: &rng,
            excitation: excitation
        )
        nextString = (index + 1) % strings.count
        active = true
        ampSmoother.snap(1)
    }

    public mutating func noteOn(frequencyHz: Double, velocity: Double) {
        pluck(frequencyHz: frequencyHz, velocity: velocity, sampleRate: sampleRate)
    }

    /// Lifting every finger lets the strings ring out faster instead of
    /// cutting them (no click).
    public mutating func noteOff() {
        for i in 0..<strings.count {
            strings[i].setRing(seconds: 0.9, sampleRate: sampleRate)
        }
    }

    public mutating func apply(_ params: VoiceParams) {
        bendSmoother.setTarget(params.pitchBendSemitones + params.detuneCents / 100)
        if params.amplitude <= 0.0001, active {
            noteOff()
        }
        active = params.amplitude > 0.0001 || strings.contains { $0.isSounding }
    }

    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, sampleRate: Double) {
        let sr = max(sampleRate, 1)
        for i in 0..<buffer.count {
            let master = ampSmoother.next()
            let ratio = pow(2.0, bendSmoother.next() / 12)
            var sum = 0.0
            for s in 0..<strings.count {
                sum += strings[s].next(bendRatio: ratio, sampleRate: sr)
            }
            let low = bodyLow.process(sum, cutoffHz: 105, q: 2.2, sampleRate: sr).band
            let high = bodyHigh.process(sum, cutoffHz: 235, q: 2.0, sampleRate: sr).band
            let out = dc.process(sum * 0.75 + low * 0.35 + high * 0.2) * master * 0.7
            buffer[i] = Float(softClip(out))
        }
    }
}

// MARK: - Filter sweep

/// Drone: three detuned band-limited saws plus a sub sine into a resonant
/// state-variable low-pass. Resonance (from hinge velocity) sharpens Q;
/// soft saturation keeps the peaks musical.
public struct SubtractiveVoice: SynthRendering {
    private var sawA = BLEPOscillator(phase: 0)
    private var sawB = BLEPOscillator(phase: 0.23)
    private var sawC = BLEPOscillator(phase: 0.71)
    private var sub = Oscillator(waveform: .sine)
    private var svf = StateVariableFilter()
    private var dc = DCBlocker()
    public var ampSmoother: AudioParameterSmoother
    public var cutoffSmoother: AudioParameterSmoother
    public var resoSmoother: AudioParameterSmoother
    public var freqSmoother: AudioParameterSmoother

    public init(sampleRate: Double = AudioConstants.defaultSampleRate) {
        ampSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 0)
        cutoffSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 1_000)
        resoSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 0.2)
        freqSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 110)
    }

    public mutating func apply(_ params: VoiceParams) {
        ampSmoother.setTarget(params.amplitude)
        cutoffSmoother.setTarget(params.cutoffHz)
        resoSmoother.setTarget(params.resonance)
        freqSmoother.setTarget(params.bentFrequencyHz)
    }

    public mutating func noteOn(frequencyHz: Double, velocity: Double) {
        ampSmoother.setTarget(velocity)
        freqSmoother.setTarget(frequencyHz)
    }

    public mutating func noteOff() {
        ampSmoother.setTarget(0)
    }

    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, sampleRate: Double) {
        let sr = max(sampleRate, 1)
        let detune = pow(2.0, 7.0 / 1200)
        for i in 0..<buffer.count {
            let amp = ampSmoother.next()
            let cutoff = max(20, cutoffSmoother.next())
            let reso = min(1, max(0, resoSmoother.next()))
            let freq = freqSmoother.next()
            let raw = (sawA.saw(frequencyHz: freq, sampleRate: sr)
                + sawB.saw(frequencyHz: freq * detune, sampleRate: sr)
                + sawC.saw(frequencyHz: freq / detune, sampleRate: sr)) / 3
                + 0.35 * sub.next(frequencyHz: freq * 0.5, sampleRate: sr)
            let q = 0.6 + pow(reso, 1.5) * 9
            let filtered = svf.process(raw, cutoffHz: cutoff, q: q, sampleRate: sr).low
            // Keep loudness roughly even as Q rises.
            let compensated = filtered / (1 + 0.12 * q)
            let out = dc.process(softClip(compensated * 1.4)) * amp * 0.6
            buffer[i] = Float(out)
        }
    }
}

// MARK: - Theremin

/// Near-sine with a touch of even harmonic and triangle, a gentle performer
/// vibrato, and a soft tone filter.
public struct ThereminVoice: SynthRendering {
    private var phase = 0.0
    private var vibratoPhase = 0.0
    private var tone = OnePoleLowPass()
    public var ampSmoother: AudioParameterSmoother
    public var freqSmoother: AudioParameterSmoother
    public var vibratoHz: Double = 5.3
    /// Peak vibrato depth in cents.
    public var vibratoCents: Double = 5

    public init(sampleRate: Double = AudioConstants.defaultSampleRate) {
        ampSmoother = AudioParameterSmoother(sampleRate: sampleRate, timeSeconds: 0.03, value: 0)
        freqSmoother = AudioParameterSmoother(sampleRate: sampleRate, timeSeconds: 0.025, value: 440)
    }

    public mutating func apply(_ params: VoiceParams) {
        ampSmoother.setTarget(params.amplitude)
        freqSmoother.setTarget(params.bentFrequencyHz)
    }

    public mutating func noteOn(frequencyHz: Double, velocity: Double) {
        apply(VoiceParams(amplitude: velocity, frequencyHz: frequencyHz))
    }

    public mutating func noteOff() {
        ampSmoother.setTarget(0)
    }

    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, sampleRate: Double) {
        let sr = max(sampleRate, 1)
        for i in 0..<buffer.count {
            let amp = ampSmoother.next()
            let vibrato = sin(2 * Double.pi * vibratoPhase) * vibratoCents / 1200
            vibratoPhase += vibratoHz / sr
            if vibratoPhase >= 1 { vibratoPhase -= 1 }
            let freq = freqSmoother.next() * pow(2.0, vibrato)
            let s = sin(2 * Double.pi * phase)
            let tri = 4 * abs(phase - 0.5) - 1
            phase += freq / sr
            if phase >= 1 { phase -= floor(phase) }
            let shaped = 0.84 * s + 0.2 * (s * s - 0.5) + 0.07 * tri
            let out = tone.process(shaped, cutoffHz: 4_200, sampleRate: sr) * amp * 0.36
            buffer[i] = Float(out)
        }
    }
}
