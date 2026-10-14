import Foundation

/// Finite-difference velocity with outlier clamping for sparse hinge samples.
public struct VelocityEstimator: Sendable, Equatable {
    /// Anything faster than this is treated as a jump, not motion.
    public var maxAbsDegPerSec: Double
    private var lastDegrees: Double?
    private var lastTimestamp: TimeInterval?

    public init(maxAbsDegPerSec: Double = 720) {
        self.maxAbsDegPerSec = maxAbsDegPerSec
    }

    public mutating func update(degrees: Double, timestamp: TimeInterval) -> Double {
        defer {
            lastDegrees = degrees
            lastTimestamp = timestamp
        }
        guard let lastD = lastDegrees, let lastT = lastTimestamp else { return 0 }
        let dt = timestamp - lastT
        guard dt > 0.0005 else { return 0 }
        let raw = (degrees - lastD) / dt
        return min(maxAbsDegPerSec, max(-maxAbsDegPerSec, raw))
    }

    public mutating func reset() {
        lastDegrees = nil
        lastTimestamp = nil
    }
}

/// One-pole smoother. `smoothing` is the EMA coefficient (1 = no lag).
public struct OnePoleSmoother: Sendable, Equatable {
    public var coefficient: Double
    public var value: Double?

    public init(coefficient: Double = 0.25) {
        self.coefficient = min(1, max(0, coefficient))
        self.value = nil
    }

    public mutating func process(_ input: Double) -> Double {
        if let previous = value {
            let next = previous + coefficient * (input - previous)
            value = next
            return next
        }
        value = input
        return input
    }

    public mutating func reset() {
        value = nil
    }
}

/// ±0.5° rest dead zone used for pitch bend (spec §7).
public enum DeadZone {
    public static let pitchBendDegrees: Double = 0.5

    public static func contains(_ deltaDegrees: Double, window: Double = pitchBendDegrees) -> Bool {
        abs(deltaDegrees) <= window
    }
}
