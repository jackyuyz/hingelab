import XCTest
import FoldKit
import HingeInput
import Instruments
import SettingsKit
import Store
import Synth
import ThemeKit
@testable import HingeLab

final class HingeLabTests: XCTestCase {
    @MainActor
    func testDisplayMetricsComeFromRuntimeNotDuoConstants() {
        let metrics = DisplayMetrics(pointWidth: 320, pointHeight: 480, displayScale: 2)
        XCTAssertEqual(metrics.pixelWidth, 640)
        XCTAssertNotEqual(Int(metrics.pixelWidth), DuoDisplaySpec.inner.pixelWidth)
        XCTAssertNotEqual(Int(metrics.pixelHeight), DuoDisplaySpec.outer.pixelHeight)
        XCTAssertNil(DuoDisplaySpec.Assumption.scaleFactor)
    }

    @MainActor
    func testAppModelAudioSessionHeadphonesUnplugPauses() {
        let model = AppModel.preview
        model.handleAudioSession(.headphonesUnplugged)
        XCTAssertEqual(model.audioOverlay, .headphonesUnplugged)
        model.handleAudioSession(.interruptionEnded(shouldResume: true))
        XCTAssertNil(model.audioOverlay)
    }

    @MainActor
    func testSelectLockedInstrumentOpensPaywall() {
        let model = AppModel.preview
        model.select(.theremin)
        XCTAssertTrue(model.showPaywall)
        XCTAssertEqual(model.selectedInstrument, .accordion)
    }

    @MainActor
    func testRibbonDrivesInstrumentLikeHinge() {
        let model = AppModel.preview
        model.select(.pitchBendGuitar)
        model.ingestRibbon(1)
        XCTAssertEqual(model.currentParams.pitchBendSemitones, 2, accuracy: 0.001)
    }

    func testFoldMockArgumentsMatchSpec() {
        XCTAssertEqual(MockFoldStateProvider.parseArgument("nohinge").posture, .noHinge)
        XCTAssertEqual(MockFoldStateProvider.parseArgument("closed").posture, .closed)
        XCTAssertEqual(MockFoldStateProvider.parseArgument("open").posture, .fullyOpen)
        XCTAssertEqual(MockFoldStateProvider.parseArgument("half:90").angle, 90)
        XCTAssertNotNil(MockFoldStateProvider.parseArgument("sweep:10-180:2").script)
    }

    @MainActor
    func testPreviewUsesDesignedThemeAndBuiltinReeds() {
        let model = AppModel.preview
        XCTAssertEqual(model.theme.name, "hingelab")
        XCTAssertEqual(model.audioAssets.sampleName(.accordionReedC3), "hl_builtin_accordion_C3_reed")
    }

    @MainActor
    func testAccordionKeyAloneIsSilentUntilBellowsMove() {
        let model = AppModel.preview
        model.select(.accordion)
        model.noteOn(60)
        XCTAssertTrue(model.heldNotes.contains(60))
        XCTAssertEqual(model.currentParams.amplitude, 0, "a key without bellows must not sound")
        model.noteOff(60)
        XCTAssertTrue(model.heldNotes.isEmpty)
    }

    @MainActor
    func testClosingClearsHeldNotes() {
        let model = AppModel.preview
        model.select(.accordion)
        model.noteOn(62)
        model.ingestFold(FoldState(posture: .closed, angleDegrees: 0))
        XCTAssertTrue(model.heldNotes.isEmpty)
    }

    func testBundledReedSamplesDecode() throws {
        let assets = BuiltinAudioAssets()
        for slot in SampleSlot.allCases where slot.isAccordionReed {
            let name = assets.sampleName(slot)
            let url = Bundle.main.url(forResource: name, withExtension: "caf")
                ?? Bundle.main.url(forResource: name, withExtension: "caf", subdirectory: "Samples")
            let data = try Data(contentsOf: try XCTUnwrap(url, "\(name).caf missing from app bundle"))
            let decoded = try CAFCodec.decode(data)
            XCTAssertEqual(decoded.sampleRate, 48_000)
            XCTAssertNotNil(decoded.loopStart)
        }
    }
}
