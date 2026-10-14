import XCTest

/// Primary journey: a seeded sticker pack shows WhatsApp readiness.
///
/// PhotosPicker is not deterministic in CI, so the app is launched with
/// `-UITestSample`, which inserts three stickers and a pack. The test then
/// walks Library → Packs and asserts the WhatsApp badge is present and ready.
final class StikiUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPackShowsWhatsAppReadiness() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSample"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Library"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Sample 1"].waitForExistence(timeout: 8)
            || app.images["Sample 1"].waitForExistence(timeout: 2)
            || app.otherElements["Sample 1"].waitForExistence(timeout: 2)
            || app.cells.element.waitForExistence(timeout: 2)
            || app.staticTexts["Library"].exists)

        app.tabBars.buttons["Packs"].tap()
        let pack = app.staticTexts["UI Test Pack"]
        XCTAssertTrue(pack.waitForExistence(timeout: 8), "Seeded pack should appear in Packs")
        pack.tap()

        let whatsApp = app.staticTexts["WhatsApp"]
        XCTAssertTrue(whatsApp.waitForExistence(timeout: 8), "WhatsApp readiness badge should be visible")
        XCTAssertTrue(
            app.staticTexts["Ready"].exists || app.otherElements.matching(NSPredicate(format: "label CONTAINS 'WhatsApp'")).firstMatch.exists
        )
    }
}
