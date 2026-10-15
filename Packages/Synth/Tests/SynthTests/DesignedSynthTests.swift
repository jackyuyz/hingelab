import Testing
import Foundation
@testable import Synth

@Suite("CAF codec")
struct CAFCodecTests {
    @Test("Round-trips 24-bit and 16-bit PCM with loop and base note")
    func roundTrip() throws {
        let frames: [Float] = (0..<4_800).map { Float(sin(Double($0) * 0.05) * 0.8) }
        for bits in [16, 24] {
            let data = CAFCodec.encode(frames: frames, sampleRate: 48_000, bitsPerChannel: bits, loopStart: 480, loopEnd: 4_000, baseNote: 57)
            let decoded = try CAFCodec.decode(data)
            #expect(decoded.sampleRate == 48_000)
            #expect(decoded.channelCount == 1)
            #expect(decoded.bitsPerChannel == bits)
            #expect(decoded.frames.count == frames.count)
            #expect(decoded.loopStart == 480)
            #expect(decoded.loopEnd == 4_000)
            #expect(decoded.baseNote == 57)
            let tolerance: Float = bits == 24 ? 1e-6 : 1e-4
            for i in stride(from: 0, to: frames.count, by: 97) {
                #expect(abs(decoded.frames[i] - frames[i]) < tolerance)
            }
        }
    }

    @Test("Rejects non-CAF data")
    func rejects() {
        #expect(throws: CAFCodec.DecodeError.notCAF) {
            try CAFCodec.decode(Data("RIFF....WAVE".utf8))
        }
    }
}

/// The CAF files shipped in the app bundle (spec: audio-design-spec.md).
@Suite("Built-in reed samples")
struct BuiltinSampleTests {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SynthTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // Synth
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo
        .appendingPathComponent("App/Resources/Samples")

    static let expected: [(name: String, note: Double)] = [
        ("hl_builtin_accordion_C3_reed", 48),
        ("hl_builtin_accordion_G3_reed", 55),
        ("hl_builtin_accordion_C4_reed", 60),
        ("hl_builtin_accordion_G4_reed", 67),
    ]

    @Test("Format, loop length, headroom, root note")
    func format() throws {
        for item in Self.expected {
            let url = Self.directory.appendingPathComponent("\(item.name).caf")
            let decoded = try CAFCodec.decode(try Data(contentsOf: url))
            #expect(decoded.sampleRate == 48_000, "\(item.name)")
            #expect(decoded.channelCount == 1, "\(item.name)")
            #expect(decoded.bitsPerChannel == 24, "\(item.name)")
            #expect(decoded.baseNote == item.note, "\(item.name)")
            let start = try #require(decoded.loopStart)
            let end = try #require(decoded.loopEnd)
            let loopSeconds = Double(end - start) / decoded.sampleRate
            #expect((0.4...0.81).contains(loopSeconds), "\(item.name) loop \(loopSeconds)")
            let peak = decoded.frames.reduce(Float(0)) { max($0, abs($1)) }
            #expect(peak < 0.966, "\(item.name) peak above −0.3 dBFS")
            #expect(!decoded.frames.contains { $0.isNaN })
        }
    }

    @Test("Loop seam is no bigger than an ordinary step inside the loop")
    func seamless() throws {
        for item in Self.expected {
            let url = Self.directory.appendingPathComponent("\(item.name).caf")
            let decoded = try CAFCodec.decode(try Data(contentsOf: url))
            let start = try #require(decoded.loopStart)
            let end = try #require(decoded.loopEnd)
            var largestStep: Float = 0
            for i in (start + 1)..<end {
                largestStep = max(largestStep, abs(decoded.frames[i] - decoded.frames[i - 1]))
            }
            let seam = abs(decoded.frames[start] - decoded.frames[end - 1])
            #expect(seam <= largestStep * 1.05, "\(item.name) seam \(seam) vs \(largestStep)")
        }
    }

