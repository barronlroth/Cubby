import XCTest

final class ReorganizeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])
        app.launch()
        return app
    }

    @MainActor
    func testLongPressItemEntersSelectMode() throws {
        let app = launchApp()

        let item = app.staticTexts["Roof Cargo Box"]
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["home-selection-done"].exists)

        item.press(forDuration: 1.0)
        let select = app.buttons["Select"]
        XCTAssertTrue(select.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Move to\u{2026}"].exists)
        select.tap()

        let count = app.staticTexts["home-selection-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "1 Selected")
        XCTAssertTrue(app.buttons["home-selection-move"].isEnabled)

        app.staticTexts["Snow Chains"].tap()
        XCTAssertEqual(count.label, "2 Selected")

        app.buttons["home-selection-done"].tap()
        XCTAssertTrue(app.buttons["Home Picker"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPathBarNavigatesToAncestorsAndHome() throws {
        let app = launchApp()

        let openToolbox = app.buttons["location-section-open-Garage > Workbench > Red Toolbox"]
        XCTAssertTrue(openToolbox.waitForExistence(timeout: 10))
        openToolbox.tap()

        let garageSegment = app.buttons["Garage"]
        XCTAssertTrue(garageSegment.waitForExistence(timeout: 5))
        garageSegment.tap()
        // Garage's own item, which Red Toolbox doesn't hold, proves we navigated.
        XCTAssertTrue(app.staticTexts["Roof Cargo Box"].waitForExistence(timeout: 5))

        // The page underneath keeps its own path bar in the hierarchy; tap the visible one.
        let homeSegments = app.buttons.matching(identifier: "Main Home, top level")
        XCTAssertTrue(homeSegments.firstMatch.waitForExistence(timeout: 5))
        let visibleHome = homeSegments.allElementsBoundByIndex.first { $0.isHittable }
        try XCTUnwrap(visibleHome).tap()
        XCTAssertTrue(app.buttons["Home Picker"].waitForExistence(timeout: 5))
    }
}
