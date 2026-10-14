import Foundation

public enum Waveform: String, Sendable, CaseIterable {
    case sine
    case triangle
    case saw
}

/// Deterministic LCG so Karplus-Strong and noise bursts are testable.
public struct SeededRNG: Sendable, Equatable {
    public var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func nextUnit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return Double(state >> 11) / Double(1 << 53)
    }

    public mutating func nextSigned() -> Double {
        nextUnit() * 2 - 1
    }
}

public struct Oscillator: Sendable, Equatable {
    public var waveform: Waveform
    public var phase: Double

    public init(waveform: Waveform = .sine, phase: Double = 0) {
        self.waveform = waveform
        self.phase = phase
    }

    public mutating func next(frequencyHz: Double, sampleRate: Double) -> Double {
        let sr = max(sampleRate, 1)
        let freq = max(frequencyHz, 0)
        let sample: Double
        switch waveform {
        case .sine:
            sample = sin(2 * Double.pi * phase)
        case .triangle:
            let t = phase.truncatingRemainder(dividingBy: 1)
            sample = 4 * abs(t - 0.5) - 1
        case .saw:
            sample = 2 * (phase.truncatingRemainder(dividingBy: 1)) - 1
        }
        phase += freq / sr
        if phase >= 1 { phase -= floor(phase) }
        return sample
    }
}

/// 2–3 detuned oscillators for the accordion musette.
public struct ReedVoice: Sendable {
    private var oscA = Oscillator(waveform: .saw)
    private var oscB = Oscillator(waveform: .saw, phase: 0.17)
    private var oscC = Oscillator(waveform: .triangle, phase: 0.41)
    public var ampSmoother: AudioParameterSmoother
    public var freqSmoother: AudioParameterSmoother
    public var active = false

    public init(sampleRate: Double = AudioConstants.defaultSampleRate) {
        ampSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 0)
        freqSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 440)
    }

    public mutating func apply(_ params: VoiceParams) {
        ampSmoother.setTarget(params.amplitude)
        freqSmoother.setTarget(params.bentFrequencyHz)
        active = params.amplitude > 0.0001
    }

    public mutating func render(into buffer: inout [Float], sampleRate: Double) {
        for i in 0..<buffer.count {
            let amp = ampSmoother.next()
            let freq = freqSmoother.next()
            let a = oscA.next(frequencyHz: freq, sampleRate: sampleRate)
            let b = oscB.next(frequencyHz: freq * 1.002, sampleRate: sampleRate)
            let c = oscC.next(frequencyHz: freq * 0.997, sampleRate: sampleRate)
            let mix = (a + b + c) / 3
            buffer[i] = Float(mix * amp * 0.4)
        }
    }
}

/// Karplus-Strong plucked string.
public struct KarplusStrongVoice: Sendable {
    private var delay: [Double] = []
    private var writeIndex = 0
    private var previous = 0.0
    public var damping: Double = 0.996
    public var ampSmoother: AudioParameterSmoother
    public var rng: SeededRNG
    public var active = false

    public init(sampleRate: Double = AudioConstants.defaultSampleRate, seed: UInt64 = 1) {
        ampSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 0)
        rng = SeededRNG(seed: seed)
    }

    public mutating func pluck(frequencyHz: Double, velocity: Double, sampleRate: Double) {
        let freq = max(frequencyHz, 20)
        let length = max(2, Int((sampleRate / freq).rounded()))
        delay = (0..<length).map { _ in rng.nextSigned() * velocity }
        writeIndex = 0
        previous = 0
        active = true
        ampSmoother.snap(velocity)
        ampSmoother.setTarget(velocity)
    }

    public mutating func noteOff() {
        ampSmoother.setTarget(0)
    }

    public mutating func apply(_ params: VoiceParams) {
        ampSmoother.setTarget(params.amplitude)
        if params.amplitude > 0.0001, delay.isEmpty {
            pluck(frequencyHz: params.bentFrequencyHz, velocity: params.amplitude, sampleRate: ampSmoother.sampleRate)
        }
        if params.amplitude <= 0.0001 {
            noteOff()
        }
    }

    public mutating func render(into buffer: inout [Float], sampleRate: Double) {
        _ = sampleRate
        if delay.isEmpty {
            for i in 0..<buffer.count { buffer[i] = 0 }
            return
        }
        for i in 0..<buffer.count {
            let amp = ampSmoother.next()
            let idx = writeIndex % delay.count
            let current = delay[idx]
            let filtered = 0.5 * (current + previous) * damping
            delay[idx] = filtered
            previous = current
            writeIndex = (writeIndex + 1) % delay.count
            buffer[i] = Float(current * amp * 0.6)
        }
    }
}

/// One-pole low-pass used by Filter Sweep. Resonance is a mild feedback.
public struct SubtractiveVoice: Sendable {
    private var osc = Oscillator(waveform: .saw)
    private var lp = 0.0
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

    public mutating func render(into buffer: inout [Float], sampleRate: Double) {
        let sr = max(sampleRate, 1)
        for i in 0..<buffer.count {
            let amp = ampSmoother.next()
            let cutoff = max(20, cutoffSmoother.next())
            let reso = min(0.95, max(0, resoSmoother.next()))
            let freq = freqSmoother.next()
            let raw = osc.next(frequencyHz: freq, sampleRate: sr)
            let coeff = 1 - exp(-2 * Double.pi * cutoff / sr)
            lp += coeff * (raw - lp + reso * lp)
            lp = min(1.5, max(-1.5, lp))
            buffer[i] = Float(lp * amp * 0.35)
        }
    }
}

public struct ThereminVoice: Sendable {
    private var osc = Oscillator(waveform: .sine)
    public var ampSmoother: AudioParameterSmoother
    public var freqSmoother: AudioParameterSmoother

    public init(sampleRate: Double = AudioConstants.defaultSampleRate) {
        ampSmoother = AudioParameterSmoother(sampleRate: sampleRate, timeSeconds: 0.03, value: 0)
        freqSmoother = AudioParameterSmoother(sampleRate: sampleRate, timeSeconds: 0.025, value: 440)
    }

    public mutating func apply(_ params: VoiceParams) {
        ampSmoother.setTarget(params.amplitude)
        freqSmoother.setTarget(params.bentFrequencyHz)
    }

    public mutating func render(into buffer: inout [Float], sampleRate: Double) {
        for i in 0..<buffer.count {
            let amp = ampSmoother.next()
            let freq = freqSmoother.next()
            buffer[i] = Float(osc.next(frequencyHz: freq, sampleRate: sampleRate) * amp * 0.5)
        }
    }
}

/// Simple sine used so the engine is audible end-to-end before real patches land.
public struct PlaceholderSineVoice: Sendable {
    private var osc = Oscillator(waveform: .sine)
    public var ampSmoother: AudioParameterSmoother
    public var freqSmoother: AudioParameterSmoother

    public init(sampleRate: Double = AudioConstants.defaultSampleRate) {
        ampSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 0)
        freqSmoother = AudioParameterSmoother(sampleRate: sampleRate, value: 440)
    }

    public mutating func apply(_ params: VoiceParams) {
        ampSmoother.setTarget(params.amplitude)
        freqSmoother.setTarget(params.bentFrequencyHz)
    }

    public mutating func render(into buffer: inout [Float], sampleRate: Double) {
        for i in 0..<buffer.count {
            let amp = ampSmoother.next()
            let freq = freqSmoother.next()
            buffer[i] = Float(osc.next(frequencyHz: freq, sampleRate: sampleRate) * amp * 0.5)
        }
    }
}
