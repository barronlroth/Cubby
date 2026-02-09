import Foundation

enum CloudKitStartupPolicy {
    static func shouldFallbackToInMemoryAfterContainerError(
        settings: CloudKitSyncSettings
    ) -> Bool {
        #if DEBUG
        return settings.strictStartup == false
        #else
        return false
        #endif
    }
}
