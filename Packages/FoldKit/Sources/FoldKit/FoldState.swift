import Foundation

/// Represents the current fold state of the device including posture and angle.
public struct FoldState: Equatable, Sendable {
    /// The current folding posture
    public var posture: FoldPosture
    
    /// Degrees exactly as reported by the system. `nil` when there is no hinge.
    /// The range is NOT documented. Never compare to absolute thresholds without calibration.
    public var angleDegrees: Double?
    
    /// Timestamp when this state was captured
    public var timestamp: Date
    
    public init(posture: FoldPosture, angleDegrees: Double?, timestamp: Date = .now) {
        self.posture = posture
        self.angleDegrees = angleDegrees
        self.timestamp = timestamp
    }
    
    /// Constant representing a device with no hinge
    public static let noHinge = FoldState(posture: .noHinge, angleDegrees: nil, timestamp: .distantPast)
    
    /// Whether this state indicates a device with a hinge
    public var hasHinge: Bool {
        posture != .noHinge
    }
}

extension FoldState: Codable {
    enum CodingKeys: String, CodingKey {
        case posture, angleDegrees, timestamp
    }
}
