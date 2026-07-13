import Testing
@testable import Cubby

@Suite("Pro Access Manager Tests")
struct ProAccessManagerTests {
    @Test("RevenueCat identifiers match the configured catalog")
    @MainActor
    func testRevenueCatIdentifiers() {
        #expect(ProAccessManager.proEntitlementId == "pro")
        #expect(ProAccessManager.annualProductId == "cubby_pro_annual")
        #expect(ProAccessManager.monthlyProductId == "cubby_pro_monthly")
    }

    @Test("XCTest bypass avoids RevenueCat network access and defaults to Pro")
    @MainActor
    func testXCTestBypassDefaultsToPro() {
        let manager = ProAccessManager()

        #expect(manager.isRevenueCatConfigured == false)
        #expect(manager.isPro)
        #expect(manager.entitlementState == .pro)
        #expect(manager.availablePackages.isEmpty)
        #expect(manager.offerings == nil)
    }

    @Test("Launch arguments resolve forced Pro and forced subscription-required states")
    func testForcedProAccessArguments() {
        #expect(ProAccessManager.forcedProAccess(arguments: ["FORCE_PRO_TIER"]) == true)
        #expect(ProAccessManager.forcedProAccess(arguments: ["FORCE_FREE_TIER"]) == false)
        #expect(ProAccessManager.forcedProAccess(arguments: []) == nil)
    }
}
