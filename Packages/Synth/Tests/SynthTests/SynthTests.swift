import Testing
import Foundation
@testable import Synth

@Suite("Parameter smoother")
struct ParameterSmootherTests {
    @Test("No step larger than the coefficient allows")
    func noLargeSteps() {
        var smoother = AudioParameterSmoother(sampleRate: 48_000, timeSeconds: 0.02, value: 0)
        smoother.setTarget(1)
        var previous = 0.0
        var maxJump = 0.0
        // ~5 time constants at 20 ms / 48 kHz ≈ 4800 frames
        for _ in 0..<4800 {
            let next = smoother.next()
            maxJump = max(maxJump, abs(next - previous))
            previous = next
        }
        #expect(maxJump < 0.05)
        #expect(smoother.current > 0.9)
    }

    @Test("Mailbox round-trips")
    func mailbox() {
        let box = ParameterMailbox(initial: .silent)
        box.publish(VoiceParams(amplitude: 0.5, frequencyHz: 220))
        #expect(box.load().amplitude == 0.5)
        #expect(box.load().frequencyHz == 220)
    }
}

@Suite("Render buffer analysis")
struct RenderBufferTests {
    @Test("Detects NaN, peak, RMS, jumps")
    func analysis() {
        let buffer = RenderBuffer(samples: [0, 0.5, -0.5, 0.25], sampleRate: 48_000)
        #expect(buffer.peak == 0.5)
        #expect(buffer.rms > 0)
        #expect(!buffer.containsNaN)
        #expect(buffer.maxSampleToSampleJump == 1.0)

        let bad = RenderBuffer(samples: [0, Float.nan], sampleRate: 48_000)
        #expect(bad.containsNaN)
    }
}

@Suite("Offline synth render")
struct OfflineSynthTests {
    @Test("Placeholder sine is non-silent, unclipped, finite")
    func placeholderSine() {
        let engine = OfflineAudioEngine(kind: .placeholderSine)
        try? engine.start()
        engine.setParameters(VoiceParams(amplitude: 0.8, frequencyHz: 440))
        let rendered = engine.renderSeconds(0.25)
        #expect(!rendered.containsNaN)
        #expect(rendered.peak < 1.0)
        #expect(rendered.rms > 0.01)
    }

    @Test("Reed, KS, subtractive, theremin all render")
    func allVoices() {
        for kind in SynthVoiceKind.allCases {
            let engine = OfflineAudioEngine(kind: kind, seed: 42)
            try? engine.start()
            if kind == .karplusStrong {
                engine.noteOn(frequencyHz: 220, velocity: 0.8)
            } else {
                engine.setParameters(VoiceParams(amplitude: 0.7, frequencyHz: 220, cutoffHz: 2_000, resonance: 0.3))
            }
            let rendered = engine.renderSeconds(0.2)
            #expect(!rendered.containsNaN, "NaN in \(kind)")
            #expect(rendered.peak < 1.0, "clip in \(kind)")
            #expect(rendered.rms > 0.001, "silent \(kind)")
        }
    }

    @Test("Karplus-Strong is deterministic for a seed")
    func karplusDeterministic() {
        func render() -> [Float] {
            let engine = OfflineAudioEngine(kind: .karplusStrong, seed: 99)
            engine.noteOn(frequencyHz: 110, velocity: 0.9)
            return engine.renderSeconds(0.1).samples
        }
        let a = render()
        let b = render()
        #expect(a == b)
        let rms = RenderBuffer(samples: a, sampleRate: 48_000).rms
        #expect(rms > 0.01)
    }

    @Test("Cutoff sweep raises spectral centroid")
    func cutoffSweepCentroid() {
        func centroid(cutoff: Double) -> Double {
            let engine = OfflineAudioEngine(kind: .subtractive)
            engine.setParameters(VoiceParams(amplitude: 0.8, frequencyHz: 110, cutoffHz: cutoff, resonance: 0.1))
            let samples = engine.renderSeconds(0.15).samples
            return spectralCentroid(samples, sampleRate: 48_000)
        }
        let low = centroid(cutoff: 200)
        let high = centroid(cutoff: 8_000)
        #expect(high > low)
    }

    @Test("Closing while playing does not click")
    func closeRelease() {
        let engine = OfflineAudioEngine(kind: .placeholderSine)
        engine.setParameters(VoiceParams(amplitude: 0.8, frequencyHz: 440))
        _ = engine.renderSeconds(0.05)
        engine.setRelease(true)
        engine.setParameters(VoiceParams(amplitude: 0.8, frequencyHz: 440))
        let rendered = engine.renderSeconds(0.25)
        #expect(!rendered.containsNaN)
        #expect(rendered.maxSampleToSampleJump < 0.1)
        #expect(abs(rendered.samples.last ?? 1) < 0.05)
    }
}

@Suite("Audio session policy")
struct AudioSessionPolicyTests {
    @Test("Maps interruption, route, overload")
    func mapping() {
        #expect(AudioSessionPolicy.action(for: .interruptionBegan) == .stopEngine)
        #expect(AudioSessionPolicy.action(for: .interruptionEnded(shouldResume: true)) == .resumeEngine)
        #expect(AudioSessionPolicy.action(for: .interruptionEnded(shouldResume: false)) == .none)
        #expect(AudioSessionPolicy.action(for: .headphonesUnplugged) == .pauseOutputForSafety)
        #expect(AudioSessionPolicy.action(for: .bluetoothRoute) == .showBluetoothLatencyWarning)
        #expect(AudioSessionPolicy.action(for: .sampleRateChanged(44_100)) == .rebuildGraph(sampleRate: 44_100))
        #expect(AudioSessionPolicy.action(for: .cpuOverload) == .increaseBufferTo256)
        #expect(AudioSessionPolicy.action(for: .noOutputAvailable) == .showNoOutput)
    }
}

func spectralCentroid(_ samples: [Float], sampleRate: Double) -> Double {
    let n = 1 << 10
    let slice = Array(samples.prefix(n))
    guard slice.count >= 64 else { return 0 }
    var real = slice.map { Double($0) }
    real += [Double](repeating: 0, count: n - real.count)
    var mag = [Double](repeating: 0, count: n / 2)
    for k in 0..<(n / 2) {
        var re = 0.0
        var im = 0.0
        let w = 2 * Double.pi * Double(k) / Double(n)
        for i in 0..<n {
            let angle = w * Double(i)
            re += real[i] * cos(angle)
            im -= real[i] * sin(angle)
        }
        mag[k] = sqrt(re * re + im * im)
    }
    var weighted = 0.0
    var total = 0.0
    for k in 1..<mag.count {
        let f = Double(k) * sampleRate / Double(n)
        weighted += f * mag[k]
        total += mag[k]
    }
    guard total > 0 else { return 0 }
    return weighted / total
}
