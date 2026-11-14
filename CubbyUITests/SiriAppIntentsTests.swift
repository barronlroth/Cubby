import XCTest

#if compiler(>=6.4) && canImport(AppIntentsTesting)
import AppIntents
import AppIntentsTesting

/// Exercises the registered intents out of process, without invoking Siri's language model.
/// UI-TESTING uses isolated temporary inventory and disables system index publication.
@available(iOS 27.0, *)
final class SiriAppIntentsTests: XCTestCase {
    private static let appBundleIdentifier = "com.barronroth.Cubby"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEntityQueryAndLocateReturnExactSavedLocations() async throws {
        let app = launchSeededApp()
        defer { app.terminate() }
        let definitions = IntentDefinitions(bundleIdentifier: Self.appBundleIdentifier)
        let entities = definitions.entities["InventoryItemEntity"]

        let passport = try await singleEntity(named: "Passport", in: entities)
        let home: String = try passport.homeName
        let location: String = try passport.locationPath
        XCTAssertEqual(home, "Main Home")
        XCTAssertEqual(location, "Home Office > Filing Cabinet")

        let result = try await definitions.intents["LocateInventoryItemIntent"]
            .makeIntent(item: passport)
            .run()
        let savedPath: String = try result.value
        XCTAssertEqual(savedPath, "Main Home > Home Office > Filing Cabinet")

        // Main Home is selected in the UI, but the entity query must include Beach House.
        let surfboard = try await singleEntity(named: "Surfboard", in: entities)
        let otherHome: String = try surfboard.homeName
        XCTAssertEqual(otherHome, "Beach House")
        let otherResult = try await definitions.intents["LocateInventoryItemIntent"]
            .makeIntent(item: surfboard)
            .run()
        let otherPath: String = try otherResult.value
        XCTAssertEqual(otherPath, "Beach House > Beach Equipment Shed")

        let missing = try await entities.entities(matching: "No Such Cubby Fixture Item")
        XCTAssertTrue(missing.isEmpty)
    }

