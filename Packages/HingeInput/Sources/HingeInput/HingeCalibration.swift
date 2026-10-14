import Foundation

/// Per-app hinge calibration. Absolute angles are undocumented, so every
/// instrument maps through this range rather than comparing to 0°/180°.
public struct HingeCalibration: Codable, Equatable, Sendable {
    public var minDegrees: Double
    public var maxDegrees: Double
    public var completedAt: Date?

    public init(minDegrees: Double = 10, maxDegrees: Double = 170, completedAt: Date? = nil) {
        self.minDegrees = minDegrees
        self.maxDegrees = maxDegrees
        self.completedAt = completedAt
    }

    /// Used until the user finishes the 3-step flow. Not a documented range.
    public static let unverifiedDefault = HingeCalibration()

    public var isComplete: Bool { completedAt != nil }

    public var spanDegrees: Double {
        max(maxDegrees - minDegrees, 1)
    }

    /// Normalize an absolute angle into 0…1 using the calibrated span.
    public func value01(degrees: Double) -> Double {
        let raw = (degrees - minDegrees) / spanDegrees
        return min(1, max(0, raw))
    }

    public mutating func recordSample(_ degrees: Double) {
        minDegrees = min(minDegrees, degrees)
        maxDegrees = max(maxDegrees, degrees)
    }
}

/// Three-step calibration, same shape FoldPlay will reuse.
public enum CalibrationStep: Int, Sendable, CaseIterable, Equatable {
    case restClosed = 1
    case restOpen = 2
    case confirm = 3
}

public struct CalibrationSession: Equatable, Sendable {
    public var step: CalibrationStep
    public var closedDegrees: Double?
    public var openDegrees: Double?

    public init(step: CalibrationStep = .restClosed) {
        self.step = step
        self.closedDegrees = nil
        self.openDegrees = nil
    }

    public mutating func capture(degrees: Double) {
        switch step {
        case .restClosed:
            closedDegrees = degrees
            step = .restOpen
        case .restOpen:
            openDegrees = degrees
            step = .confirm
        case .confirm:
            break
        }
    }

    public func finish(now: Date = .now) -> HingeCalibration? {
        guard let closed = closedDegrees, let open = openDegrees else { return nil }
        let lo = min(closed, open)
        let hi = max(closed, open)
        return HingeCalibration(minDegrees: lo, maxDegrees: hi, completedAt: now)
    }
}
