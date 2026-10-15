import XCTest

/// Fastlane-free App Store screenshot capture.
///
/// Skipped unless `SCREENSHOT_DIR` is set, so the default test suite stays
/// deterministic. Drive it from `scripts/capture-screenshots.sh` on a Mac.
final class ScreenshotCaptureTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] == nil,
            "Set SCREENSHOT_DIR to capture App Store screenshots."
        )
    }

    @MainActor
    func testCaptureRequiredScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSample", "-UITestScreenshots"]
        app.launch()

        save("01-library")

        app.tabBars.buttons["Packs"].tap()
        _ = app.staticTexts["UI Test Pack"].waitForExistence(timeout: 8)
        save("02-packs")

        if app.staticTexts["UI Test Pack"].exists {
            app.staticTexts["UI Test Pack"].tap()
            _ = app.staticTexts["WhatsApp"].waitForExistence(timeout: 6)
            save("03-pack-detail")
            if app.navigationBars.buttons.count > 0 {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }

        app.tabBars.buttons["Create"].tap()
        save("04-create")

        app.tabBars.buttons["Settings"].tap()
        save("05-settings")

        if app.buttons["Upgrade to Pro"].waitForExistence(timeout: 4) {
            app.buttons["Upgrade to Pro"].tap()
            _ = app.navigationBars["Stiki Pro"].waitForExistence(timeout: 6)
                || app.staticTexts["Stiki Pro"].waitForExistence(timeout: 4)
            save("06-paywall")
        }
    }

    @MainActor
    private func save(_ name: String) {
        let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"]!
        let url = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent("\(name).png")
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // XCUIScreen writes simulator pixels. Resize to ASC sizes on the host
        // with `sips` — see docs/appstore/SCREENSHOT_PLAN.md.
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        XCTAttachment(screenshot: XCUIScreen.main.screenshot()).lifetime = .keepAlways
    }
}
