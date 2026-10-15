import Foundation

/// Minimal Core Audio Format reader/writer for linear PCM. Pure Swift so
/// sample files are tested on Linux, and the app does not need AVAudioFile
/// to load them.
///
/// Supported: `lpcm`, 16/24/32-bit integer or 32/64-bit float, either byte
/// order, any channel count (mixed down to mono). Loop points come from the
/// `mark` chunk (sustain loop start `slbg` / end `slen`); the root note from
/// the `inst` chunk.
public enum CAFCodec {
    public enum DecodeError: Error, Equatable, Sendable {
        case notCAF
        case missingChunk(String)
        case unsupportedFormat(String)
        case truncated
    }

    public struct Decoded: Sendable, Equatable {
        public var sampleRate: Double
        public var channelCount: Int
        public var bitsPerChannel: Int
        /// Mono (channels averaged).
        public var frames: [Float]
        public var loopStart: Int?
        public var loopEnd: Int?
        public var baseNote: Double?

        public func sampleBuffer(defaultRootMIDINote: Double) -> SampleBuffer {
            SampleBuffer(
                frames: frames,
                sampleRate: sampleRate,
                rootMIDINote: baseNote ?? defaultRootMIDINote,
                loopStart: loopStart,
                loopEnd: loopEnd
            )
        }
    }

    // MARK: Decode

    public static func decode(_ data: Data) throws -> Decoded {
        let bytes = [UInt8](data)
        var reader = ByteReader(bytes: bytes)
        guard bytes.count >= 8, try reader.fourCC() == "caff" else { throw DecodeError.notCAF }
        _ = try reader.u16() // file version
        _ = try reader.u16() // flags

        var sampleRate: Double?
        var formatID = ""
        var formatFlags: UInt32 = 0
        var bytesPerPacket = 0
        var channels = 0
        var bits = 0
        var audio: ArraySlice<UInt8>?
        var loopStart: Int?
        var loopEnd: Int?
        var baseNote: Double?

        while reader.remaining >= 12 {
            let type = try reader.fourCC()
            let size = try reader.i64()
            let bodyStart = reader.offset
            let bodySize = size < 0 ? reader.remaining : Int(size)
            guard bodySize <= reader.remaining else { throw DecodeError.truncated }
            var body = ByteReader(bytes: bytes, offset: bodyStart, limit: bodyStart + bodySize)
            switch type {
            case "desc":
                sampleRate = try body.f64()
                formatID = try body.fourCC()
                formatFlags = try body.u32()
                bytesPerPacket = Int(try body.u32())
                _ = try body.u32() // frames per packet
                channels = Int(try body.u32())
                bits = Int(try body.u32())
            case "data":
                _ = try body.u32() // edit count
                audio = bytes[(bodyStart + 4)..<(bodyStart + bodySize)]
            case "mark":
                _ = try body.u32() // SMPTE time type
                let count = Int(try body.u32())
                for _ in 0..<count {
                    let markerType = try body.fourCC()
                    let position = try body.f64()
                    _ = try body.u32() // marker ID
                    try body.skip(8) // SMPTE time
                    _ = try body.u32() // channel
                    if markerType == "slbg" { loopStart = Int(position.rounded()) }
                    if markerType == "slen" { loopEnd = Int(position.rounded()) }
                }
            case "inst":
                baseNote = Double(try body.f32())
            default:
                break
            }
            reader.offset = bodyStart + bodySize
        }

        guard let rate = sampleRate else { throw DecodeError.missingChunk("desc") }
        guard let pcm = audio else { throw DecodeError.missingChunk("data") }
        guard formatID == "lpcm" else { throw DecodeError.unsupportedFormat(formatID) }
        guard channels > 0, bits > 0 else { throw DecodeError.unsupportedFormat("channels/bits") }

        let isFloat = formatFlags & 1 != 0
        let littleEndian = formatFlags & 2 != 0
        let bytesPerSample = bits / 8
        let frameBytes = bytesPerPacket > 0 ? bytesPerPacket : bytesPerSample * channels
        guard [2, 3, 4, 8].contains(bytesPerSample), frameBytes >= bytesPerSample * channels else {
            throw DecodeError.unsupportedFormat("\(bits)-bit")
        }
        if isFloat, bytesPerSample != 4, bytesPerSample != 8 { throw DecodeError.unsupportedFormat("float\(bits)") }
        if !isFloat, bytesPerSample == 8 { throw DecodeError.unsupportedFormat("int64") }

        let frameCount = pcm.count / frameBytes
        var frames = [Float](repeating: 0, count: frameCount)
        let base = pcm.startIndex
        for f in 0..<frameCount {
            var sum = 0.0
            for c in 0..<channels {
                let at = base + f * frameBytes + c * bytesPerSample
                sum += sampleValue(bytes, at: at, size: bytesPerSample, float: isFloat, littleEndian: littleEndian)
            }
            frames[f] = Float(sum / Double(channels))
        }
        return Decoded(
            sampleRate: rate,
            channelCount: channels,
            bitsPerChannel: bits,
            frames: frames,
            loopStart: loopStart,
            loopEnd: loopEnd,
            baseNote: baseNote
        )
    }

