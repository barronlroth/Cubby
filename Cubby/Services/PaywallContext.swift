import Foundation
import SwiftUI

struct PaywallContext: Identifiable, Equatable {
    enum Reason: String, Equatable {
        case subscriptionRequired
        case homeLimitReached
        case itemLimitReached
        case overLimit
        case manualUpgrade
    }

    let id = UUID()
    let reason: Reason

    var isBlocking: Bool {
        reason == .subscriptionRequired
    }
}

private struct ActivePaywallKey: EnvironmentKey {
    static let defaultValue: Binding<PaywallContext?> = .constant(nil)
}

extension EnvironmentValues {
    var activePaywall: Binding<PaywallContext?> {
        get { self[ActivePaywallKey.self] }
        set { self[ActivePaywallKey.self] = newValue }
    }
}
