import Foundation
import FoldKit

/// Converts `FoldState` (or a ribbon/tilt 0…1) into a `HingeSample`.
///
/// Relative angle, velocity, and smoothing all live here so every instrument
/// sees the same processed stream.
public struct HingeInputPipeline: Sendable {
    public var calibration: HingeCalibration
    public var tracker: RelativeAngleTracker
    public var velocity: VelocityEstimator
    public var smoother: OnePoleSmoother
    public var deadZoneDegrees: Double
    public var source: ControlSource

    public init(
        calibration: HingeCalibration = .unverifiedDefault,
        smoothing: Double = 0.25,
        deadZoneDegrees: Double = DeadZone.pitchBendDegrees,
        source: ControlSource = .hinge
    ) {
        self.calibration = calibration
        self.tracker = RelativeAngleTracker(smoothing: smoothing)
        self.velocity = VelocityEstimator()
        self.smoother = OnePoleSmoother(coefficient: smoothing)
        self.deadZoneDegrees = deadZoneDegrees
        self.source = source
    }

    public mutating func beginInteraction(at degrees: Double) {
        tracker.begin(at: degrees)
        velocity.reset()
        smoother.reset()
    }

    public mutating func ingest(_ state: FoldState) -> HingeSample {
        let timestamp = state.timestamp.timeIntervalSince1970
        guard let degrees = state.angleDegrees else {
            return HingeSample(
                timestamp: timestamp,
                posture: state.posture,
                angleDegrees: nil,
                value01: 0.5,
                deltaDegrees: 0,
                velocityDegPerSec: 0,
                smoothedValue01: 0.5,
                isInDeadZone: true,
                source: source
            )
        }

        if tracker.anchorDegrees == nil {
            tracker.begin(at: degrees)
        }

        let value01 = calibration.value01(degrees: degrees)
        let smoothed = smoother.process(value01)
        let delta = tracker.delta(degrees)
        _ = tracker.update(degrees)
        let speed = velocity.update(degrees: degrees, timestamp: timestamp)

        return HingeSample(
            timestamp: timestamp,
            posture: state.posture,
            angleDegrees: degrees,
            value01: value01,
            deltaDegrees: delta,
            velocityDegPerSec: speed,
            smoothedValue01: smoothed,
            isInDeadZone: DeadZone.contains(delta, window: deadZoneDegrees),
            source: source
        )
    }

    /// Ribbon / tilt fallback. Same `value01` contract as the hinge path.
    public mutating func ingestFallback(value01: Double, timestamp: TimeInterval, source: ControlSource) -> HingeSample {
        let clamped = min(1, max(0, value01))
        let degrees = calibration.minDegrees + clamped * calibration.spanDegrees
        let state = FoldState(
            posture: .noHinge,
            angleDegrees: degrees,
            timestamp: Date(timeIntervalSince1970: timestamp)
        )
        let previousSource = self.source
        self.source = source
        let sample = ingest(state)
        self.source = previousSource
        return HingeSample(
            timestamp: sample.timestamp,
            posture: .noHinge,
            angleDegrees: nil,
            value01: sample.value01,
            deltaDegrees: sample.deltaDegrees,
            velocityDegPerSec: sample.velocityDegPerSec,
            smoothedValue01: sample.smoothedValue01,
            isInDeadZone: sample.isInDeadZone,
            source: source
        )
    }

    public mutating func reset() {
        tracker.reset()
        velocity.reset()
        smoother.reset()
    }
}
