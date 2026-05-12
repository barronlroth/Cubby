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

        let paywallTitle = app.staticTexts["Cubby Pro"]
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
        XCTAssertTrue(app.staticTexts["Unlimited homes"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Unlimited items"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Shared home inventories"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Photos, notes, exact paths"].exists)
        XCTAssertTrue(app.buttons["Unlock Pro"].waitForExistence(timeout: 10))

        let termsLink = app.buttons["Terms"]
        let privacyLink = app.buttons["Privacy"]
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
