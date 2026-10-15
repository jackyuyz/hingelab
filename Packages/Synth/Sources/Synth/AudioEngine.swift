import Foundation

public protocol SynthRendering: Sendable {
    mutating func apply(_ params: VoiceParams)
    mutating func noteOn(frequencyHz: Double, velocity: Double)
    mutating func noteOff()
    /// Realtime entry point. Must not allocate or lock.
    mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, sampleRate: Double)
}

extension SynthRendering {
    /// Convenience for tests and offline rendering.
    public mutating func render(into buffer: inout [Float], sampleRate: Double) {
        buffer.withUnsafeMutableBufferPointer { pointer in
            render(into: pointer, sampleRate: sampleRate)
        }
    }
}

public protocol AudioEngineControlling: AnyObject, Sendable {
    var isRunning: Bool { get }
    var sampleRate: Double { get }
    var bufferFrames: Int { get }
    var lastRender: RenderBuffer? { get }
    func start() throws
    func stop()
    func setVoiceKind(_ kind: SynthVoiceKind)
    func setParameters(_ params: VoiceParams)
    func noteOn(frequencyHz: Double, velocity: Double)
    func noteOff()
    func setRelease(_ enabled: Bool)
}

public enum AudioEngineError: Error, Equatable, Sendable {
    case alreadyRunning
    case notRunning
}

public struct SynthBank: Sendable {
    public var kind: SynthVoiceKind
    public var sine: PlaceholderSineVoice
    public var reed: ReedVoice
    public var string: KarplusStrongVoice
    public var filter: SubtractiveVoice
    public var theremin: ThereminVoice
    public var releaseSmoother: AudioParameterSmoother
    public var releasing = false

    public init(kind: SynthVoiceKind = .placeholderSine, sampleRate: Double = AudioConstants.defaultSampleRate, seed: UInt64 = 1) {
        self.kind = kind
        self.sine = PlaceholderSineVoice(sampleRate: sampleRate)
        self.reed = ReedVoice(sampleRate: sampleRate)
        self.string = KarplusStrongVoice(sampleRate: sampleRate, seed: seed)
        self.filter = SubtractiveVoice(sampleRate: sampleRate)
        self.theremin = ThereminVoice(sampleRate: sampleRate)
        self.releaseSmoother = AudioParameterSmoother(sampleRate: sampleRate, timeSeconds: AudioConstants.closeReleaseSeconds, value: 1)
    }

    public mutating func apply(_ params: VoiceParams) {
        var p = params
        if releasing {
            p.amplitude *= max(0, releaseSmoother.current)
        }
        switch kind {
        case .placeholderSine: sine.apply(p)
        case .reed: reed.apply(p)
        case .karplusStrong: string.apply(p)
        case .subtractive: filter.apply(p)
        case .theremin: theremin.apply(p)
        }
    }

    public mutating func beginCloseRelease() {
        releasing = true
        releaseSmoother.snap(1)
        releaseSmoother.setTarget(0)
    }

    public mutating func render(into buffer: inout [Float], sampleRate: Double) {
        buffer.withUnsafeMutableBufferPointer { pointer in
            render(into: pointer, sampleRate: sampleRate)
        }
    }

    /// Realtime entry point used by the AVAudioEngine host. No allocations.
    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>, sampleRate: Double) {
        switch kind {
        case .placeholderSine: sine.render(into: buffer, sampleRate: sampleRate)
        case .reed: reed.render(into: buffer, sampleRate: sampleRate)
        case .karplusStrong: string.render(into: buffer, sampleRate: sampleRate)
        case .subtractive: filter.render(into: buffer, sampleRate: sampleRate)
        case .theremin: theremin.render(into: buffer, sampleRate: sampleRate)
        }
        if releasing {
            for i in 0..<buffer.count {
                let g = releaseSmoother.next()
                buffer[i] *= Float(g)
            }
            if releaseSmoother.current < 0.0001 {
                releasing = false
            }
        }
    }

    /// Main thread, before rendering. Reeds use every buffer as a root note;
    /// the guitar uses the first buffer as its pluck excitation.
    public mutating func loadSamples(_ samples: [SampleBuffer], for voice: SynthVoiceKind) {
        switch voice {
        case .reed: reed.sampler.load(samples)
        case .karplusStrong: string.excitation = samples.first
        case .placeholderSine, .subtractive, .theremin: break
        }
    }

    public mutating func noteOn(frequencyHz: Double, velocity: Double) {
        switch kind {
        case .karplusStrong:
            string.pluck(frequencyHz: frequencyHz, velocity: velocity, sampleRate: string.sampleRate)
        default:
            let p = VoiceParams(amplitude: velocity, frequencyHz: frequencyHz)
            apply(p)
        }
    }

    public mutating func noteOff() {
        let p = VoiceParams.silent
        apply(p)
        if kind == .karplusStrong {
            string.noteOff()
        }
    }
}

/// Offline engine used by unit tests and as the Linux stand-in for AVAudioEngine.
public final class OfflineAudioEngine: AudioEngineControlling, SampleLoading, @unchecked Sendable {
    public private(set) var isRunning = false
    public var sampleRate: Double
    public var bufferFrames: Int
    public private(set) var lastRender: RenderBuffer?
    private var bank: SynthBank
    private let mailbox = ParameterMailbox()
    private var kind: SynthVoiceKind

