#if DEBUG
import Foundation

enum DesignCatalogDefaults {
    static let suiteName = "com.barronroth.Cubby.DesignCatalog"
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    static let lastUsedHomeIDKey = "lastUsedHomeId"

    static func make(
        suiteName: String = suiteName,
        reset: Bool = false
    ) -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Unable to create Design Catalog defaults suite: \(suiteName)")
        }
        if reset {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
#endif
