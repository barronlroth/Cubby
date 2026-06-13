import XCTest

final class HomeSectionCollapseUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLongPressCollapsesAndChevronExpandsStorageSection() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])
        app.launch()

        let garageTitle = app.staticTexts["location-section-title-Garage"]
        XCTAssertTrue(garageTitle.waitForExistence(timeout: 10))

        let cargoBox = app.staticTexts["Roof Cargo Box"]
        XCTAssertTrue(cargoBox.waitForExistence(timeout: 5))

        garageTitle.press(forDuration: 0.7)

        let garageItemCount = app.staticTexts["location-section-count-Garage"]
        XCTAssertTrue(garageItemCount.waitForExistence(timeout: 5))
        XCTAssertEqual(garageItemCount.label, "2 items")
        XCTAssertTrue(cargoBox.waitForNonExistence(timeout: 5))

        app.buttons["location-section-toggle-Garage"].tap()

        XCTAssertTrue(cargoBox.waitForExistence(timeout: 5))
    }
}
