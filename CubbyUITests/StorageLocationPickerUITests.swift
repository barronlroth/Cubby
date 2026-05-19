import XCTest

final class StorageLocationPickerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSubLocationCreatedFromItemPickerIsSelected() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])
        app.launch()

        let addItemButton = app.buttons["Add Item"]
        XCTAssertTrue(addItemButton.waitForExistence(timeout: 10))
        addItemButton.tap()

        let locationButton = app.buttons["add-item-location-picker-button"]
        XCTAssertTrue(locationButton.waitForExistence(timeout: 5))
        locationButton.tap()

        let searchField = app.searchFields["Search locations"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Walk-in Closet")

        let addSubLocationButton = app.buttons["Add sub-location under Walk-in Closet"]
        XCTAssertTrue(addSubLocationButton.waitForExistence(timeout: 5))
        addSubLocationButton.tap()

        XCTAssertTrue(app.staticTexts["Add Sub-location"].waitForExistence(timeout: 5))

        let nameField = app.textFields["Sub-location name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Top Shelf")

        app.buttons["save-location-button"].tap()

        XCTAssertTrue(app.staticTexts["Top Shelf"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Done"].tap()

        let updatedLocationButton = app.buttons["add-item-location-picker-button"]
        XCTAssertTrue(updatedLocationButton.waitForExistence(timeout: 5))
        XCTAssertEqual(
            updatedLocationButton.value as? String,
            "Master Bedroom > Walk-in Closet > Top Shelf"
        )
    }
}
