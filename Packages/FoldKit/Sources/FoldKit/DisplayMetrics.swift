import Foundation

/// Runtime display metrics. Always filled from the active window / SwiftUI
/// geometry — never from `DuoDisplaySpec` pixel constants.
///
/// `DuoDisplaySpec` exists only as a documented reference for design and
/// handoff. Layout, hit testing, and visualizers must use this type.
public struct DisplayMetrics: Equatable, Sendable {
    public var pointWidth: Double
    public var pointHeight: Double
    public var displayScale: Double
    public var safeAreaTop: Double
    public var safeAreaLeft: Double
    public var safeAreaBottom: Double
    public var safeAreaRight: Double

    public init(
        pointWidth: Double,
        pointHeight: Double,
        displayScale: Double,
        safeAreaTop: Double = 0,
        safeAreaLeft: Double = 0,
        safeAreaBottom: Double = 0,
        safeAreaRight: Double = 0
    ) {
        self.pointWidth = pointWidth
        self.pointHeight = pointHeight
        self.displayScale = displayScale
        self.safeAreaTop = safeAreaTop
        self.safeAreaLeft = safeAreaLeft
        self.safeAreaBottom = safeAreaBottom
        self.safeAreaRight = safeAreaRight
    }

    public static let zero = DisplayMetrics(
        pointWidth: 0,
        pointHeight: 0,
        displayScale: 1
    )

    public var pixelWidth: Double { pointWidth * displayScale }
    public var pixelHeight: Double { pointHeight * displayScale }

    public var aspectWidthOverHeight: Double {
        guard pointHeight > 0 else { return 0 }
        return pointWidth / pointHeight
    }

    public var isLandscape: Bool { pointWidth > pointHeight }
}

/// Heuristic guess of which Duo panel a size resembles. Never used for layout.
/// Compare against live `DisplayMetrics`, not hardcoded point sizes.
public enum DuoPanelGuess: String, Sendable, Equatable {
    case unknown
    /// Roughly the cover (tall portrait).
    case outerCover
    /// Roughly the inner unfolded landscape.
    case innerUnfolded
}

extension DisplayMetrics {
    /// Aspect-only guess against the public reference ratios. Not a substitute
    /// for reading the window.
    public var panelGuess: DuoPanelGuess {
        guard pointWidth > 0, pointHeight > 0 else { return .unknown }
        let inner = DuoDisplaySpec.inner.pixelAspectWidthOverHeight
        let outer = DuoDisplaySpec.outer.pixelAspectHeightOverWidth
        if isLandscape, abs(aspectWidthOverHeight - inner) < 0.08 {
            return .innerUnfolded
        }
        if !isLandscape, abs((pointHeight / pointWidth) - outer) < 0.08 {
            return .outerCover
        }
        return .unknown
    }
}
