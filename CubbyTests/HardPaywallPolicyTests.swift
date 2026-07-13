import Testing
@testable import Cubby

@Suite("Hard Paywall Policy Tests")
struct HardPaywallPolicyTests {
    @Test("Pro user after onboarding can access the inventory")
    func proUserAfterOnboardingIsAllowed() {
        let access = HardPaywallPolicy.access(
            hasCompletedOnboarding: true,
            entitlementState: .pro
        )

        #expect(access == .allowed)
    }

    @Test("Non-Pro user after onboarding is blocked by subscription wall")
    func nonProUserAfterOnboardingIsBlocked() {
        let access = HardPaywallPolicy.access(
            hasCompletedOnboarding: true,
            entitlementState: .notPro
        )

        #expect(access == .blocked(.subscriptionRequired))
    }

    @Test("Resolving entitlement after onboarding waits instead of flashing the wall")
    func resolvingEntitlementWaits() {
        let access = HardPaywallPolicy.access(
            hasCompletedOnboarding: true,
            entitlementState: .resolving
        )

        #expect(access == .waitingForEntitlement)
    }

    @Test("Users can finish onboarding before the subscription wall appears")
    func onboardingIsAllowedBeforeSubscriptionWall() {
        let access = HardPaywallPolicy.access(
            hasCompletedOnboarding: false,
            entitlementState: .notPro
        )

        #expect(access == .allowed)
    }
}
