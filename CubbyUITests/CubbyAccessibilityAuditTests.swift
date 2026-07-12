import XCTest

final class CubbyAccessibilityAuditTests: XCTestCase {
    private static let bundleIdentifier = "com.barronroth.Cubby"

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testOnboardingAccessibility() throws {
        let app = launch(arguments: ["SNAPSHOT_ONBOARDING"])
        XCTAssertTrue(app.staticTexts["Welcome to Cubby"].waitForExistence(timeout: 10))
        try validateCompactDestinationIfNeeded(app)
        try performCoreAccessibilityAudit(in: app)
    }

    @MainActor
    func testHomeAccessibility() throws {
        let app = launchStandardFixture()
        waitForHome(in: app)
        try validateCompactDestinationIfNeeded(app)
        try performCoreAccessibilityAudit(in: app)
    }

    @MainActor
    func testSearchAccessibility() throws {
        let app = launchStandardFixture()
        waitForHome(in: app)

        let searchField = app.searchFields["Search Items"].firstMatch
        if searchField.waitForExistence(timeout: 2) == false {
            app.buttons["Search"].firstMatch.tap()
        }
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Roof Cargo")
        XCTAssertTrue(app.staticTexts["Roof Cargo Box"].waitForExistence(timeout: 5))

        try validateCompactDestinationIfNeeded(app)
        try performCoreAccessibilityAudit(in: app)
    }

    @MainActor
    func testItemDetailAccessibility() throws {
        let app = launchStandardFixture()
        openItemDetail(in: app)
        try validateCompactDestinationIfNeeded(app)
        try performCoreAccessibilityAudit(in: app)
    }

    @MainActor
    func testItemEditorAccessibility() throws {
        let app = launchStandardFixture()
        openItemDetail(in: app)
        app.buttons["More actions"].tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Item"].waitForExistence(timeout: 5))

        try validateCompactDestinationIfNeeded(app)
        try performCoreAccessibilityAudit(in: app, excluding: .dynamicType)
    }

    @MainActor
    func testLocationPickerAccessibility() throws {
        let app = launchStandardFixture()
        openItemDetail(in: app)
        app.buttons["More actions"].tap()
        XCTAssertTrue(app.buttons["Move Item"].waitForExistence(timeout: 5))
        app.buttons["Move Item"].tap()
        XCTAssertTrue(app.staticTexts["Select Location"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.searchFields["Search locations"].waitForExistence(timeout: 5))

        try validateCompactDestinationIfNeeded(app)
        try performCoreAccessibilityAudit(in: app, excluding: .dynamicType)
    }

    @MainActor
    func testPaywallAccessibility() throws {
        let app = launch(arguments: ["SEED_ITEM_LIMIT_REACHED", "FORCE_FREE_TIER"])
        XCTAssertTrue(app.staticTexts["Test Item 1"].waitForExistence(timeout: 10))
        let addItemButton = app.buttons["Add Item"]
        XCTAssertTrue(addItemButton.waitForExistence(timeout: 5))
        addItemButton.tap()
        XCTAssertTrue(app.staticTexts["Cubby Pro"].waitForExistence(timeout: 10))

        try validateCompactDestinationIfNeeded(app)
        try performCoreAccessibilityAudit(in: app, excluding: .dynamicType)
    }

    @MainActor
    func testOptionsAccessibility() throws {
        let app = launchStandardFixture()
        waitForHome(in: app)
        app.buttons["Home Picker"].tap()
        XCTAssertTrue(app.buttons["Manage Homes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cubby Pro"].waitForExistence(timeout: 5))

        try validateCompactDestinationIfNeeded(app)
        try performCoreAccessibilityAudit(in: app)
    }

    @MainActor
    private func launchStandardFixture() -> XCUIApplication {
        launch(arguments: ["SEED_MOCK_DATA", "FORCE_PRO_TIER"])
    }

    @MainActor
    private func launch(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.bundleIdentifier)
        app.launchArguments = ["UI-TESTING"] + arguments + designConfigurationArguments
        app.launch()
        return app
    }

    @MainActor
    private func waitForHome(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Home Picker"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Roof Cargo Box"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func openItemDetail(in app: XCUIApplication) {
        waitForHome(in: app)
        app.staticTexts["Roof Cargo Box"].firstMatch.tap()
        XCTAssertTrue(app.buttons["More actions"].waitForExistence(timeout: 5))
    }

    private var designConfigurationArguments: [String] {
        switch ProcessInfo.processInfo.environment["CUBBY_DESIGN_VALIDATION_PROFILE"] {
        case "dark":
            ["DESIGN_COLOR_SCHEME_DARK"]
        case "accessibility-text":
            ["DESIGN_DYNAMIC_TYPE_ACCESSIBILITY_3"]
        case "reduce-motion":
            ["DESIGN_REDUCE_MOTION"]
        default:
            []
        }
    }

    @MainActor
    private func performCoreAccessibilityAudit(
        in app: XCUIApplication,
        excluding excludedTypes: XCUIAccessibilityAuditType = []
    ) throws {
        var auditTypes: XCUIAccessibilityAuditType = [
            .elementDetection,
            .hitRegion,
            .sufficientElementDescription,
            .dynamicType,
            .trait
        ]
        auditTypes.subtract(excludedTypes)
        if ProcessInfo.processInfo.environment["CUBBY_DESIGN_VALIDATION_PROFILE"] == "accessibility-text" {
            // The app is already running at an accessibility content size. Asking the
            // audit to apply another Dynamic Type sweep is unsupported on iOS 26.2.
            auditTypes.remove(.dynamicType)
        }
        try app.performAccessibilityAudit(for: auditTypes) { issue in
            if issue.auditType == .dynamicType,
               let label = issue.element?.label,
               ["Cancel", "Done"].contains(label) {
                // System toolbar labels use UIKit-managed sizing and are flagged on iOS 26.2.
                return true
            }

            if issue.auditType == .hitRegion,
               issue.detailedDescription.contains("_UITextFieldClearButton") {
                // The system-owned searchable clear button reports its glyph bounds, not its hit slop.
                return true
            }

            if issue.auditType == .sufficientElementDescription,
               issue.detailedDescription.contains("TUIPredictionViewCell") {
                // Keyboard prediction cells are owned by UIKit and appear only while search is focused.
                return true
            }

            return false
        }
    }

    @MainActor
    private func validateCompactDestinationIfNeeded(_ app: XCUIApplication) throws {
        guard ProcessInfo.processInfo.environment["CUBBY_DESIGN_VALIDATION_PROFILE"] == "compact" else {
            return
        }

        let width = app.windows.firstMatch.frame.width
        guard width <= 390 else {
            throw XCTSkip(
                "Compact Device configuration requires a compact iPhone run destination (width 390 points or less)."
            )
        }
    }
}
