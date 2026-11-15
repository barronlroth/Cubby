import XCTest

/// Measures hitches while flicking through a large home inventory.
/// Hitch numbers are only meaningful on a physical device; simulator runs are
/// useful for relative before/after comparisons.
final class ScrollPerformanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeListScrollPerformance() throws {
        let app = XCUIApplication(bundleIdentifier: "com.barronroth.Cubby")
        app.launchArguments.append(contentsOf: ["UI-TESTING", "SEED_LARGE_INVENTORY", "FORCE_PRO_TIER"])
        app.launch()

        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Adapter 175"].waitForExistence(timeout: 10))

        let options = XCTMeasureOptions()
        options.iterationCount = 5
        options.invocationOptions = [.manuallyStop]

        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            list.swipeUp(velocity: .fast)
            stopMeasuring()
            list.swipeDown(velocity: .fast)
        }
    }
}
