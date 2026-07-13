import XCTest

final class UndoAccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testUndoDismissButtonHasMinimumHitRegion() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])
        app.launch()

        let item = app.staticTexts["Roof Cargo Box"]
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        item.tap()

        let moreActions = app.buttons["More actions"]
        XCTAssertTrue(moreActions.waitForExistence(timeout: 5))
        moreActions.tap()

        let deleteMenuItem = app.buttons["Delete"]
        XCTAssertTrue(deleteMenuItem.waitForExistence(timeout: 5))
        deleteMenuItem.tap()

        let deleteConfirmation = app.buttons["Delete"]
        XCTAssertTrue(deleteConfirmation.waitForExistence(timeout: 5))
        deleteConfirmation.tap()

        let dismissUndo = app.buttons["Dismiss undo"]
        XCTAssertTrue(dismissUndo.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(dismissUndo.frame.width, 44)
        XCTAssertGreaterThanOrEqual(dismissUndo.frame.height, 44)
    }
}
