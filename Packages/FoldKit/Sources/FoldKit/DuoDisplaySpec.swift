import Foundation

/// One Duo panel in the orientation it is used.
public struct DuoDisplayPanel: Equatable, Sendable {
    /// Advertised diagonal, inches.
    public var diagonalInches: Double
    /// Native pixels across, in this orientation.
    public var pixelWidth: Int
    /// Native pixels down, in this orientation.
    public var pixelHeight: Int

    public init(diagonalInches: Double, pixelWidth: Int, pixelHeight: Int) {
        self.diagonalInches = diagonalInches
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    /// `pixelWidth / pixelHeight`.
    public var pixelAspectWidthOverHeight: Double {
        Double(pixelWidth) / Double(pixelHeight)
    }

    /// `pixelHeight / pixelWidth`.
    public var pixelAspectHeightOverWidth: Double {
        Double(pixelHeight) / Double(pixelWidth)
    }
}

/// iPhone Duo display sizes.
///
/// Pixel counts and diagonals are the PM's numbers from public reporting.
/// Apple's documentation has not confirmed them. Crease width, point sizes,
/// and the scale factor are not in those reports; they stay in `Assumption`
/// and are not derived from the pixel sizes.
public enum DuoDisplaySpec {
    /// Cover display. Portrait. About 1:1.455 (height:width).
    public static let outer = DuoDisplayPanel(
        diagonalInches: 5.4,
        pixelWidth: 1398,
        pixelHeight: 2034
    )

    /// Unfolded inner display. Landscape. About 1.42:1 (width:height).
    public static let inner = DuoDisplayPanel(
        diagonalInches: 7.6,
        pixelWidth: 2670,
        pixelHeight: 1878
    )

    /// Unpublished. Do not fill these in from the pixel sizes.
    public enum Assumption {
        /// Physical width of the fold crease, millimeters. Unknown.
        public static let creaseWidthMillimeters: Double? = nil

        /// Logical point size of the cover. Unknown until `scaleFactor` is known.
        public static let outerPointWidth: Double? = nil
        public static let outerPointHeight: Double? = nil

        /// Logical point size of the unfolded inner display. Unknown until `scaleFactor` is known.
        public static let innerPointWidth: Double? = nil
        public static let innerPointHeight: Double? = nil

        /// `UIScreen.scale`. Unknown. Do not divide pixels by 2 or 3.
        public static let scaleFactor: Double? = nil
    }
}
