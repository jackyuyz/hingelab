import Foundation
import Synth

#if canImport(AVFoundation)
import AVFoundation
import os

/// The synth state shared with the audio thread. Main-thread calls take the
/// unfair lock for a few microseconds (no allocation inside, except loading
/// samples before playback); the render block takes it once per buffer.
final class RealtimeSynth: @unchecked Sendable {
    private let state: OSAllocatedUnfairLock<SynthBank>

    init(kind: SynthVoiceKind, sampleRate: Double) {
        state = OSAllocatedUnfairLock(uncheckedState: SynthBank(kind: kind, sampleRate: sampleRate))
    }

    func mutate(_ body: (inout SynthBank) -> Void) {
        state.withLockUnchecked { bank in body(&bank) }
    }

    /// Audio thread. No allocation: renders straight into the output buffer.
    func render(into buffer: UnsafeMutableBufferPointer<Float>, sampleRate: Double) {
        state.withLockUnchecked { bank in
            bank.render(into: buffer, sampleRate: sampleRate)
        }
    }
}

/// iOS host for AVAudioEngine: one `AVAudioSourceNode` pulling `SynthBank`.
///
/// Render block rules: no allocations, no Swift array growth, no Objective-C
/// messaging; DSP stays in `SynthBank`. Called from the main thread only
/// (AppModel is @MainActor); the class is not actor-isolated so it can satisfy
/// the package protocols.
final class AVAudioEngineHost: AudioEngineControlling, SampleLoading, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var synth: RealtimeSynth?
    private var graphSampleRate: Double = 0
    private var kind: SynthVoiceKind = .placeholderSine
    private var pendingSamples: [SynthVoiceKind: [SampleBuffer]] = [:]
    private var lastParams: VoiceParams = .silent
    private var observers: [NSObjectProtocol] = []
    private(set) var bufferFrames: Int

    /// Interruptions and route changes, mapped to the package's events.
    var onSessionEvent: (@MainActor (AudioSessionEvent) -> Void)?

    init(bufferFrames: Int = AudioConstants.lowLatencyFrames) {
        self.bufferFrames = bufferFrames
        observeSession()
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    var isRunning: Bool { engine.isRunning }
    var sampleRate: Double { graphSampleRate > 0 ? graphSampleRate : AudioConstants.defaultSampleRate }
    /// TODO: Looper capture needs an output tap into a preallocated ring
    /// buffer (milestone: real AVAudioEngine graph). Nil until then.
    var lastRender: RenderBuffer? { nil }

    func setBufferFrames(_ frames: Int) {
        bufferFrames = frames
        try? AVAudioSession.sharedInstance().setPreferredIOBufferDuration(Double(frames) / sampleRate)
    }

    func start() throws {
        if engine.isRunning { throw AudioEngineError.alreadyRunning }
        let session = AVAudioSession.sharedInstance()
        // An instrument plays with the silent switch on and does not mix.
        try session.setCategory(.playback, mode: .default, options: [])
        try? session.setPreferredSampleRate(AudioConstants.defaultSampleRate)
        try? session.setPreferredIOBufferDuration(Double(bufferFrames) / AudioConstants.defaultSampleRate)
        try session.setActive(true)
        let rate = session.sampleRate > 0 ? session.sampleRate : AudioConstants.defaultSampleRate
        if sourceNode == nil || rate != graphSampleRate {
            buildGraph(sampleRate: rate)
        }
        engine.prepare()
        try engine.start()
        if session.currentRoute.outputs.contains(where: { Self.isBluetooth($0.portType) }) {
            deliver(.bluetoothRoute)
        }
    }

    func stop() {
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func setVoiceKind(_ kind: SynthVoiceKind) {
        self.kind = kind
        synth?.mutate { $0.kind = kind }
    }

    func setParameters(_ params: VoiceParams) {
        lastParams = params
        synth?.mutate { $0.apply(params) }
    }

    func noteOn(frequencyHz: Double, velocity: Double) {
        synth?.mutate { $0.noteOn(frequencyHz: frequencyHz, velocity: velocity) }
    }

    func noteOff() {
        synth?.mutate { $0.noteOff() }
    }

    func setRelease(_ enabled: Bool) {
        guard enabled else { return }
        synth?.mutate { $0.beginCloseRelease() }
    }

    func loadSamples(_ samples: [SampleBuffer], for kind: SynthVoiceKind) {
        pendingSamples[kind] = samples
        synth?.mutate { $0.loadSamples(samples, for: kind) }
    }

    // MARK: Graph

    private func buildGraph(sampleRate: Double) {
        if let old = sourceNode {
            engine.detach(old)
        }
        let synth = RealtimeSynth(kind: kind, sampleRate: sampleRate)
        for (voice, samples) in pendingSamples {
            synth.mutate { $0.loadSamples(samples, for: voice) }
        }
        let params = lastParams
        synth.mutate { $0.apply(params) }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let node = Self.makeSourceNode(synth: synth, format: format)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.9
        self.synth = synth
        self.sourceNode = node
        self.graphSampleRate = sampleRate
    }

    /// Built in a nonisolated static context so the render closure carries no
    /// actor isolation (it runs on the realtime audio thread).
    private static func makeSourceNode(synth: RealtimeSynth, format: AVAudioFormat) -> AVAudioSourceNode {
        let rate = format.sampleRate
        return AVAudioSourceNode(format: format) { isSilence, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let first = buffers.first, let data = first.mData else { return noErr }
            let frames = Int(frameCount)
            let output = UnsafeMutableBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: frames)
            synth.render(into: output, sampleRate: rate)
            if buffers.count > 1 {
                for index in 1..<buffers.count {
                    buffers[index].mData?.copyMemory(from: data, byteCount: frames * MemoryLayout<Float>.size)
                }
            }
            isSilence.pointee = false
            return noErr
        }
    }

    // MARK: Session events

    private func observeSession() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        // Closures look the session up again: AVAudioSession is not Sendable.
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            guard let event = Self.interruptionEvent(note.userInfo) else { return }
            self?.deliver(event)
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] note in
            let route = AVAudioSession.sharedInstance().currentRoute
            guard let event = Self.routeEvent(note.userInfo, route: route) else { return }
            self?.deliver(event)
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.sourceNode = nil
            self.deliver(.sampleRateChanged(AVAudioSession.sharedInstance().sampleRate))
        })
    }

    private func deliver(_ event: AudioSessionEvent) {
        let handler = onSessionEvent
        MainActor.assumeIsolated {
            handler?(event)
        }
    }

    private static func interruptionEvent(_ info: [AnyHashable: Any]?) -> AudioSessionEvent? {
        guard let raw = info?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return nil }
        switch type {
        case .began:
            return .interruptionBegan
        case .ended:
            let optionsRaw = info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            return .interruptionEnded(shouldResume: options.contains(.shouldResume))
        @unknown default:
            return nil
        }
    }

    private static func routeEvent(_ info: [AnyHashable: Any]?, route: AVAudioSessionRouteDescription) -> AudioSessionEvent? {
        guard let raw = info?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return nil }
        switch reason {
        case .oldDeviceUnavailable:
            return .headphonesUnplugged
        case .newDeviceAvailable, .override, .categoryChange:
            if route.outputs.isEmpty { return .noOutputAvailable }
            return route.outputs.contains(where: { isBluetooth($0.portType) }) ? .bluetoothRoute : nil
        default:
            return route.outputs.isEmpty ? .noOutputAvailable : nil
        }
    }

    private static func isBluetooth(_ port: AVAudioSession.Port) -> Bool {
        port == .bluetoothA2DP || port == .bluetoothLE || port == .bluetoothHFP
    }
}
#else
typealias AVAudioEngineHost = OfflineAudioEngine
#endif