    @MainActor
    func testSystemOpenShowsCrossHomeItemAndItsEntityAnnotation() async throws {
        let app = launchSeededApp()
        defer { app.terminate() }
        let definitions = IntentDefinitions(bundleIdentifier: Self.appBundleIdentifier)
        let entities = definitions.entities["InventoryItemEntity"]
        let surfboard = try await singleEntity(named: "Surfboard", in: entities)

        try await definitions.intents["OpenInventoryItemSystemIntent"]
            .makeIntent(target: surfboard)
            .run()

        XCTAssertTrue(app.buttons["More actions"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Surfboard"].exists)
        XCTAssertTrue(app.staticTexts["Beach Equipment Shed"].exists)
        XCTAssertTrue(app.buttons["Close"].exists)
        let isAnnotated = try await waitForAnnotation(of: surfboard, in: entities)
        XCTAssertTrue(isAnnotated, "The visible item must expose the same entity that the intent opened.")
    }

    @MainActor
    func testSystemSearchShowsAllHomeResultsAndOpensSelectedItem() async throws {
        let app = launchSeededApp()
        defer { app.terminate() }
        let definitions = IntentDefinitions(bundleIdentifier: Self.appBundleIdentifier)
        let entities = definitions.entities["InventoryItemEntity"]
        let surfboard = try await singleEntity(named: "Surfboard", in: entities)

        try await definitions.intents["SearchInventorySystemIntent"]
            .makeIntent(criteria: StringSearchCriteria(term: "Surfboard"))
            .run()

        XCTAssertTrue(app.navigationBars["Search Items"].waitForExistence(timeout: 10))
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "siri-search-result-")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("Surfboard"))
        XCTAssertTrue(row.label.contains("Beach House"))
        let isAnnotated = try await waitForAnnotation(of: surfboard, in: entities)
        XCTAssertTrue(isAnnotated, "Search results must expose their entity identifiers.")

        row.tap()
        XCTAssertTrue(app.buttons["More actions"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Beach Equipment Shed"].exists)
    }

    @MainActor
    func testOrdinaryHomeSearchRowExposesItsEntityAnnotation() async throws {
        let app = launchSeededApp()
        defer { app.terminate() }
        let definitions = IntentDefinitions(bundleIdentifier: Self.appBundleIdentifier)
        let entities = definitions.entities["InventoryItemEntity"]
        let passport = try await singleEntity(named: "Passport", in: entities)

        if !app.searchFields.firstMatch.waitForExistence(timeout: 2) {
            let searchButton = app.buttons["Search"]
            XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
            searchButton.tap()
        }
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("passport")

        XCTAssertTrue(app.staticTexts["Passport"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Roof Cargo Box"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Search Items"].exists)
        let isAnnotated = try await waitForAnnotation(of: passport, in: entities)
        if !isAnnotated { attachPresentationDiagnostics(app, name: "Home search row annotation missing") }
        XCTAssertTrue(isAnnotated, "An ordinary home row must expose its matching inventory entity.")
    }

    @MainActor
    func testOrdinaryDedicatedSearchRowExposesCrossHomeEntityAnnotation() async throws {
        let app = launchSeededApp()
        defer { app.terminate() }
        let definitions = IntentDefinitions(bundleIdentifier: Self.appBundleIdentifier)
        let entities = definitions.entities["InventoryItemEntity"]
        let surfboard = try await singleEntity(named: "Surfboard", in: entities)

        app.buttons["Home Picker"].tap()
        let searchAllItems = app.buttons["Search All Items"]
        XCTAssertTrue(searchAllItems.waitForExistence(timeout: 5))
        searchAllItems.tap()
        XCTAssertTrue(app.staticTexts["Search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["All Homes"].waitForExistence(timeout: 5))
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Surfboard")

        XCTAssertTrue(app.staticTexts["Surfboard"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Search Items"].exists)
        let isAnnotated = try await waitForAnnotation(of: surfboard, in: entities)
        if !isAnnotated { attachPresentationDiagnostics(app, name: "Dedicated search row annotation missing") }
        XCTAssertTrue(isAnnotated, "An ordinary cross-home search row must expose its matching inventory entity.")
    }

    @MainActor
    func testUnsavedAddItemCanBeCancelledWithoutAnIntent() throws {
        let app = launchSeededApp()
        defer { app.terminate() }

        app.buttons["Add Item"].tap()
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Unsaved Siri Test Draft")
        XCTAssertEqual(titleField.value as? String, "Unsaved Siri Test Draft")

        app.buttons["Cancel"].tap()
        let editorClosed = app.navigationBars["Add Item"].waitForNonExistence(timeout: 5)
        if !editorClosed { attachPresentationDiagnostics(app, name: "Control editor did not dismiss") }
        XCTAssertTrue(editorClosed, "Cancelling an unsaved editor must work without an incoming intent.")
        XCTAssertTrue(app.buttons["Add Item"].exists)
    }

    @MainActor
    func testSearchWaitsForUnsavedAddItemToClose() async throws {
        let app = launchSeededApp()
        defer { app.terminate() }
        let definitions = IntentDefinitions(bundleIdentifier: Self.appBundleIdentifier)

        app.buttons["Add Item"].tap()
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Unsaved Siri Test Draft")

        try await definitions.intents["SearchInventorySystemIntent"]
            .makeIntent(criteria: StringSearchCriteria(term: "Surfboard"))
            .run()

        XCTAssertTrue(app.navigationBars["Add Item"].exists)
        XCTAssertEqual(titleField.value as? String, "Unsaved Siri Test Draft")
        XCTAssertFalse(app.navigationBars["Search Items"].exists)

        // User-controlled cancellation, not the intent, closes the editor.
        app.activate()
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertEqual(titleField.value as? String, "Unsaved Siri Test Draft")
        titleField.typeText(" Updated")
        XCTAssertEqual(titleField.value as? String, "Unsaved Siri Test Draft Updated")
        let cancelButton = app.buttons["Cancel"]
        let cancelReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"), object: cancelButton
        )
        XCTAssertEqual(XCTWaiter.wait(for: [cancelReady], timeout: 5), .completed)
        cancelButton.tap()
        let editorClosed = app.navigationBars["Add Item"].waitForNonExistence(timeout: 5)
        if !editorClosed { attachPresentationDiagnostics(app, name: "Editor did not dismiss") }
        XCTAssertTrue(editorClosed)
        let searchPresented = app.navigationBars["Search Items"].waitForExistence(timeout: 10)
        if !searchPresented { attachPresentationDiagnostics(app, name: "Pending search did not present") }
        XCTAssertTrue(searchPresented)
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "siri-search-result-")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("Surfboard"))
    }

    @MainActor
    private func attachPresentationDiagnostics(_ app: XCUIApplication, name: String) {
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name) - accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testDeniedProAccessRejectsPreviouslyWorkingEntityLookup() async throws {
        // Establish that the same registered entity query succeeds before denying access.
        let proApp = launchSeededApp()
        let definitions = IntentDefinitions(bundleIdentifier: Self.appBundleIdentifier)
        _ = try await singleEntity(named: "Passport", in: definitions.entities["InventoryItemEntity"])
        proApp.terminate()

        let freeApp = launchSeededApp(isPro: false)
        defer { freeApp.terminate() }
        var lookupError: Error?
        do {
            _ = try await definitions.entities["InventoryItemEntity"].entities(matching: "Passport")
        } catch {
            lookupError = error
        }

        XCTAssertNotNil(lookupError, "A non-Pro process must reject inventory lookup through App Intents.")
        XCTAssertTrue(freeApp.staticTexts["Start with Cubby Pro"].exists)
        XCTAssertFalse(freeApp.navigationBars["Search Items"].exists)
        // Cross-process error wrapping is framework-owned; service tests assert the exact error.
    }

    @MainActor
    private func launchSeededApp(isPro: Bool = true) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.appBundleIdentifier)
        app.launchArguments = [
            "UI-TESTING",
            "SEED_MOCK_DATA",
            isPro ? "FORCE_PRO_TIER" : "FORCE_FREE_TIER"
        ]
        app.launch()
        if isPro {
            XCTAssertTrue(app.buttons["Add Item"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["Main Home"].exists)
        } else {
            XCTAssertTrue(app.staticTexts["Start with Cubby Pro"].waitForExistence(timeout: 10))
        }
        return app
    }

    @MainActor
    private func singleEntity(named name: String, in definition: AppEntityDefinition) async throws -> AnyAppEntity {
        let matches = try await definition.entities(matching: name)
        XCTAssertEqual(matches.count, 1, "Expected one seeded item named \(name).")
        let entity = try XCTUnwrap(matches.first)
        let title: String = try entity.title
        XCTAssertEqual(title, name)
        return entity
    }

    @MainActor
    private func waitForAnnotation(of entity: AnyAppEntity, in definition: AppEntityDefinition) async throws -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        repeat {
            let annotations = try await definition.viewAnnotations()
            if annotations.contains(where: { $0.entity.identifier == entity.identifier }) {
                return true
            }
            try await Task.sleep(for: .milliseconds(100))
        } while clock.now < deadline
        return false
    }
}
#endif