    @Test("Sampler plays the shipped reeds in tune")
    func samplerPitch() throws {
        var buffers: [SampleBuffer] = []
        for item in Self.expected {
            let url = Self.directory.appendingPathComponent("\(item.name).caf")
            buffers.append(try CAFCodec.decode(try Data(contentsOf: url)).sampleBuffer(defaultRootMIDINote: item.note))
        }
        let engine = OfflineAudioEngine(kind: .reed)
        engine.loadSamples(buffers, for: .reed)
        // A3 is between the C3 and C4 roots: exercises repitching.
        engine.setParameters(VoiceParams(amplitude: 0.8, frequencyHz: 220))
        _ = engine.renderSeconds(0.2)
        let rendered = engine.renderSeconds(1.2)
        #expect(!rendered.containsNaN)
        #expect(rendered.peak < 1.0)
        let hz = estimatePitch(rendered.samples, sampleRate: 48_000, minHz: 150, maxHz: 400)
        #expect(abs(1200 * log2(hz / 220)) < 10, "estimated \(hz) Hz")
    }
}

@Suite("Designed voices")
struct DesignedVoiceTests {
    @Test("Guitar bend follows the hinge while the string rings")
    func guitarBend() {
        let engine = OfflineAudioEngine(kind: .karplusStrong, seed: 7)
        engine.noteOn(frequencyHz: 110, velocity: 0.9)
        engine.setParameters(VoiceParams(amplitude: 0.9, frequencyHz: 110, pitchBendSemitones: 0))
        let open = engine.renderSeconds(0.3).samples
        engine.setParameters(VoiceParams(amplitude: 0.9, frequencyHz: 110, pitchBendSemitones: 2))
        _ = engine.renderSeconds(0.1)
        let bent = engine.renderSeconds(0.3).samples
        let f0 = estimatePitch(open, sampleRate: 48_000, minHz: 80, maxHz: 160)
        let f1 = estimatePitch(bent, sampleRate: 48_000, minHz: 80, maxHz: 160)
        let cents = 1200 * log2(f1 / f0)
        #expect(abs(cents - 200) < 15, "bend \(cents) cents")
    }

    @Test("A strum rings on several strings at once")
    func strumPolyphony() {
        func level(strings: Int) -> Float {
            let engine = OfflineAudioEngine(kind: .karplusStrong, seed: 3)
            let notes: [Double] = [82.4, 110, 146.8, 196, 246.9, 329.6]
            for hz in notes.prefix(strings) {
                engine.noteOn(frequencyHz: hz, velocity: 0.7)
                _ = engine.renderSeconds(0.01)
            }
            engine.setParameters(VoiceParams(amplitude: 0.7))
            _ = engine.renderSeconds(0.2)
            return engine.renderSeconds(0.2).rms
        }
        #expect(level(strings: 6) > level(strings: 1) * 1.5)
    }

    @Test("Lifting the fingers lets strings ring out without a click")
    func guitarReleaseNoClick() {
        let engine = OfflineAudioEngine(kind: .karplusStrong, seed: 5)
        engine.noteOn(frequencyHz: 196, velocity: 0.9)
        engine.setParameters(VoiceParams(amplitude: 0.9))
        let before = engine.renderSeconds(0.1)
        engine.noteOff()
        let after = engine.renderSeconds(1.5)
        #expect(after.maxSampleToSampleJump < max(0.1, before.maxSampleToSampleJump * 1.2))
        #expect(after.samples.suffix(4_800).map { abs($0) }.max() ?? 1 < 0.02)
    }

    @Test("Extreme parameters stay finite and below full scale")
    func extremes() {
        let cases: [VoiceParams] = [
            VoiceParams(amplitude: 1, frequencyHz: 20, cutoffHz: 20, resonance: 1),
            VoiceParams(amplitude: 1, frequencyHz: 4_000, cutoffHz: 20_000, resonance: 1),
            VoiceParams(amplitude: 1, frequencyHz: 440, cutoffHz: 23_000, resonance: 0, pitchBendSemitones: 12),
        ]
        for kind in SynthVoiceKind.allCases {
            for params in cases {
                let engine = OfflineAudioEngine(kind: kind, seed: 11)
                if kind == .karplusStrong { engine.noteOn(frequencyHz: params.frequencyHz, velocity: 1) }
                engine.setParameters(params)
                let rendered = engine.renderSeconds(0.3)
                #expect(!rendered.containsNaN, "\(kind) \(params)")
                #expect(rendered.peak < 1.0, "\(kind) peak \(rendered.peak)")
            }
        }
    }

