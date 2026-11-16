import XCTest

final class HomeSectionCollapseUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTitleTapTogglesStorageSection() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])
        app.launch()

        let garageTitle = app.staticTexts["location-section-title-Garage"]
        XCTAssertTrue(garageTitle.waitForExistence(timeout: 10))

        let cargoBox = app.staticTexts["Roof Cargo Box"]
        XCTAssertTrue(cargoBox.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["location-section-count-Garage"].exists)
        XCTAssertTrue(app.buttons["location-section-open-Garage"].exists)

        garageTitle.tap()

        let garageItemCount = app.staticTexts["location-section-count-Garage"]
        XCTAssertTrue(garageItemCount.waitForExistence(timeout: 5))
        XCTAssertEqual(garageItemCount.label, "2 items")
        XCTAssertTrue(cargoBox.waitForNonExistence(timeout: 5))

        garageTitle.tap()

        XCTAssertTrue(cargoBox.waitForExistence(timeout: 5))
        XCTAssertTrue(garageItemCount.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["location-section-open-Garage"].exists)
    }
}
