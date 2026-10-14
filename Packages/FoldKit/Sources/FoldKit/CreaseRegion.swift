import Foundation

/// Axis-aligned reserved fold/crease region in a container's local coordinates.
///
/// On device this comes from `GeometryProxy.reservedRegions(kind: .division)`.
/// That API reports a region only while the device is partially folded; it has
/// zero width when the device is flat, and it is empty on the first layout pass.
public struct CreaseRegion: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isEmpty: Bool { width <= 0 || height <= 0 }
}

/// Provides the fold crease reserved region. Feature code depends on this
/// protocol — never on `reservedRegions(kind:)` directly.
public protocol CreaseRegionProviding: Sendable {
    /// The crease in the given container, or `nil` when there is no active fold
    /// (flat, closed, no hinge, or first layout pass).
    func division(inWidth width: Double, height: Double) -> CreaseRegion?
}

/// Test / preview provider. The mock crease width is **not** a Duo measurement.
public struct MockCreaseRegionProvider: CreaseRegionProviding, Equatable, Sendable {
    public var isHalfFolded: Bool
    /// Placeholder strip used only when `isHalfFolded` is true. Not a real crease.
    public var mockWidthPoints: Double

    public init(isHalfFolded: Bool = false, mockWidthPoints: Double = 8) {
        self.isHalfFolded = isHalfFolded
        self.mockWidthPoints = mockWidthPoints
    }

    public func division(inWidth width: Double, height: Double) -> CreaseRegion? {
        guard isHalfFolded, width > 0, height > 0 else { return nil }
        let w = min(mockWidthPoints, width)
        return CreaseRegion(x: (width - w) / 2, y: 0, width: w, height: height)
    }
}

/// Production stub. The real `reservedRegions(kind: .division)` call lives in
/// the app layer behind a `#available` + `TODO(verify-api)` guard.
public struct UnavailableCreaseRegionProvider: CreaseRegionProviding, Sendable {
    public init() {}

    public func division(inWidth width: Double, height: Double) -> CreaseRegion? {
        _ = width
        _ = height
        return nil
    }
}
