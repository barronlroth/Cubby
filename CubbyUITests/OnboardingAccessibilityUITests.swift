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
            "FORCE_PRO_TIER",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to Cubby"].waitForExistence(timeout: 10))
        let welcomeButton = app.buttons["onboarding-welcome-primary"]
        XCTAssertTrue(welcomeButton.waitForExistence(timeout: 5))
        if welcomeButton.isHittable == false {
            app.swipeUp()
        }
        welcomeButton.tap()

        let homeNameField = app.textFields["onboarding-home-name"]
        XCTAssertTrue(homeNameField.waitForExistence(timeout: 5))
        homeNameField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        homeNameField.typeText("Accessible Home")

        let continueButton = app.buttons["onboarding-home-continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        if continueButton.isHittable == false {
            app.swipeUp()
        }
        XCTAssertTrue(continueButton.isHittable)
        continueButton.tap()

        let itemField = app.textFields["onboarding-item-name"]
        XCTAssertTrue(itemField.waitForExistence(timeout: 5))
        itemField.tap()
        itemField.typeText("Medication")
        let itemContinueButton = app.buttons["onboarding-item-continue"]
        if itemContinueButton.isHittable == false {
            app.swipeUp()
        }
        XCTAssertTrue(itemContinueButton.isHittable)
        itemContinueButton.tap()

        let customLocationField = app.textFields["onboarding-location-custom"]
        XCTAssertTrue(customLocationField.waitForExistence(timeout: 5))
        if customLocationField.isHittable == false {
            app.swipeUp()
        }
        customLocationField.tap()
        customLocationField.typeText("Medicine Cabinet")

        let reviewButton = app.buttons["onboarding-location-review"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 5))
        for _ in 0..<4 where reviewButton.isHittable == false {
            app.swipeUp()
        }
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertTrue(reviewButton.isHittable)
        reviewButton.tap()

        let storeButton = app.buttons["onboarding-store-first-item"]
        XCTAssertTrue(storeButton.waitForExistence(timeout: 5))
        if storeButton.isHittable == false {
            app.swipeUp()
        }
        XCTAssertTrue(storeButton.isHittable)
        storeButton.tap()

        XCTAssertTrue(app.staticTexts["Medication"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testHomeSuggestionScalesAtAccessibilityTextSize() throws {
        let normalApp = launchOnboarding()
        let normalFrame = homeSuggestionFrame(in: normalApp)
        normalApp.terminate()

        let accessibilityApp = launchOnboarding(
            additionalArguments: [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        )
        let accessibilityFrame = homeSuggestionFrame(in: accessibilityApp)

        XCTAssertGreaterThan(
            accessibilityFrame.height,
            normalFrame.height,
            "The relative Cubby font should grow the bordered suggestion chip at Accessibility XXXL."
        )
    }

    @MainActor
    private func launchOnboarding(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments = [
            "UI-TESTING",
            "SNAPSHOT_ONBOARDING",
            "FORCE_PRO_TIER"
        ] + additionalArguments
        app.launch()
        return app
    }

    @MainActor
    private func homeSuggestionFrame(in app: XCUIApplication) -> CGRect {
        XCTAssertTrue(app.staticTexts["Welcome to Cubby"].waitForExistence(timeout: 10))
        app.buttons["onboarding-welcome-primary"].tap()

        let suggestion = app.buttons["Apartment"]
        for _ in 0..<4 where suggestion.exists == false {
            app.swipeUp()
        }
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        return suggestion.frame
    }
}
