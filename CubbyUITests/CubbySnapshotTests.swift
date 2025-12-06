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
    func testOnboardingSnapshot() throws {
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        setupSnapshot(app)
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SNAPSHOT_ONBOARDING"])
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to Cubby"].waitForExistence(timeout: 5))
        snapshot("00-Onboarding")
    }

    @MainActor
    func testTakeSnapshots() throws {
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        setupSnapshot(app)
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_MOCK_DATA"])
        app.launch()

        let addItemButton = app.buttons["Add Item"]
        XCTAssertTrue(addItemButton.waitForExistence(timeout: 10))

        let cargoCell = app.staticTexts["Roof Cargo Box"]
        XCTAssertTrue(cargoCell.waitForExistence(timeout: 5))
        snapshot("01-Home")

        cargoCell.tap()
        XCTAssertTrue(app.staticTexts["Roof Cargo Box"].waitForExistence(timeout: 5))
        snapshot("02-ItemDetail")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        addItemButton.tap()

        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        snapshot("03-AddItem")
    }
}
