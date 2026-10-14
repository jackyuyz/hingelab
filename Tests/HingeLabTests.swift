import XCTest
import FoldKit
import HingeInput
import Instruments
import SettingsKit
import Store
import Synth
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
}
