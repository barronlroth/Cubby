import Foundation

#if CUBBY_DEV && !DEBUG
#error("CUBBY_DEV is only supported in a development build.")
#endif

enum CubbyBuildProfile {
    static let devBundleIdentifier = "com.barronroth.Cubby.dev"

    static var isDev: Bool {
        #if CUBBY_DEV
        true
        #else
        false
        #endif
    }

    static func acceptsBundleIdentifier(_ identifier: String?, isDevBuild: Bool = isDev) -> Bool {
        !isDevBuild || identifier == devBundleIdentifier
    }

    /// Check before opening either persistence stack or configuring external services.
    static func validateInstallation() {
        precondition(
            acceptsBundleIdentifier(Bundle.main.bundleIdentifier),
            "Cubby Dev must use com.barronroth.Cubby.dev; refusing to open storage."
        )
    }
}
