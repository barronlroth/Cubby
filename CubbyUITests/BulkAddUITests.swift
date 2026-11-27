import XCTest

final class BulkAddUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// JSON input skips Apple Intelligence, so this runs the same on any simulator.
    @MainActor
    func testAddFromListReviewsAndSavesCheckedItems() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Main Home"].waitForExistence(timeout: 10))
        app.buttons["Home Picker"].tap()
        let addFromList = app.buttons["Add from a List"]
        XCTAssertTrue(addFromList.waitForExistence(timeout: 5))
        addFromList.tap()

        let editor = app.textViews["bulk-add-text-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(
            #"[{"name": "Snow Chains", "location": "Garage"}, "#
                + #"{"name": "Headlamps (2)", "emoji": "🔦", "location": "Garage > Shelf 2"}, "#
                + #"{"name": "Tent Stakes", "location": "Garage > Shelf 2"}]"#
        )
        attachScreenshot(app, named: "compose")
        app.buttons["bulk-add-next-button"].tap()

        XCTAssertTrue(app.navigationBars["Review Items"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["bulk-add-duplicate-flag"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["New location"].exists)
        let save = app.buttons["bulk-add-save-button"]
        XCTAssertEqual(save.label, "Save 2")
        attachScreenshot(app, named: "review")

        save.tap()
        XCTAssertTrue(app.staticTexts["Headlamps (2)"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Tent Stakes"].exists)
        attachScreenshot(app, named: "saved")
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
