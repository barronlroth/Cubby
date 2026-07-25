import XCTest

final class OnboardingAccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingCompletesWithKeyboardAtAccessibilityTextSize() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: [
            "UI-TESTING",
            "SNAPSHOT_ONBOARDING",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to Cubby"].waitForExistence(timeout: 10))

        let homeNameField = app.textFields["Home Name"]
        XCTAssertTrue(homeNameField.waitForExistence(timeout: 5))
        homeNameField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.textFields["Home Name"].typeText("Accessible Home")

        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5))
        if !getStartedButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(getStartedButton.isHittable)
        getStartedButton.tap()

        XCTAssertTrue(app.staticTexts["Accessible Home"].waitForExistence(timeout: 10))
    }
}
