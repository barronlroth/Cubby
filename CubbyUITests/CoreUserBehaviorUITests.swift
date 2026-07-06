import XCTest

final class CoreUserBehaviorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingCreatesFirstHomeAndShowsInventory() throws {
        let app = launchApp(["UI-TESTING", "SNAPSHOT_ONBOARDING", "FORCE_PRO_TIER"])

        XCTAssertTrue(app.staticTexts["Welcome to Cubby"].waitForExistence(timeout: 10))

        let homeNameField = app.textFields["Home Name"]
        XCTAssertTrue(homeNameField.waitForExistence(timeout: 5))
        homeNameField.tap()
        homeNameField.typeText("Lake House")

        submitOnboarding(in: app)

        XCTAssertTrue(app.buttons["Add Item"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Lake House"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No Items"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExistingHomesRecoveryAllowsFreshSetupAfterWait() throws {
        let app = launchApp([
            "UI-TESTING",
            "SNAPSHOT_ONBOARDING",
            "SKIP_SEEDING",
            "FORCE_EXISTING_HOMES_RECOVERY",
            "FORCE_PRO_TIER"
        ])

        XCTAssertTrue(app.staticTexts["Looking for your homes"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Set Up a New Home"].exists)

        let setUpButton = app.buttons["Set Up a New Home"]
        XCTAssertTrue(setUpButton.waitForExistence(timeout: 5))
        setUpButton.tap()

        XCTAssertTrue(app.staticTexts["Welcome to Cubby"].waitForExistence(timeout: 5))
        let homeNameField = app.textFields["Home Name"]
        XCTAssertTrue(homeNameField.waitForExistence(timeout: 5))
        homeNameField.tap()
        homeNameField.typeText("Recovery Home")

        submitOnboarding(in: app)

        XCTAssertTrue(app.buttons["Add Item"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Recovery Home"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRuntimeInitializationFailureShowsRelaunchGuidance() throws {
        let app = launchApp(
            ["UI-TESTING"],
            environment: ["USE_CORE_DATA_SHARING_STACK": "0"]
        )

        let title = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Cubby Could")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["The shared-home data stack failed to initialize. Relaunch the app to try again."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMigrationRecoveryMessageIsShownAndDismissible() throws {
        let app = launchApp([
            "UI-TESTING",
            "SEED_EMPTY_HOME",
            "FORCE_PRO_TIER",
            "FORCE_MIGRATION_RECOVERY_MESSAGE"
        ])

        XCTAssertTrue(app.staticTexts["Storage Recovered"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["We couldn't migrate your existing data. Cubby reset shared-home storage so you can continue."].waitForExistence(timeout: 5))
        app.buttons["OK"].tap()
        XCTAssertTrue(app.staticTexts["Storage Recovered"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add Item"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEmptyHomeShowsUsefulEmptyState() throws {
        let app = launchApp(["UI-TESTING", "SEED_EMPTY_HOME", "FORCE_PRO_TIER"])

        XCTAssertTrue(app.staticTexts["Empty Home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No Items"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Add items to your storage locations to see them here"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add Item"].exists)
    }

    @MainActor
    func testInlineSearchFiltersAndCancelRestoresHomeList() throws {
        let app = launchApp(["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])

        XCTAssertTrue(app.staticTexts["Roof Cargo Box"].waitForExistence(timeout: 10))
        openSearch(in: app)

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("passport")

        XCTAssertTrue(app.staticTexts["Passport"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Roof Cargo Box"].waitForNonExistence(timeout: 5))

        closeSearch(in: app)

        XCTAssertTrue(app.staticTexts["Roof Cargo Box"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDedicatedSearchFindsAcrossHomesAndShowsEmptyStates() throws {
        let app = launchApp(["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])

        openDedicatedSearch(in: app)

        XCTAssertTrue(app.staticTexts["Search Your Items"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["All Homes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Main Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Beach House"].waitForExistence(timeout: 5))

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("no matching cubby item")

        XCTAssertTrue(app.staticTexts["No Results"].waitForExistence(timeout: 5))
        clearActiveSearchField(in: app)

        searchField.tap()
        searchField.typeText("Surfboard")

        XCTAssertTrue(app.staticTexts["Surfboard"].waitForExistence(timeout: 5))

        app.buttons["Main Home"].tap()
        XCTAssertTrue(app.staticTexts["No Results"].waitForExistence(timeout: 5))

        app.buttons["All Homes"].tap()
        XCTAssertTrue(app.staticTexts["Surfboard"].waitForExistence(timeout: 5))

        app.staticTexts["Surfboard"].tap()
        XCTAssertTrue(app.buttons["More actions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Beach Equipment Shed"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddEditDeleteAndUndoItem() throws {
        let app = launchApp(["UI-TESTING", "SEED_EMPTY_HOME", "FORCE_PRO_TIER"])

        createItem(named: "flashlight", description: "garage shelf", in: app)

        XCTAssertTrue(app.staticTexts["Flashlight"].waitForExistence(timeout: 10))
        app.staticTexts["Flashlight"].tap()

        XCTAssertTrue(app.buttons["More actions"].waitForExistence(timeout: 5))
        app.buttons["More actions"].tap()
        app.buttons["Edit"].tap()

        XCTAssertTrue(app.staticTexts["Edit Item"].waitForExistence(timeout: 5))
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(" updated")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Flashlight Updated"].waitForExistence(timeout: 10))

        app.buttons["More actions"].tap()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["Flashlight Updated"].waitForNonExistence(timeout: 10))

        let undoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Undo delete")).firstMatch
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5))
        undoButton.tap()

        XCTAssertTrue(app.staticTexts["Flashlight Updated"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testHomePickerSwitchesHomesAndCanAddHomeWhenPro() throws {
        let app = launchApp(["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])

        XCTAssertTrue(app.staticTexts["Main Home"].waitForExistence(timeout: 10))
        app.buttons["Home Picker"].tap()

        XCTAssertTrue(app.buttons["Beach House"].waitForExistence(timeout: 5))
        app.buttons["Beach House"].tap()
        XCTAssertTrue(app.staticTexts["Surfboard"].waitForExistence(timeout: 5))

        app.buttons["Home Picker"].tap()
        XCTAssertTrue(app.buttons["Add New Home"].waitForExistence(timeout: 5))
        app.buttons["Add New Home"].tap()

        let homeNameField = app.textFields["Home Name"]
        XCTAssertTrue(homeNameField.waitForExistence(timeout: 5))
        homeNameField.tap()
        homeNameField.typeText("Cabin")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Cabin"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No Items"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReadOnlySharedHomeBlocksMutationAffordances() throws {
        let app = launchApp([
            "UI-TESTING",
            "SEED_MOCK_DATA",
            "FORCE_PRO_TIER",
            "MOCK_SHARED_HOMES_READ_ONLY"
        ])

        XCTAssertTrue(app.staticTexts["Main Home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Roof Cargo Box"].waitForExistence(timeout: 5))

        app.staticTexts["Roof Cargo Box"].tap()
        XCTAssertTrue(app.buttons["More actions"].waitForNonExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Add Item"].tap()

        XCTAssertTrue(app.staticTexts["You have read-only access to this shared home."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
    }

    @MainActor
    func testForcedFreeOnboardingShowsNonDismissibleTrialPaywall() throws {
        let app = launchApp(["UI-TESTING", "SNAPSHOT_ONBOARDING", "FORCE_FREE_TIER", "FORCE_FREE_TRIAL_PREVIEW"])

        XCTAssertTrue(app.staticTexts["Welcome to Cubby"].waitForExistence(timeout: 10))

        let homeNameField = app.textFields["Home Name"]
        XCTAssertTrue(homeNameField.waitForExistence(timeout: 5))
        homeNameField.tap()
        homeNameField.typeText("Trial House")

        submitOnboarding(in: app)

        let trialTitle = app.staticTexts["Start your 7-day free trial"]
        XCTAssertTrue(trialTitle.waitForExistence(timeout: 10))
        let requiredCopy = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Cubby Pro is required")).firstMatch
        XCTAssertTrue(requiredCopy.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start 7-Day Free Trial"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Restore Purchase"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Manage Subscription"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Close"].exists)

        app.swipeDown()
        XCTAssertTrue(trialTitle.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Close"].exists)
    }

    @MainActor
    func testOptionsShowsSubscriptionManagementForProUser() throws {
        let app = launchApp(["UI-TESTING", "SEED_EMPTY_HOME", "FORCE_PRO_TIER"])

        XCTAssertTrue(app.staticTexts["Empty Home"].waitForExistence(timeout: 10))
        app.buttons["Home Picker"].tap()

        let optionsButton = app.buttons["Options"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5))
        optionsButton.tap()

        XCTAssertTrue(app.staticTexts["Options"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Active"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Restore Purchases"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Manage Subscription"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["View Subscription Options"].exists)

        let terms = app.buttons["Terms of Use"]
        let privacy = app.buttons["Privacy Policy"]
        if !privacy.exists {
            app.swipeUp()
        }
        XCTAssertTrue(terms.waitForExistence(timeout: 5))
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLocationSectionOpensLocationDetail() throws {
        let app = launchApp(["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])

        XCTAssertTrue(app.staticTexts["Roof Cargo Box"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Garage"].waitForExistence(timeout: 5))
        app.staticTexts["Garage"].tap()

        XCTAssertTrue(app.staticTexts["Nested Locations"].waitForExistence(timeout: 5))

        let itemsHeader = app.staticTexts["Items"]
        scrollToElement(itemsHeader, in: app)
        XCTAssertTrue(itemsHeader.waitForExistence(timeout: 5))
    }

    @MainActor
    func testMoveItemUpdatesDetailLocation() throws {
        let app = launchApp(["UI-TESTING", "SEED_MOCK_DATA", "FORCE_PRO_TIER"])

        openItem(named: "Roof Cargo Box", in: app)
        app.buttons["More actions"].tap()
        app.buttons["Move Item"].tap()

        XCTAssertTrue(app.staticTexts["Select Location"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kitchen"].waitForExistence(timeout: 5))
        app.staticTexts["Kitchen"].tap()
        XCTAssertTrue(app.buttons["Done"].isEnabled)
        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["Select Location"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kitchen"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDismissUndoHidesPrompt() throws {
        let app = launchApp(["UI-TESTING", "SEED_EMPTY_HOME", "FORCE_PRO_TIER"])

        createItem(named: "binoculars", description: "camp shelf", in: app)
        openItem(named: "Binoculars", in: app)
        deleteOpenItem(in: app)

        let undoButton = undoDeleteButton(in: app)
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Dismiss Undo"].waitForExistence(timeout: 5))
        app.buttons["Dismiss Undo"].tap()

        XCTAssertTrue(undoButton.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testTagsCanBeAddedAndSuggestedFromKnownTags() throws {
        let app = launchApp(["UI-TESTING", "SEED_EMPTY_HOME", "FORCE_PRO_TIER"])

        app.buttons["Add Item"].tap()
        fillRequiredItemFields(title: "signal flare", description: "camp box", in: app)
        addTag("Emergency Kit", in: app)
        XCTAssertTrue(app.staticTexts["emergency-kit"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()

        openItem(named: "Signal Flare", in: app)
        XCTAssertTrue(app.staticTexts["emergency-kit"].waitForExistence(timeout: 5))
        tapBack(in: app)

        app.buttons["Add Item"].tap()
        fillRequiredItemFields(title: "water filter", description: "camp box", in: app)

        let tagField = app.textFields["Add tag"]
        scrollToElement(tagField, in: app)
        XCTAssertTrue(tagField.waitForExistence(timeout: 5))
        tagField.tap()
        tagField.typeText("emer")

        let suggestion = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "emergency-kit")).firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        suggestion.tap()

        XCTAssertTrue(app.staticTexts["emergency-kit"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testItemEditValidationDisablesSaveForOverlongTitle() throws {
        let app = launchApp(["UI-TESTING", "SEED_EMPTY_HOME", "FORCE_PRO_TIER"])

        createItem(named: "journal", description: "desk drawer", in: app)
        openItem(named: "Journal", in: app)

        app.buttons["More actions"].tap()
        app.buttons["Edit"].tap()

        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(String(repeating: "x", count: 205))

        XCTAssertTrue(app.staticTexts["Item title must be less than 200 characters"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
    }

    private func launchApp(
        _ arguments: [String],
        environment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: arguments)
        environment.forEach { key, value in
            app.launchEnvironment[key] = value
        }
        app.launch()
        return app
    }

    private func submitOnboarding(in app: XCUIApplication) {
        let keyboardDone = app.keyboards.buttons.matching(
            NSPredicate(format: "label == %@ OR identifier == %@", "done", "Done")
        ).firstMatch

        if keyboardDone.waitForExistence(timeout: 2) {
            keyboardDone.tap()
        } else {
            app.buttons["Get Started"].tap()
        }

        if !app.buttons["Add Item"].waitForExistence(timeout: 5),
           app.buttons["Get Started"].waitForExistence(timeout: 1) {
            app.buttons["Get Started"].tap()
        }
    }

    private func openSearch(in app: XCUIApplication) {
        if app.searchFields.firstMatch.waitForExistence(timeout: 2) {
            return
        }

        let searchButton = app.buttons["Search"]
        if searchButton.waitForExistence(timeout: 5) {
            searchButton.tap()
        }
    }

    private func closeSearch(in app: XCUIApplication) {
        if app.buttons["Cancel Search"].waitForExistence(timeout: 1) {
            app.buttons["Cancel Search"].tap()
        } else if app.buttons["close"].waitForExistence(timeout: 1) {
            app.buttons["close"].tap()
        } else {
            let clearTextButton = app.buttons["Clear text"]
            XCTAssertTrue(clearTextButton.waitForExistence(timeout: 5))
            clearTextButton.tap()
        }
    }

    private func openDedicatedSearch(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Main Home"].waitForExistence(timeout: 10))
        app.buttons["Home Picker"].tap()

        let searchAllItems = app.buttons["Search All Items"]
        XCTAssertTrue(searchAllItems.waitForExistence(timeout: 5))
        searchAllItems.tap()

        XCTAssertTrue(app.staticTexts["Search"].waitForExistence(timeout: 5))
    }

    private func clearActiveSearchField(in app: XCUIApplication) {
        if app.buttons["Clear text"].waitForExistence(timeout: 2) {
            app.buttons["Clear text"].tap()
        } else {
            let searchField = app.searchFields.firstMatch
            XCTAssertTrue(searchField.waitForExistence(timeout: 5))
            searchField.press(forDuration: 1.0)
            app.menuItems["Select All"].tap()
            searchField.typeText(XCUIKeyboardKey.delete.rawValue)
        }
    }

    private func createItem(named title: String, description: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Add Item"].waitForExistence(timeout: 10))
        app.buttons["Add Item"].tap()

        fillRequiredItemFields(title: title, description: description, in: app)

        XCTAssertTrue(app.buttons["Save"].isEnabled)
        app.buttons["Save"].tap()
    }

    private func fillRequiredItemFields(title: String, description: String, in app: XCUIApplication) {
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)

        let descriptionField = app.textFields["Description"]
        XCTAssertTrue(descriptionField.waitForExistence(timeout: 5))
        descriptionField.tap()
        descriptionField.typeText(description)
    }

    private func addTag(_ tag: String, in app: XCUIApplication) {
        let tagField = app.textFields["Add tag"]
        scrollToElement(tagField, in: app, maxSwipes: 8)
        XCTAssertTrue(tagField.waitForExistence(timeout: 5))
        tagField.tap()
        tagField.typeText(tag)

        let addTagButton = app.buttons["Add Tag"]
        XCTAssertTrue(addTagButton.waitForExistence(timeout: 5))
        XCTAssertTrue(addTagButton.isEnabled)
        addTagButton.tap()
    }

    private func openItem(named title: String, in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10))
        app.staticTexts[title].tap()
        XCTAssertTrue(app.buttons["More actions"].waitForExistence(timeout: 5))
    }

    private func deleteOpenItem(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["More actions"].waitForExistence(timeout: 5))
        app.buttons["More actions"].tap()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()
    }

    private func undoDeleteButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Undo delete")).firstMatch
    }

    private func tapBack(in app: XCUIApplication) {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()
    }

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 5) {
        var swipesRemaining = maxSwipes
        while !element.isHittable && swipesRemaining > 0 {
            app.swipeUp()
            swipesRemaining -= 1
        }
    }
}
