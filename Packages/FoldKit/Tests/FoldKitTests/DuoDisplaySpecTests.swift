import Testing
@testable import FoldKit

@Suite("Duo display spec")
struct DuoDisplaySpecTests {

    @Test("Cover display matches the public portrait size")
    func outerDisplay() {
        let outer = DuoDisplaySpec.outer
        #expect(outer.diagonalInches == 5.4)
        #expect(outer.pixelWidth == 1398)
        #expect(outer.pixelHeight == 2034)
        #expect(outer.pixelHeight > outer.pixelWidth)
        // Public figure is about 1:1.455 (height:width).
        #expect(abs(outer.pixelAspectHeightOverWidth - 1.455) < 0.001)
        #expect(abs(outer.pixelAspectHeightOverWidth - (2034.0 / 1398.0)) < 0.000_000_1)
    }

    @Test("Inner display matches the public unfolded landscape size")
    func innerDisplay() {
        let inner = DuoDisplaySpec.inner
        #expect(inner.diagonalInches == 7.6)
        #expect(inner.pixelWidth == 2670)
        #expect(inner.pixelHeight == 1878)
        #expect(inner.pixelWidth > inner.pixelHeight)
        // Public figure is about 1.42:1 (width:height).
        #expect(abs(inner.pixelAspectWidthOverHeight - 1.42) < 0.005)
        #expect(abs(inner.pixelAspectWidthOverHeight - (2670.0 / 1878.0)) < 0.000_000_1)
    }

    @Test("Crease width, point sizes, and scale stay unconfirmed")
    func assumptionsStayUnset() {
        #expect(DuoDisplaySpec.Assumption.creaseWidthMillimeters == nil)
        #expect(DuoDisplaySpec.Assumption.outerPointWidth == nil)
        #expect(DuoDisplaySpec.Assumption.outerPointHeight == nil)
        #expect(DuoDisplaySpec.Assumption.innerPointWidth == nil)
        #expect(DuoDisplaySpec.Assumption.innerPointHeight == nil)
        #expect(DuoDisplaySpec.Assumption.scaleFactor == nil)
    }
}
