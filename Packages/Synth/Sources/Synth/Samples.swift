import Foundation

/// Mono PCM sample with an optional sustain loop. Loaded on the main thread,
/// handed to the engine once, then only read on the audio thread.
public struct SampleBuffer: Sendable, Equatable {
    public var frames: [Float]
    public var sampleRate: Double
    /// MIDI note the sample was recorded at (A4 = 69 = 440 Hz).
    public var rootMIDINote: Double
    /// Sustain loop, `loopStart ..< loopEnd`. Equal values mean "no loop".
    public var loopStart: Int
    public var loopEnd: Int

    public init(frames: [Float], sampleRate: Double, rootMIDINote: Double, loopStart: Int? = nil, loopEnd: Int? = nil) {
        self.frames = frames
        self.sampleRate = sampleRate
        self.rootMIDINote = rootMIDINote
        let end = min(frames.count, max(0, loopEnd ?? frames.count))
        self.loopEnd = end
        self.loopStart = min(end, max(0, loopStart ?? 0))
    }

    public var rootHz: Double {
        440 * pow(2.0, (rootMIDINote - 69) / 12)
    }

    public var hasLoop: Bool { loopEnd - loopStart >= 4 }

    public var durationSeconds: Double {
        Double(frames.count) / max(sampleRate, 1)
    }
}

/// Plays a set of pitched, looped samples (one per root note). Picks the
/// nearest root for the requested pitch and crossfades 6 ms when the root
/// changes so note changes never click.
public struct LoopingSampler: Sendable {
    public private(set) var buffers: [SampleBuffer] = []
    private var current = -1
    private var previous = -1
    private var positionCurrent = 0.0
    private var positionPrevious = 0.0
    private var fade = 1.0

    public init() {}

    public var hasSamples: Bool { !buffers.isEmpty }

    /// Main thread only, before the buffers are rendered.
    public mutating func load(_ samples: [SampleBuffer]) {
        buffers = samples
            .filter { $0.hasLoop && $0.sampleRate > 0 }
            .sorted { $0.rootMIDINote < $1.rootMIDINote }
        current = -1
        previous = -1
        fade = 1
    }

    public func nearestIndex(forHz hz: Double) -> Int {
        guard !buffers.isEmpty else { return -1 }
        let target = max(hz, 1)
        var best = 0
        var bestDistance = Double.infinity
        for i in 0..<buffers.count {
            let distance = abs(log2(target / buffers[i].rootHz))
            if distance < bestDistance {
                bestDistance = distance
                best = i
            }
        }
        return best
    }

    public mutating func next(frequencyHz: Double, sampleRate: Double) -> Double {
        guard !buffers.isEmpty else { return 0 }
        let index = nearestIndex(forHz: frequencyHz)
        if index != current {
            previous = current
            positionPrevious = positionCurrent
            current = index
            positionCurrent = Double(buffers[index].loopStart)
            fade = previous >= 0 ? 0 : 1
        }
        var out = read(index: current, position: &positionCurrent, frequencyHz: frequencyHz, sampleRate: sampleRate)
        if fade < 1 {
            let old = previous >= 0
                ? read(index: previous, position: &positionPrevious, frequencyHz: frequencyHz, sampleRate: sampleRate)
                : 0
            fade = min(1, fade + 1 / (0.006 * max(sampleRate, 1)))
            out = out * fade + old * (1 - fade)
        }
        return out
    }

    private func frame(_ index: Int, at i: Int) -> Double {
        let start = buffers[index].loopStart
        let end = buffers[index].loopEnd
        var j = i
        if j >= end { j = start + (j - start) % (end - start) }
        if j < 0 { j = 0 }
        return Double(buffers[index].frames[j])
    }

    private func read(index: Int, position: inout Double, frequencyHz: Double, sampleRate: Double) -> Double {
        let base = Int(position)
        let t = position - Double(base)
        // 4-point Hermite interpolation.
        let xm1 = frame(index, at: base - 1)
        let x0 = frame(index, at: base)
        let x1 = frame(index, at: base + 1)
        let x2 = frame(index, at: base + 2)
        let c1 = 0.5 * (x1 - xm1)
        let c2 = xm1 - 2.5 * x0 + 2 * x1 - 0.5 * x2
        let c3 = 0.5 * (x2 - xm1) + 1.5 * (x0 - x1)
        let value = ((c3 * t + c2) * t + c1) * t + x0

        let rate = (max(frequencyHz, 1) / buffers[index].rootHz) * (buffers[index].sampleRate / max(sampleRate, 1))
        position += rate
        let start = Double(buffers[index].loopStart)
        let end = Double(buffers[index].loopEnd)
        while position >= end {
            position -= end - start
        }
        return value
    }
}

/// Engines that accept designed samples. Call from the main thread.
public protocol SampleLoading: AnyObject {
    func loadSamples(_ samples: [SampleBuffer], for kind: SynthVoiceKind)
}
