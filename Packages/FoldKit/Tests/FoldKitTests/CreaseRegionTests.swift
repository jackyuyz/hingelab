import Testing
@testable import FoldKit

@Suite("Crease region")
struct CreaseRegionTests {
    @Test("Mock provider reports nil when not half-folded")
    func mockNilWhenFlat() {
        let provider = MockCreaseRegionProvider(isHalfFolded: false)
        #expect(provider.division(inWidth: 800, height: 400) == nil)
    }

    @Test("Mock provider returns a centered strip only while half-folded")
    func mockStripWhenHalfFolded() {
        let provider = MockCreaseRegionProvider(isHalfFolded: true, mockWidthPoints: 10)
        let region = provider.division(inWidth: 800, height: 400)
        #expect(region != nil)
        #expect(region?.width == 10)
        #expect(region?.height == 400)
        #expect(region?.x == 395)
        #expect(region?.y == 0)
        #expect(region?.isEmpty == false)
    }

    @Test("Unavailable provider never invents a crease")
    func unavailable() {
        let provider = UnavailableCreaseRegionProvider()
        #expect(provider.division(inWidth: 800, height: 400) == nil)
    }
}

@Suite("Display metrics")
struct DisplayMetricsTests {
    @Test("Pixel size is points times scale, never a hardcoded Duo size")
    func pixelsFromRuntime() {
        let metrics = DisplayMetrics(
            pointWidth: 400,
            pointHeight: 300,
            displayScale: 3,
            safeAreaTop: 20,
            safeAreaLeft: 4,
            safeAreaBottom: 12,
            safeAreaRight: 4
        )
        #expect(metrics.pixelWidth == 1200)
        #expect(metrics.pixelHeight == 900)
        #expect(metrics.isLandscape)
        #expect(abs(metrics.aspectWidthOverHeight - 400.0 / 300.0) < 0.000_000_1)
        #expect(metrics.safeAreaTop == 20)
    }

    @Test("Panel guess uses aspect only and does not hardcode point sizes")
    func panelGuess() {
        let innerish = DisplayMetrics(pointWidth: 1335, pointHeight: 939, displayScale: 2)
        #expect(innerish.panelGuess == .innerUnfolded)

        let outerish = DisplayMetrics(pointWidth: 466, pointHeight: 678, displayScale: 3)
        #expect(outerish.panelGuess == .outerCover)

        let odd = DisplayMetrics(pointWidth: 100, pointHeight: 100, displayScale: 2)
        #expect(odd.panelGuess == .unknown)
    }
}
