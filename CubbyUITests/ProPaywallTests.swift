import XCTest

final class ProPaywallTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testItemLimitReachedShowsPaywall() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_ITEM_LIMIT_REACHED", "FORCE_FREE_TIER"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Main Home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Test Item 1"].waitForExistence(timeout: 10))

        let addItemButton = app.buttons["Add Item"]
        XCTAssertTrue(addItemButton.waitForExistence(timeout: 10))
        XCTAssertTrue(addItemButton.isEnabled)
        addItemButton.tap()

        let paywallTitle = app.staticTexts["Add More Items with Cubby Pro"]
        if !paywallTitle.waitForExistence(timeout: 10) {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Paywall not shown"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            let debugTree = XCTAttachment(string: app.debugDescription)
            debugTree.name = "App debugDescription"
            debugTree.lifetime = .keepAlways
            add(debugTree)
        }

        XCTAssertTrue(paywallTitle.exists)

        let termsLink = app.buttons["Terms of Use (EULA)"]
        let privacyLink = app.buttons["Privacy Policy"]
        if !termsLink.exists || !privacyLink.exists {
            app.swipeUp()
        }

        XCTAssertTrue(termsLink.waitForExistence(timeout: 10))
        XCTAssertTrue(privacyLink.waitForExistence(timeout: 10))

        let paywallScreenshot = XCTAttachment(screenshot: app.screenshot())
        paywallScreenshot.name = "Paywall shown"
        paywallScreenshot.lifetime = .keepAlways
        add(paywallScreenshot)

        let fullScreenPaywallScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        fullScreenPaywallScreenshot.name = "Paywall shown full screen"
        fullScreenPaywallScreenshot.lifetime = .keepAlways
        add(fullScreenPaywallScreenshot)
    }
}
