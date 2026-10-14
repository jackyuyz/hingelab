import Testing
import Foundation
@testable import Looper

@Suite("Loop buffer")
struct LoopBufferTests {
    @Test("Writes until the cap then errors")
    func cap() {
        let buffer = LoopBuffer(capacity: 4, sampleRate: 8)
        #expect(buffer.write([0.1, 0.2, 0.3]) == nil)
        #expect(buffer.readAll().count == 3)
        #expect(buffer.write([0.4, 0.5])?.kind == .memoryCap)
        #expect(buffer.isFull)
    }

    @Test("Overdub mixes without exceeding ±1")
    func overdub() {
        let buffer = LoopBuffer(capacity: 4)
        _ = buffer.write([0.4, 0.4, 0.4, 0.4])
        buffer.overdub([0.4, 0.8, 0.4, 0.4])
        let mixed = buffer.readAll()
        #expect(mixed[0] == 0.8)
        #expect(mixed[1] == 1.0)
    }
}

@Suite("WAV encoder")
struct WAVEncoderTests {
    @Test("Writes a valid RIFF header")
    func header() {
        let data = WAVEncoder.encode([0, 0.5, -0.5], sampleRate: 48_000)
        let ascii = String(bytes: data.prefix(12), encoding: .ascii)
        #expect(ascii?.hasPrefix("RIFF") == true)
        #expect(data.count > 44)
    }
}

@Suite("Loop recorder gating")
struct LoopRecorderTests {
    @Test("Free user is limited to one track")
    func freeLimit() {
        let recorder = LoopRecorder(isPro: false)
        #expect(recorder.maxTracks == 1)
        #expect(recorder.beginRecording() == nil)
        _ = recorder.stopRecording()
        #expect(recorder.beginRecording()?.kind == .trackLimit)
    }

    @Test("Pro user can record eight tracks")
    func proLimit() {
        let recorder = LoopRecorder(isPro: true)
        #expect(recorder.maxTracks == 8)
        for _ in 0..<8 {
            #expect(recorder.beginRecording() == nil)
            _ = recorder.stopRecording()
        }
        #expect(recorder.beginRecording()?.kind == .trackLimit)
    }

    @Test("Export empty fails, export after record succeeds")
    func export() throws {
        let recorder = LoopRecorder(isPro: true, sampleRate: 8_000)
        #expect(throws: LoopError.self) {
            _ = try recorder.exportWAV()
        }
        #expect(recorder.beginRecording() == nil)
        #expect(recorder.append([0.1, -0.1, 0.2]) == nil)
        _ = recorder.stopRecording()
        let data = try recorder.exportWAV()
        #expect(data.count > 44)
    }
}
