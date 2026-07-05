import XCTest

final class ProPaywallTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testForcedFreeSeededUserSeesBlockingHardPaywall() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA", "FORCE_FREE_TIER"])
        app.launch()

        let paywallTitle = app.staticTexts["Start with Cubby Pro"]
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
        XCTAssertTrue(app.staticTexts["Every home from day one"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Unlimited items"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Shared home inventories"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Close"].exists)

        let continueButton = app.buttons["Continue with Pro"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertFalse(continueButton.isEnabled)
        XCTAssertTrue(app.staticTexts["Purchase options are not available in this build."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Restore Purchase"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Manage Subscription"].waitForExistence(timeout: 10))

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

    @MainActor
    func testForcedTrialPreviewUsesSevenDayFallback() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: [
            "UI-TESTING",
            "SEED_MOCK_DATA",
            "FORCE_FREE_TIER",
            "FORCE_FREE_TRIAL_PREVIEW"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Start your 7-day free trial"].waitForExistence(timeout: 10))
        let requiredCopy = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Start with 7 days free")).firstMatch
        XCTAssertTrue(requiredCopy.waitForExistence(timeout: 5))

        let trialBadge = app.staticTexts["Free trial included"]
        if !trialBadge.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(trialBadge.waitForExistence(timeout: 5))

        let trialButton = app.buttons["Start 7-Day Free Trial"]
        XCTAssertTrue(trialButton.waitForExistence(timeout: 5))
        XCTAssertFalse(trialButton.isEnabled)
        XCTAssertFalse(app.buttons["Close"].exists)
    }

    @MainActor
    func testUnavailablePurchaseOptionsShowRetryAndRestoreActions() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA", "FORCE_FREE_TIER"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Start with Cubby Pro"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Purchase options are not available in this build."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Restore Purchase"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Manage Subscription"].waitForExistence(timeout: 10))

        XCTAssertTrue(app.staticTexts["Unable to load purchase options. Please check your connection and try again."].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["Try Again"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Restore"].waitForExistence(timeout: 5))
    }
}
