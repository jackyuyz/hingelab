import Foundation

/// Represents the folding posture of a foldable device.
///
/// Maps to the system's hinge status values:
/// - `.closed` → device is folded closed
/// - `.partiallyOpen` → device is flexed/half-folded
/// - `.fullyOpen` → device is flat/fully open
/// - `.noHinge` → non-foldable device or hinge context unavailable
/// - `.unknown` → transient or unrecognized states
public enum FoldPosture: String, Codable, Sendable, CaseIterable, Equatable {
    /// Non-Duo iPhone, iPad, Mac ("Designed for iPad"), or hinge context unavailable
    case noHinge
    /// Folded; app is (assumed) on the outer display
    case closed
    /// Flexed / half-folded (laptop, book, tent… system does not tell which)
    case partiallyOpen
    /// Flat; app on inner display
    case fullyOpen
    /// UIKit `.unknown`, or transient states
    case unknown
    
    /// Whether this posture indicates a device with a hinge
    public var hasHinge: Bool {
        self != .noHinge
    }
    
    /// Human-readable description of the posture
    public var displayName: String {
        switch self {
        case .noHinge: return "No Hinge"
        case .closed: return "Closed"
        case .partiallyOpen: return "Partially Open"
        case .fullyOpen: return "Fully Open"
        case .unknown: return "Unknown"
        }
    }
}
