import Testing
import Foundation
@testable import SettingsKit

@Suite("Scale quantization")
struct ScaleModeTests {
    @Test("Off leaves continuous pitch")
    func off() {
        #expect(ScaleMode.off.quantize(60.4) == 60.4)
    }

    @Test("Chromatic rounds")
    func chromatic() {
        #expect(ScaleMode.chromatic.quantize(60.4) == 60)
        #expect(ScaleMode.chromatic.quantize(60.6) == 61)
    }

    @Test("Major snaps to C major when near C")
    func major() {
        let snapped = ScaleMode.major.quantize(61.1) // C# near C/D
        let pc = Int(snapped.rounded()) % 12
        #expect([0, 2, 4, 5, 7, 9, 11].contains(pc))
    }

    @Test("Pentatonic never lands on F or B")
    func pentatonic() {
        for n in stride(from: 48.0, through: 72.0, by: 0.3) {
            let q = ScaleMode.pentatonic.quantize(n)
            let pc = Int(q.rounded()) %% 12
            #expect([0, 2, 4, 7, 9].contains(pc))
        }
    }
}

infix operator %% : MultiplicationPrecedence
private func %% (left: Int, right: Int) -> Int {
    let r = left % right
    return r >= 0 ? r : r + right
}

@Suite("Settings store")
struct SettingsStoreTests {
    @Test("Memory store round-trips")
    func memory() {
        let store = MemorySettingsStore()
        var settings = store.load()
        settings.pitchBendRangeSemitones = 12
        settings.audioBuffer = .normal
        settings.leftHanded = true
        store.save(settings)
        #expect(store.load().pitchBendRangeSemitones == 12)
        #expect(store.load().audioBuffer.frames == 256)
        #expect(store.load().leftHanded)
    }

    @Test("UserDefaults store round-trips")
    func defaults() {
        let defaults = UserDefaults(suiteName: "hingelab.settings.test")!
        defaults.removePersistentDomain(forName: "hingelab.settings.test")
        let store = UserDefaultsSettingsStore(defaults: defaults)
        #expect(store.load().a4Hz == 440)
        var s = UserSettings.default
        s.a4Hz = 432
        store.save(s)
        #expect(store.load().a4Hz == 432)
    }
}
