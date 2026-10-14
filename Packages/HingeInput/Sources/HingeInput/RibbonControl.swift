import Foundation

/// Non-hinge control that produces the same 0…1 as a calibrated hinge.
/// Used for non-Duo devices, VoiceOver, App Review, and the outer cover.
public struct RibbonControl: Equatable, Sendable {
    public var value01: Double

    public init(value01: Double = 0.5) {
        self.value01 = min(1, max(0, value01))
    }

    public mutating func set(_ value01: Double) {
        self.value01 = min(1, max(0, value01))
    }
}
