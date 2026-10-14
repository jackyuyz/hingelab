import Foundation
import Synth

#if canImport(AVFoundation)
import AVFoundation

/// iOS host for AVAudioEngine. The engine graph is not allocated until `start()`.
/// Swap this in for `OfflineAudioEngine` in `HingeLabApp` once device audio is wired.
///
/// Render block rules: no allocations, no locks other than `ParameterMailbox.load()`,
/// no Swift arrays. DSP stays in `SynthBank`.
@MainActor
final class AVAudioEngineHost: AudioEngineControlling {
    private let inner: OfflineAudioEngine
    // TODO: Hold AVAudioEngine + AVAudioSourceNode here. Do not compile against
    // unverified Duo-only audio APIs.

    var isRunning: Bool { inner.isRunning }
    var sampleRate: Double { inner.sampleRate }
    var bufferFrames: Int { inner.bufferFrames }
    var lastRender: RenderBuffer? { inner.lastRender }

    init(bufferFrames: Int = AudioConstants.lowLatencyFrames) {
        inner = OfflineAudioEngine(bufferFrames: bufferFrames)
    }

    func start() throws {
        try inner.start()
        // Preferred IO buffer: 128 frames in Low latency (~2.7 ms @ 48 kHz).
        // Session category: .playback, mixWithOthers off.
        // Silent switch still plays (instrument).
    }

    func stop() { inner.stop() }
    func setVoiceKind(_ kind: SynthVoiceKind) { inner.setVoiceKind(kind) }
    func setParameters(_ params: VoiceParams) { inner.setParameters(params) }
    func noteOn(frequencyHz: Double, velocity: Double) { inner.noteOn(frequencyHz: frequencyHz, velocity: velocity) }
    func noteOff() { inner.noteOff() }
    func setRelease(_ enabled: Bool) { inner.setRelease(enabled) }
}
#else
typealias AVAudioEngineHost = OfflineAudioEngine
#endif
