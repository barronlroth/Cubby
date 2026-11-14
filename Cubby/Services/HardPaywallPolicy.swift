import Foundation

enum ProEntitlementState: Equatable {
    case resolving
    case pro
    case notPro
}

enum HardPaywallAccess: Equatable {
    case allowed
    case waitingForEntitlement
    case blocked(PaywallContext.Reason)
}

struct HardPaywallPolicy {
    static func access(
        hasCompletedOnboarding: Bool,
        entitlementState: ProEntitlementState
    ) -> HardPaywallAccess {
        guard hasCompletedOnboarding else {
            return .allowed
        }

        switch entitlementState {
        case .resolving:
            return .waitingForEntitlement
        case .pro:
            return .allowed
        case .notPro:
            return .blocked(.subscriptionRequired)
        }
    }
}

struct HardPaywallPresentationPolicy {
    static func nextReason(
        currentReason: PaywallContext.Reason?,
        entitlementState: ProEntitlementState,
        isForced: Bool
    ) -> PaywallContext.Reason? {
        if isForced {
            return .subscriptionRequired
        }

        switch HardPaywallPolicy.access(
            hasCompletedOnboarding: true,
            entitlementState: entitlementState
        ) {
        case .allowed, .waitingForEntitlement:
            return currentReason == .subscriptionRequired ? nil : currentReason
        case .blocked(let reason):
            return reason
        }
    }
}
