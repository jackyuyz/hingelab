import Foundation
import FoldKit

/// One processed hinge (or fallback) sample ready for instruments.
public struct HingeSample: Equatable, Sendable {
    public var timestamp: TimeInterval
    public var posture: FoldPosture
    /// Absolute degrees as reported. `nil` when there is no hinge.
    public var angleDegrees: Double?
    /// Calibrated 0…1 control value. Identical whether driven by hinge, ribbon, or tilt.
    public var value01: Double
    /// Signed degrees from the current interaction anchor.
    public var deltaDegrees: Double
    /// Degrees per second, outlier-clamped.
    public var velocityDegPerSec: Double
    /// EMA-smoothed 0…1.
    public var smoothedValue01: Double
    /// True when |delta| is inside the pitch-bend dead zone.
    public var isInDeadZone: Bool
    public var source: ControlSource

    public init(
        timestamp: TimeInterval,
        posture: FoldPosture,
        angleDegrees: Double?,
        value01: Double,
        deltaDegrees: Double,
        velocityDegPerSec: Double,
        smoothedValue01: Double,
        isInDeadZone: Bool,
        source: ControlSource
    ) {
        self.timestamp = timestamp
        self.posture = posture
        self.angleDegrees = angleDegrees
        self.value01 = value01
        self.deltaDegrees = deltaDegrees
        self.velocityDegPerSec = velocityDegPerSec
        self.smoothedValue01 = smoothedValue01
        self.isInDeadZone = isInDeadZone
        self.source = source
    }
}

/// Where the 0…1 control value came from. Hinge, ribbon, and tilt must produce
/// identical instrument results for the same `value01`.
public enum ControlSource: String, Codable, Sendable, CaseIterable {
    case hinge
    case ribbon
    case tilt
}
