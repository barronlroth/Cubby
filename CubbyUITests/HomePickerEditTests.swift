import XCTest

final class HomePickerEditTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testManageHomesEntersAndExitsEditMode() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Main Home"].waitForExistence(timeout: 10))

        app.buttons["Home Picker"].tap()
        XCTAssertTrue(app.buttons["Manage Homes"].waitForExistence(timeout: 5))

        app.buttons["Manage Homes"].tap()
        XCTAssertTrue(app.staticTexts["Edit Homes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete Main Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))

        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Manage Homes"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDeleteHomeControlPresentsConfirmation() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Main Home"].waitForExistence(timeout: 10))

        app.buttons["Home Picker"].tap()
        XCTAssertTrue(app.buttons["Manage Homes"].waitForExistence(timeout: 5))
        app.buttons["Manage Homes"].tap()

        let deleteButton = app.buttons["Delete Main Home"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        XCTAssertTrue(app.alerts["Delete Home?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["Delete Home?"].buttons["Cancel"].exists)
    }

    @MainActor
    func testLeaveSharedHomeControlPresentsConfirmation() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: [
            "UI-TESTING",
            "SEED_MOCK_DATA",
            "FORCE_PRO_TIER",
            "MOCK_SHARED_HOMES_MIXED"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Main Home"].waitForExistence(timeout: 10))

        app.buttons["Home Picker"].tap()
        XCTAssertTrue(app.buttons["Manage Homes"].waitForExistence(timeout: 5))
        app.buttons["Manage Homes"].tap()

        let leaveButton = app.buttons["Leave Beach House"]
        XCTAssertTrue(leaveButton.waitForExistence(timeout: 5))
        leaveButton.tap()

        XCTAssertTrue(app.alerts["Leave Shared Home?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["Leave Shared Home?"].buttons["Cancel"].exists)
    }
}
