import XCTest

final class HomePickerEditTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openManageHomes(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"] + arguments)
        app.launch()

        XCTAssertTrue(app.staticTexts["Main Home"].waitForExistence(timeout: 10))

        app.buttons["Home Picker"].tap()
        let manageHomes = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Manage Homes")).firstMatch
        XCTAssertTrue(manageHomes.waitForExistence(timeout: 5))
        manageHomes.tap()
        XCTAssertTrue(app.navigationBars["Homes"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    func testManageHomesOpensAndCloses() throws {
        let app = openManageHomes()

        XCTAssertTrue(app.staticTexts["Main Home"].waitForExistence(timeout: 5))
        app.navigationBars["Homes"].buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Homes"].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testDeleteHomeControlPresentsConfirmation() throws {
        let app = openManageHomes()

        let row = app.cells.containing(.staticText, identifier: "Main Home").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()

        let deleteButton = app.buttons["Delete Main Home"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        XCTAssertTrue(app.alerts["Delete Home?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["Delete Home?"].buttons["Cancel"].exists)
    }

    @MainActor
    func testLeaveSharedHomeControlPresentsConfirmation() throws {
        let app = openManageHomes(arguments: ["MOCK_SHARED_HOMES_MIXED"])

        let row = app.cells.containing(.staticText, identifier: "Beach House").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()

        let leaveButton = app.buttons["Leave Beach House"]
        XCTAssertTrue(leaveButton.waitForExistence(timeout: 5))
        leaveButton.tap()

        XCTAssertTrue(app.alerts["Leave Shared Home?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["Leave Shared Home?"].buttons["Cancel"].exists)
    }
}
