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

/// Simple sine used so the engine is audible end-to-end before real patches land.
public struct PlaceholderSineVoice: SynthRendering {
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

    public mutating func noteOn(frequencyHz: Double, velocity: Double) {
        apply(VoiceParams(amplitude: velocity, frequencyHz: frequencyHz))
    }

    public mutating func noteOff() {
        ampSmoother.setTarget(0)
    }

    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, sampleRate: Double) {
        for i in 0..<buffer.count {
            let amp = ampSmoother.next()
            let freq = freqSmoother.next()
            buffer[i] = Float(osc.next(frequencyHz: freq, sampleRate: sampleRate) * amp * 0.5)
        }
    }
}
