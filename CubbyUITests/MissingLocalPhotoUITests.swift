import XCTest

final class MissingLocalPhotoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMissingLocalPhotoShowsExplicitPlaceholder() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: [
            "UI-TESTING",
            "SEED_MISSING_LOCAL_PHOTO"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Missing Photo Item"].waitForExistence(timeout: 10))
        app.staticTexts["Missing Photo Item"].tap()

        XCTAssertTrue(app.staticTexts["Photo not on this device yet"].waitForExistence(timeout: 10))
    }
}
