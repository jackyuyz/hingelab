import Foundation
import Synth

public struct Loop: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var fileName: String
    public var bars: Int
    public var bpm: Double
    public var createdAt: Date
    public var durationSeconds: Double

    public init(
        id: UUID = UUID(),
        fileName: String,
        bars: Int = 4,
        bpm: Double = 120,
        createdAt: Date = .now,
        durationSeconds: Double = 0
    ) {
        self.id = id
        self.fileName = fileName
        self.bars = bars
        self.bpm = bpm
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
    }
}

public enum LoopLimits {
    public static let maxDurationSeconds: Double = 5 * 60
    public static let freeTrackCount = 1
    public static let proTrackCount = 8

    public static func maxTracks(isPro: Bool) -> Int {
        isPro ? proTrackCount : freeTrackCount
    }

    public static func maxFrames(sampleRate: Double) -> Int {
        Int(maxDurationSeconds * sampleRate)
    }
}

public enum LoopState: String, Sendable, Equatable {
    case empty
    case recording
    case overdubbing
    case playing
    case stopped
    case saving
    case exportFailed
}

public struct LoopError: Error, Equatable, Sendable {
    public var kind: Kind
    public init(_ kind: Kind) { self.kind = kind }

    public enum Kind: Equatable, Sendable {
        case memoryCap
        case diskFull
        case noAudio
        case trackLimit
    }
}

public final class LoopBuffer: @unchecked Sendable {
    public private(set) var samples: [Float]
    public let capacity: Int
    public private(set) var writeIndex = 0
    public private(set) var filled = 0
    public var sampleRate: Double

    public init(capacity: Int, sampleRate: Double = AudioConstants.defaultSampleRate) {
        self.capacity = max(1, capacity)
        self.samples = [Float](repeating: 0, count: max(1, capacity))
        self.sampleRate = sampleRate
    }

    public var isFull: Bool { filled >= capacity }

    @discardableResult
    public func write(_ incoming: [Float]) -> LoopError? {
        if incoming.isEmpty { return nil }
        if filled >= capacity { return LoopError(.memoryCap) }
        for sample in incoming {
            if filled >= capacity { return LoopError(.memoryCap) }
            samples[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
            filled += 1
        }
        return nil
    }

    public func readAll() -> [Float] {
        Array(samples.prefix(filled))
    }

    public func overdub(_ incoming: [Float], mix: Float = 1) {
        guard filled > 0 else {
            _ = write(incoming)
            return
        }
        let existing = readAll()
        var mixed = existing
        for i in 0..<incoming.count {
            let idx = i % max(existing.count, 1)
            if idx < mixed.count {
                mixed[idx] = max(-1, min(1, mixed[idx] + incoming[i] * mix))
            }
        }
        samples = mixed + [Float](repeating: 0, count: max(0, capacity - mixed.count))
        filled = mixed.count
        writeIndex = mixed.count % capacity
    }

    public func clear() {
        samples = [Float](repeating: 0, count: capacity)
        writeIndex = 0
        filled = 0
    }

    public var durationSeconds: Double {
        Double(filled) / max(sampleRate, 1)
    }
}

public enum WAVEncoder {
    public static func encode(_ samples: [Float], sampleRate: Double, channels: Int = 1) -> Data {
        let sr = UInt32(sampleRate.rounded())
        let ch = UInt16(max(1, channels))
        var pcm = [Int16](repeating: 0, count: samples.count)
        for i in 0..<samples.count {
            let clipped = max(-1, min(1, samples[i]))
            pcm[i] = Int16((clipped * Float(Int16.max)).rounded())
        }
        var data = Data()
        func ascii(_ s: String) { data.append(contentsOf: s.utf8) }
        func u16(_ v: UInt16) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func u32(_ v: UInt32) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        ascii("RIFF")
        u32(UInt32(36 + pcm.count * 2))
        ascii("WAVE")
        ascii("fmt ")
        u32(16)
        u16(1)
        u16(ch)
        u32(sr)
        u32(sr * UInt32(ch) * 2)
        u16(ch * 2)
        u16(16)
        ascii("data")
        u32(UInt32(pcm.count * 2))
        for s in pcm {
            var le = s.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        return data
    }
}

public final class LoopRecorder: @unchecked Sendable {
    public private(set) var state: LoopState = .empty
    public private(set) var tracks: [Loop] = []
    public var isPro: Bool
    public let sampleRate: Double
    public var bpm: Double
    public private(set) var activeBuffer: LoopBuffer
    public var lastError: LoopError?

    public init(isPro: Bool = false, sampleRate: Double = AudioConstants.defaultSampleRate, bpm: Double = 120) {
        self.isPro = isPro
        self.sampleRate = sampleRate
        self.bpm = bpm
        self.activeBuffer = LoopBuffer(capacity: LoopLimits.maxFrames(sampleRate: sampleRate), sampleRate: sampleRate)
    }

    public var maxTracks: Int { LoopLimits.maxTracks(isPro: isPro) }

    public func beginRecording() -> LoopError? {
        if tracks.count >= maxTracks { return LoopError(.trackLimit) }
        activeBuffer.clear()
        state = .recording
        lastError = nil
        return nil
    }

    public func append(_ samples: [Float]) -> LoopError? {
        guard state == .recording || state == .overdubbing else { return nil }
        if let error = activeBuffer.write(samples) {
            lastError = error
            state = .exportFailed
            return error
        }
        return nil
    }

    public func stopRecording() -> Loop {
        state = .stopped
        let loop = Loop(
            fileName: "loop-\(UUID().uuidString).wav",
            bars: 4,
            bpm: bpm,
            durationSeconds: activeBuffer.durationSeconds
        )
        tracks.append(loop)
        return loop
    }

    public func beginOverdub() {
        state = .overdubbing
    }

    public func mixOverdub(_ samples: [Float]) {
        activeBuffer.overdub(samples)
        state = .stopped
    }

    public func exportWAV() throws -> Data {
        let samples = activeBuffer.readAll()
        guard !samples.isEmpty else { throw LoopError(.noAudio) }
        state = .saving
        let data = WAVEncoder.encode(samples, sampleRate: sampleRate)
        state = .stopped
        return data
    }
}
