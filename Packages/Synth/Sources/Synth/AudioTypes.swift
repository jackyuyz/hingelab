import Foundation

public enum AudioConstants: Sendable {
    public static let defaultSampleRate: Double = 48_000
    public static let lowLatencyFrames: Int = 128
    public static let normalLatencyFrames: Int = 256
    /// Audio-thread one-pole time constant when hinge samples are sparse.
    public static let parameterRampSeconds: Double = 0.02
    /// Gentle release when the device closes while notes are sounding.
    public static let closeReleaseSeconds: Double = 0.2
}

public struct RenderBuffer: Equatable, Sendable {
    public var samples: [Float]
    public var sampleRate: Double
    public var channelCount: Int

    public init(samples: [Float], sampleRate: Double, channelCount: Int = 1) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }

    public var frameCount: Int {
        guard channelCount > 0 else { return 0 }
        return samples.count / channelCount
    }

    public var peak: Float {
        samples.reduce(0) { max($0, abs($1)) }
    }

    public var rms: Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return sqrt(sum / Float(samples.count))
    }

    public var containsNaN: Bool {
        samples.contains { $0.isNaN || $0.isInfinite }
    }

    public var maxSampleToSampleJump: Float {
        guard samples.count > 1 else { return 0 }
        var best: Float = 0
        for i in 1..<samples.count {
            best = max(best, abs(samples[i] - samples[i - 1]))
        }
        return best
    }
}

public struct VoiceParams: Equatable, Sendable {
    public var amplitude: Double
    public var frequencyHz: Double
    public var cutoffHz: Double
    public var resonance: Double
    public var pitchBendSemitones: Double
    public var detuneCents: Double

    public init(
        amplitude: Double = 0,
        frequencyHz: Double = 440,
        cutoffHz: Double = 8_000,
        resonance: Double = 0.2,
        pitchBendSemitones: Double = 0,
        detuneCents: Double = 0
    ) {
        self.amplitude = amplitude
        self.frequencyHz = frequencyHz
        self.cutoffHz = cutoffHz
        self.resonance = resonance
        self.pitchBendSemitones = pitchBendSemitones
        self.detuneCents = detuneCents
    }

    public static let silent = VoiceParams()

    public var bentFrequencyHz: Double {
        frequencyHz * pow(2.0, (pitchBendSemitones + detuneCents / 100.0) / 12.0)
    }
}

public enum SynthVoiceKind: String, Sendable, CaseIterable {
    case placeholderSine
    case reed
    case karplusStrong
    case subtractive
    case theremin
}
