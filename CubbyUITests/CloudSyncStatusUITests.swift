import XCTest

final class CloudSyncStatusUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSyncBadgeShowsSyncedWhenForcedAvailable() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: [
            "UI-TESTING",
            "SEED_MOCK_DATA",
            "FORCE_CLOUDKIT_AVAILABILITY_AVAILABLE"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Synced"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSyncBadgeShowsICloudOffWhenForcedNoAccount() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: [
            "UI-TESTING",
            "SEED_MOCK_DATA",
            "FORCE_CLOUDKIT_AVAILABILITY_NO_ACCOUNT"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["iCloud Off"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSyncBadgeShowsOfflineWhenForcedTemporarilyUnavailable() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: [
            "UI-TESTING",
            "SEED_MOCK_DATA",
            "FORCE_CLOUDKIT_AVAILABILITY_TEMP_UNAVAILABLE"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Offline"].waitForExistence(timeout: 10))
    }
}
