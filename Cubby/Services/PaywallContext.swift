import Foundation
import SwiftUI

struct PaywallContext: Identifiable, Equatable {
    enum Reason: String, Equatable {
        case homeLimitReached
        case itemLimitReached
        case overLimit
    }

    let id = UUID()
    let reason: Reason
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

