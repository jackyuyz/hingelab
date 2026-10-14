import Foundation

/// Audio-thread one-pole smoother. Time constant is in seconds.
public struct AudioParameterSmoother: Sendable, Equatable {
    public var sampleRate: Double
    public var timeSeconds: Double
    public var current: Double
    public var target: Double

    public init(sampleRate: Double = AudioConstants.defaultSampleRate, timeSeconds: Double = AudioConstants.parameterRampSeconds, value: Double = 0) {
        self.sampleRate = sampleRate
        self.timeSeconds = timeSeconds
        self.current = value
        self.target = value
    }

    public var coefficient: Double {
        let sr = max(sampleRate, 1)
        let t = max(timeSeconds, 1.0 / sr)
        return 1 - exp(-1.0 / (t * sr))
    }

    public mutating func setTarget(_ value: Double) {
        target = value
    }

    public mutating func next() -> Double {
        current += coefficient * (target - current)
        return current
    }

    public mutating func process(into destination: inout [Double]) {
        for i in 0..<destination.count {
            destination[i] = next()
        }
    }

    public mutating func snap(_ value: Double) {
        current = value
        target = value
    }
}

/// Main-thread → audio-thread mailbox. Foundation uses a lock so packages stay
/// dependency-free on Linux. The iOS audio host should treat `load()` as the
/// only audio-thread read and never allocate.
public final class ParameterMailbox: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: VoiceParams

    public init(initial: VoiceParams = .silent) {
        self.snapshot = initial
    }

    public func publish(_ params: VoiceParams) {
        lock.lock()
        snapshot = params
        lock.unlock()
    }

    public func load() -> VoiceParams {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }
}
