import XCTest

final class HingeLabUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchWithHalfFoldMock() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "half:90"]
        app.launch()
        XCTAssertTrue(app.staticTexts["HingeLab"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["picker.accordion"].exists)
    }

    func testNoHingeShowsRibbon() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "nohinge"]
        app.launch()
        XCTAssertTrue(app.sliders["ribbon.slider"].waitForExistence(timeout: 5))
    }

    func testSettingsAndPaywallIdentifiers() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "open"]
        app.launch()
        app.buttons["picker.settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func testAccordionHalfFoldShowsDesignedSlots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "half:95"]
        app.launch()
        app.buttons["picker.accordion"].tap()
        XCTAssertTrue(app.otherElements["slot.bellows"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["slot.angleGauge"].exists)
        XCTAssertTrue(app.buttons["accordion.chord.C"].exists)
        XCTAssertEqual(app.buttons["accordion.chord.C"].label, "C major chord")
    }

    func testClosedShowsPocketPlayer() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "closed"]
        app.launch()
        XCTAssertTrue(app.otherElements["cover.compact"].waitForExistence(timeout: 5))
    }
}
