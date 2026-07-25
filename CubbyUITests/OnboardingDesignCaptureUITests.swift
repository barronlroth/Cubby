import XCTest

final class OnboardingDesignCaptureUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testCapturePhaseOneOnboarding() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: [
            "UI-TESTING",
            "SNAPSHOT_ONBOARDING",
            "FORCE_FREE_TIER",
            "FORCE_FREE_TRIAL_PREVIEW"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to Cubby"].waitForExistence(timeout: 10))
        capture("01-Welcome")

        app.buttons["onboarding-welcome-primary"].tap()
        assertNavigation("Your Home", in: app)
        let homeField = app.textFields["onboarding-home-name"]
        XCTAssertTrue(homeField.waitForExistence(timeout: 5))
        homeField.tap()
        homeField.typeText("Juniper House")
        dismissKeyboard(in: app)
        XCTAssertEqual(homeField.value as? String, "Juniper House")
        capture("02-Home")
        app.buttons["onboarding-home-continue"].tap()

        assertNavigation("First Item", in: app)
        let itemField = app.textFields["onboarding-item-name"]
        XCTAssertTrue(itemField.waitForExistence(timeout: 5))
        itemField.tap()
        itemField.typeText("Passport")
        dismissKeyboard(in: app)
        XCTAssertEqual(itemField.value as? String, "Passport")
        capture("03-First-Item")
        app.buttons["onboarding-item-continue"].tap()

        assertNavigation("Item Location", in: app)
        XCTAssertTrue(app.staticTexts["Where does it live?"].waitForExistence(timeout: 5))
        let closetButton = app.buttons["Closet"]
        closetButton.tap()
        XCTAssertTrue(closetButton.isSelected)
        XCTAssertTrue(app.navigationBars["Item Location"].buttons.element(boundBy: 0).isHittable)
        Thread.sleep(forTimeInterval: 1)
        capture("04-Location")
        app.buttons["onboarding-location-review"].tap()

        assertNavigation("Review", in: app)
        XCTAssertTrue(app.staticTexts["Ready to store it?"].waitForExistence(timeout: 5))
        capture("05-Review")
        app.buttons["onboarding-store-first-item"].tap()

        XCTAssertTrue(app.staticTexts["Start your 7-day free trial"].waitForExistence(timeout: 10))
        capture("06-Paywall-Handoff")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func assertNavigation(_ title: String, in app: XCUIApplication) {
        let navigationBar = app.navigationBars[title]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
        let backButton = navigationBar.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        XCTAssertTrue(backButton.isHittable)
        Thread.sleep(forTimeInterval: 0.5)
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
        start.press(forDuration: 0.05, thenDragTo: end)

        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 3))
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeDown(velocity: .fast)
        }
        Thread.sleep(forTimeInterval: 1)
    }
}