    @Test("Higher resonance boosts energy at the cutoff")
    func resonancePeak() {
        func bandEnergy(resonance: Double) -> Double {
            let engine = OfflineAudioEngine(kind: .subtractive)
            engine.setParameters(VoiceParams(amplitude: 0.8, frequencyHz: 55, cutoffHz: 1_000, resonance: resonance))
            _ = engine.renderSeconds(0.1)
            let samples = engine.renderSeconds(0.1).samples
            return goertzelEnergy(samples, hz: 990, sampleRate: 48_000)
                + goertzelEnergy(samples, hz: 1_045, sampleRate: 48_000)
        }
        #expect(bandEnergy(resonance: 0.9) > bandEnergy(resonance: 0.05) * 2)
    }

    @Test("Reed voice stays in tune without samples")
    func reedPitch() {
        let engine = OfflineAudioEngine(kind: .reed)
        engine.setParameters(VoiceParams(amplitude: 0.8, frequencyHz: 261.63))
        _ = engine.renderSeconds(0.2)
        let hz = estimatePitch(engine.renderSeconds(0.5).samples, sampleRate: 48_000, minHz: 180, maxHz: 400)
        #expect(abs(1200 * log2(hz / 261.63)) < 10)
    }

    @Test("Realtime render path matches the array path")
    func pointerPathMatches() {
        var a = SynthBank(kind: .theremin)
        var b = SynthBank(kind: .theremin)
        let p = VoiceParams(amplitude: 0.7, frequencyHz: 330)
        a.apply(p)
        b.apply(p)
        var arrayBuffer = [Float](repeating: 0, count: 256)
        a.render(into: &arrayBuffer, sampleRate: 48_000)
        let pointer = UnsafeMutableBufferPointer<Float>.allocate(capacity: 256)
        defer { pointer.deallocate() }
        pointer.initialize(repeating: 0)
        b.render(into: pointer, sampleRate: 48_000)
        #expect(Array(pointer) == arrayBuffer)
    }
}

/// Autocorrelation pitch estimate with parabolic peak refinement.
func estimatePitch(_ samples: [Float], sampleRate: Double, minHz: Double, maxHz: Double) -> Double {
    let x = samples.map(Double.init)
    let minLag = Int(sampleRate / maxHz)
    let maxLag = Int(sampleRate / minHz)
    let n = min(x.count - maxLag - 1, 16_384)
    guard n > 0 else { return 0 }
    func r(_ lag: Int) -> Double {
        var sum = 0.0
        for i in 0..<n { sum += x[i] * x[i + lag] }
        return sum
    }
    var bestLag = minLag
    var best = -Double.infinity
    var values: [Int: Double] = [:]
    for lag in minLag...maxLag {
        let v = r(lag)
        values[lag] = v
        if v > best {
            best = v
            bestLag = lag
        }
    }
    let y0 = values[bestLag - 1] ?? r(bestLag - 1)
    let y1 = best
    let y2 = values[bestLag + 1] ?? r(bestLag + 1)
    let denom = y0 - 2 * y1 + y2
    let shift = denom == 0 ? 0 : 0.5 * (y0 - y2) / denom
    return sampleRate / (Double(bestLag) + shift)
}

func goertzelEnergy(_ samples: [Float], hz: Double, sampleRate: Double) -> Double {
    let w = 2 * Double.pi * hz / sampleRate
    let coeff = 2 * cos(w)
    var s1 = 0.0
    var s2 = 0.0
    for sample in samples {
        let s0 = Double(sample) + coeff * s1 - s2
        s2 = s1
        s1 = s0
    }
    return s1 * s1 + s2 * s2 - coeff * s1 * s2
}
