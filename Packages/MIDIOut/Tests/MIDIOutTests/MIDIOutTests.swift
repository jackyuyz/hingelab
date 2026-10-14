import Testing
@testable import MIDIOut

@Suite("MIDI encoding")
struct MIDIEncoderTests {
    @Test("Note on/off bytes")
    func notes() {
        #expect(MIDIEncoder.encode(.noteOn(channel: 0, note: 60, velocity: 100)) == [0x90, 60, 100])
        #expect(MIDIEncoder.encode(.noteOff(channel: 1, note: 64)) == [0x81, 64, 0])
    }

    @Test("CC bytes")
    func cc() {
        #expect(MIDIEncoder.encode(.controlChange(channel: 0, number: 74, value: 64)) == [0xB0, 74, 64])
        #expect(MIDIEncoder.encode(.controlChange(channel: 15, number: 1, value: 127)) == [0xBF, 1, 127])
    }

    @Test("14-bit pitch bend center and ends")
    func pitchBend() {
        #expect(MIDIEncoder.pitchBend14(value01: 0.5) == 8192)
        #expect(MIDIEncoder.pitchBend14(value01: 0) == 0)
        #expect(MIDIEncoder.pitchBend14(value01: 1) == 16383)
        let center = MIDIEncoder.encode(.pitchBend(channel: 0, value14: 8192))
        #expect(center == [0xE0, 0x00, 0x40])
        let max = MIDIEncoder.encode(.pitchBend(channel: 2, value14: 16383))
        #expect(max == [0xE2, 0x7F, 0x7F])
        let clamped = MIDIEncoder.encode(.pitchBend(channel: 0, value14: 20_000))
        #expect(clamped == [0xE0, 0x7F, 0x7F])
    }
}

@Suite("MIDI mapping")
struct MIDIMappingTests {
    @Test("Hinge to pitch bend and CC74")
    func targets() {
        let bend = MIDIMapping(hingeTarget: .pitchBend, channel: 0)
        #expect(bend.event(value01: 0.5) == .pitchBend(channel: 0, value14: 8192))

        let cc = MIDIMapping(hingeTarget: .brightness, channel: 3)
        #expect(cc.event(value01: 1) == .controlChange(channel: 3, number: 74, value: 127))
        #expect(cc.event(value01: 0) == .controlChange(channel: 3, number: 74, value: 0))
    }
}

@Suite("Null MIDI sender")
struct NullMIDISenderTests {
    @Test("Records events and keeps the HingeLab name")
    func records() {
        let sender = NullMIDISender()
        #expect(sender.virtualSourceName == "HingeLab")
        sender.send(.noteOn(channel: 0, note: 60, velocity: 80))
        #expect(sender.sent.count == 1)
    }
}