    public init(
        sampleRate: Double = AudioConstants.defaultSampleRate,
        bufferFrames: Int = AudioConstants.lowLatencyFrames,
        kind: SynthVoiceKind = .placeholderSine,
        seed: UInt64 = 1
    ) {
        self.sampleRate = sampleRate
        self.bufferFrames = bufferFrames
        self.kind = kind
        self.bank = SynthBank(kind: kind, sampleRate: sampleRate, seed: seed)
    }

    public func start() throws {
        if isRunning { throw AudioEngineError.alreadyRunning }
        isRunning = true
    }

    public func stop() {
        isRunning = false
    }

    public func setVoiceKind(_ kind: SynthVoiceKind) {
        self.kind = kind
        bank.kind = kind
    }

    public func setParameters(_ params: VoiceParams) {
        mailbox.publish(params)
    }

    public func noteOn(frequencyHz: Double, velocity: Double) {
        bank.noteOn(frequencyHz: frequencyHz, velocity: velocity)
        mailbox.publish(VoiceParams(amplitude: velocity, frequencyHz: frequencyHz))
    }

    public func noteOff() {
        bank.noteOff()
        mailbox.publish(.silent)
    }

    public func setRelease(_ enabled: Bool) {
        if enabled { bank.beginCloseRelease() }
    }

    public func loadSamples(_ samples: [SampleBuffer], for kind: SynthVoiceKind) {
        bank.loadSamples(samples, for: kind)
    }

    @discardableResult
    public func renderFrames(_ count: Int) -> RenderBuffer {
        let params = mailbox.load()
        bank.apply(params)
        var buffer = [Float](repeating: 0, count: count)
        bank.render(into: &buffer, sampleRate: sampleRate)
        let result = RenderBuffer(samples: buffer, sampleRate: sampleRate, channelCount: 1)
        lastRender = result
        return result
    }

    public func renderSeconds(_ seconds: Double) -> RenderBuffer {
        let frames = max(1, Int((seconds * sampleRate).rounded()))
        var all: [Float] = []
        all.reserveCapacity(frames)
        var remaining = frames
        while remaining > 0 {
            let chunk = min(bufferFrames, remaining)
            let rendered = renderFrames(chunk)
            all.append(contentsOf: rendered.samples)
            remaining -= chunk
        }
        let result = RenderBuffer(samples: all, sampleRate: sampleRate, channelCount: 1)
        lastRender = result
        return result
    }
}

/// Scripted hinge-style parameter automation for offline acceptance tests.
public struct ParameterAutomation: Sendable {
    public var timeSeconds: Double
    public var params: VoiceParams

    public init(timeSeconds: Double, params: VoiceParams) {
        self.timeSeconds = timeSeconds
        self.params = params
    }
}

extension OfflineAudioEngine {
    public func render(seconds: Double, automation: [ParameterAutomation]) -> RenderBuffer {
        let frames = max(1, Int((seconds * sampleRate).rounded()))
        var all: [Float] = []
        all.reserveCapacity(frames)
        var frame = 0
        var autoIndex = 0
        let sorted = automation.sorted { $0.timeSeconds < $1.timeSeconds }
        if let first = sorted.first, first.timeSeconds <= 0 {
            setParameters(first.params)
            autoIndex = 1
        }
        while frame < frames {
            let t = Double(frame) / sampleRate
            while autoIndex < sorted.count, sorted[autoIndex].timeSeconds <= t {
                setParameters(sorted[autoIndex].params)
                autoIndex += 1
            }
            let chunk = min(bufferFrames, frames - frame)
            all.append(contentsOf: renderFrames(chunk).samples)
            frame += chunk
        }
        let result = RenderBuffer(samples: all, sampleRate: sampleRate, channelCount: 1)
        lastRender = result
        return result
    }
}

/// Audio-session events mapped to engine actions. The AVAudioSession bridge
/// lives in the app; this policy is platform-independent.
public enum AudioSessionEvent: Equatable, Sendable {
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case headphonesUnplugged
    case bluetoothRoute
    case sampleRateChanged(Double)
    case cpuOverload
    case noOutputAvailable
}

public enum AudioSessionAction: Equatable, Sendable {
    case stopEngine
    case resumeEngine
    case pauseOutputForSafety
    case showBluetoothLatencyWarning
    case rebuildGraph(sampleRate: Double)
    case increaseBufferTo256
    case showNoOutput
    case none
}

public enum AudioSessionPolicy {
    public static func action(for event: AudioSessionEvent) -> AudioSessionAction {
        switch event {
        case .interruptionBegan:
            return .stopEngine
        case .interruptionEnded(let shouldResume):
            return shouldResume ? .resumeEngine : .none
        case .headphonesUnplugged:
            return .pauseOutputForSafety
        case .bluetoothRoute:
            return .showBluetoothLatencyWarning
        case .sampleRateChanged(let rate):
            return .rebuildGraph(sampleRate: rate)
        case .cpuOverload:
            return .increaseBufferTo256
        case .noOutputAvailable:
            return .showNoOutput
        }
    }
}
