import Testing
import Foundation
import FoldKit
@testable import HingeInput

@Suite("Hinge calibration")
struct HingeCalibrationTests {
    @Test("value01 maps the calibrated span")
    func mapsSpan() {
        let cal = HingeCalibration(minDegrees: 20, maxDegrees: 120, completedAt: .now)
        #expect(cal.value01(degrees: 20) == 0)
        #expect(cal.value01(degrees: 120) == 1)
        #expect(abs(cal.value01(degrees: 70) - 0.5) < 0.000_000_1)
        #expect(cal.value01(degrees: 0) == 0)
        #expect(cal.value01(degrees: 200) == 1)
        #expect(cal.isComplete)
    }

    @Test("Three-step session records closed then open")
    func threeStep() {
        var session = CalibrationSession()
        #expect(session.step == .restClosed)
        session.capture(degrees: 12)
        session.capture(degrees: 165)
        #expect(session.step == .confirm)
        let finished = session.finish(now: Date(timeIntervalSince1970: 1))
        #expect(finished?.minDegrees == 12)
        #expect(finished?.maxDegrees == 165)
        #expect(finished?.isComplete == true)
    }
}

@Suite("Velocity estimator")
struct VelocityEstimatorTests {
    @Test("First sample is zero, second is finite difference")
    func finiteDifference() {
        var estimator = VelocityEstimator()
        #expect(estimator.update(degrees: 10, timestamp: 1.0) == 0)
        let v = estimator.update(degrees: 40, timestamp: 2.0)
        #expect(v == 30)
    }

    @Test("Outliers are clamped")
    func clamp() {
        var estimator = VelocityEstimator(maxAbsDegPerSec: 100)
        _ = estimator.update(degrees: 0, timestamp: 0)
        let v = estimator.update(degrees: 500, timestamp: 1)
        #expect(v == 100)
        _ = estimator.update(degrees: 0, timestamp: 2)
        let down = estimator.update(degrees: -500, timestamp: 3)
        #expect(down == -100)
    }
}

@Suite("Dead zone")
struct DeadZoneTests {
    @Test("±0.5° is the pitch-bend rest window")
    func window() {
        #expect(DeadZone.contains(0.4))
        #expect(DeadZone.contains(-0.5))
        #expect(!DeadZone.contains(0.6))
        #expect(DeadZone.pitchBendDegrees == 0.5)
    }
}

@Suite("Hinge input pipeline")
struct HingeInputPipelineTests {
    @Test("Calibrated hinge and ribbon produce the same value01")
    func hingeAndRibbonMatch() {
        let cal = HingeCalibration(minDegrees: 0, maxDegrees: 100, completedAt: .now)
        var hinge = HingeInputPipeline(calibration: cal, smoothing: 1, source: .hinge)
        var ribbon = HingeInputPipeline(calibration: cal, smoothing: 1, source: .ribbon)

        let state = FoldState(
            posture: .partiallyOpen,
            angleDegrees: 25,
            timestamp: Date(timeIntervalSince1970: 10)
        )
        let fromHinge = hinge.ingest(state)
        let fromRibbon = ribbon.ingestFallback(value01: 0.25, timestamp: 10, source: .ribbon)

        #expect(abs(fromHinge.value01 - 0.25) < 0.000_000_1)
        #expect(abs(fromRibbon.value01 - fromHinge.value01) < 0.000_000_1)
        #expect(fromHinge.source == .hinge)
        #expect(fromRibbon.source == .ribbon)
        #expect(fromRibbon.angleDegrees == nil)
    }

    @Test("No hinge yields a resting sample")
    func noHinge() {
        var pipeline = HingeInputPipeline()
        let sample = pipeline.ingest(.noHinge)
        #expect(sample.angleDegrees == nil)
        #expect(sample.isInDeadZone)
        #expect(sample.velocityDegPerSec == 0)
    }

    @Test("Smoothing lags a step change")
    func smoothing() {
        let cal = HingeCalibration(minDegrees: 0, maxDegrees: 100, completedAt: .now)
        var slow = HingeInputPipeline(calibration: cal, smoothing: 0.2)
        var fast = HingeInputPipeline(calibration: cal, smoothing: 1.0)
        let a = FoldState(posture: .partiallyOpen, angleDegrees: 0, timestamp: Date(timeIntervalSince1970: 1))
        let b = FoldState(posture: .partiallyOpen, angleDegrees: 100, timestamp: Date(timeIntervalSince1970: 1.1))
        _ = slow.ingest(a)
        _ = fast.ingest(a)
        let s = slow.ingest(b)
        let f = fast.ingest(b)
        #expect(f.smoothedValue01 > s.smoothedValue01)
        #expect(f.smoothedValue01 == 1)
    }
}

@Suite("Ribbon control")
struct RibbonControlTests {
    @Test("Clamps to 0...1")
    func clamp() {
        var ribbon = RibbonControl(value01: 2)
        #expect(ribbon.value01 == 1)
        ribbon.set(-1)
        #expect(ribbon.value01 == 0)
    }
}
