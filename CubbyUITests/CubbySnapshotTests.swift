//
//  CubbySnapshotTests.swift
//  CubbyUITests
//
//  Created by OpenAI Codex
//

import XCTest

final class CubbySnapshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTakeSnapshots() throws {
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA"])
        app.launch()

        let addItemButton = app.buttons["Add Item"]
        XCTAssertTrue(addItemButton.waitForExistence(timeout: 10))

        let rolexCell = app.staticTexts["Rolex Submariner"]
        XCTAssertTrue(rolexCell.waitForExistence(timeout: 5))
        snapshot("01-Home")

        rolexCell.tap()
        XCTAssertTrue(app.staticTexts["Rolex Submariner"].waitForExistence(timeout: 5))
        snapshot("02-ItemDetail")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        addItemButton.tap()

        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        snapshot("03-AddItem")
    }
}