    private static func sampleValue(_ b: [UInt8], at i: Int, size: Int, float: Bool, littleEndian: Bool) -> Double {
        var raw: UInt64 = 0
        for k in 0..<size {
            let byte = UInt64(littleEndian ? b[i + k] : b[i + size - 1 - k])
            raw |= byte << (8 * UInt64(k))
        }
        if float {
            return size == 4 ? Double(Float(bitPattern: UInt32(raw))) : Double(bitPattern: raw)
        }
        let bitsCount = UInt64(size * 8)
        let signBit: UInt64 = 1 << (bitsCount - 1)
        let signed = Int64(bitPattern: (raw ^ signBit) &- signBit)
        return Double(signed) / Double(signBit)
    }

    // MARK: Encode

    /// Writes mono big-endian integer PCM (16 or 24 bit) with optional loop
    /// markers and base note. Used by tests and tooling.
    public static func encode(
        frames: [Float],
        sampleRate: Double,
        bitsPerChannel: Int = 24,
        loopStart: Int? = nil,
        loopEnd: Int? = nil,
        baseNote: Double? = nil
    ) -> Data {
        precondition(bitsPerChannel == 16 || bitsPerChannel == 24)
        let bytesPerSample = bitsPerChannel / 8
        var w = ByteWriter()
        w.fourCC("caff"); w.u16(1); w.u16(0)

        w.fourCC("desc"); w.i64(32)
        w.f64(sampleRate)
        w.fourCC("lpcm")
        w.u32(0) // big-endian signed integer
        w.u32(UInt32(bytesPerSample))
        w.u32(1)
        w.u32(1)
        w.u32(UInt32(bitsPerChannel))

        if let baseNote {
            w.fourCC("inst"); w.i64(28)
            w.f32(Float(baseNote))
            w.u8(0); w.u8(127); w.u8(1); w.u8(127)
            w.f32(0)
            w.u32(0); w.u32(0); w.u32(0); w.u32(0)
        }

        if let loopStart, let loopEnd {
            w.fourCC("mark"); w.i64(8 + 2 * 28)
            w.u32(0)
            w.u32(2)
            for (type, position, id) in [("slbg", loopStart, 1), ("slen", loopEnd, 2)] {
                w.fourCC(type)
                w.f64(Double(position))
                w.u32(UInt32(id))
                w.bytes([UInt8](repeating: 0xFF, count: 4) + [0, 0, 0, 0])
                w.u32(0)
            }
        }

        w.fourCC("data"); w.i64(Int64(4 + frames.count * bytesPerSample))
        w.u32(0)
        let scale = Double(1 << (bitsPerChannel - 1))
        for sample in frames {
            let clamped = min(1, max(-1, Double(sample)))
            let value = Int64((clamped * scale).rounded())
            let limited = min(Int64(scale) - 1, max(-Int64(scale), value))
            let raw = UInt64(bitPattern: limited)
            for k in stride(from: bytesPerSample - 1, through: 0, by: -1) {
                w.u8(UInt8((raw >> (8 * UInt64(k))) & 0xFF))
            }
        }
        return Data(w.storage)
    }
}

// MARK: - Byte helpers (big-endian)

private struct ByteReader {
    let bytes: [UInt8]
    var offset: Int
    let limit: Int

    init(bytes: [UInt8], offset: Int = 0, limit: Int? = nil) {
        self.bytes = bytes
        self.offset = offset
        self.limit = limit ?? bytes.count
    }

    var remaining: Int { limit - offset }

    mutating func take(_ n: Int) throws -> ArraySlice<UInt8> {
        guard n <= remaining else { throw CAFCodec.DecodeError.truncated }
        defer { offset += n }
        return bytes[offset..<(offset + n)]
    }

    mutating func skip(_ n: Int) throws { _ = try take(n) }

    mutating func uint(_ n: Int) throws -> UInt64 {
        try take(n).reduce(0) { ($0 << 8) | UInt64($1) }
    }

    mutating func u16() throws -> UInt16 { UInt16(try uint(2)) }
    mutating func u32() throws -> UInt32 { UInt32(try uint(4)) }
    mutating func i64() throws -> Int64 { Int64(bitPattern: try uint(8)) }
    mutating func f32() throws -> Float { Float(bitPattern: try u32()) }
    mutating func f64() throws -> Double { Double(bitPattern: try uint(8)) }
    mutating func fourCC() throws -> String {
        String(decoding: try take(4), as: UTF8.self)
    }
}

private struct ByteWriter {
    var storage: [UInt8] = []

    mutating func u8(_ v: UInt8) { storage.append(v) }
    mutating func bytes(_ v: [UInt8]) { storage.append(contentsOf: v) }
    mutating func uint(_ v: UInt64, _ n: Int) {
        for k in stride(from: n - 1, through: 0, by: -1) {
            storage.append(UInt8((v >> (8 * UInt64(k))) & 0xFF))
        }
    }
    mutating func u16(_ v: UInt16) { uint(UInt64(v), 2) }
    mutating func u32(_ v: UInt32) { uint(UInt64(v), 4) }
    mutating func i64(_ v: Int64) { uint(UInt64(bitPattern: v), 8) }
    mutating func f32(_ v: Float) { u32(v.bitPattern) }
    mutating func f64(_ v: Double) { uint(v.bitPattern, 8) }
    mutating func fourCC(_ s: String) { storage.append(contentsOf: Array(s.utf8.prefix(4))) }
}
