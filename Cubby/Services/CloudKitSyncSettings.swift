import Foundation

struct CloudKitSyncSettings: Equatable {
    static let containerIdentifier = "iCloud.com.barronroth.Cubby"
    static let disableLaunchArgument = "DISABLE_CLOUDKIT"

    let usesCloudKit: Bool
    let isInMemory: Bool
    let reason: Reason?

    enum Reason: String {
        case uiTesting
        case disabledByLaunchArgument
        case xctest
    }

    static func isRunningTests(
        environment: [String: String],
        bundlePath: String
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCInjectBundle"] != nil
            || environment["XCInjectBundleInto"] != nil
            || bundlePath.contains("XCTest")
    }

    static func resolve(
        arguments: [String],
        environment: [String: String],
        bundlePath: String,
        isUITesting: Bool,
        isRunningTestsOverride: Bool? = nil
    ) -> CloudKitSyncSettings {
        let runningTests = isRunningTestsOverride
            ?? isRunningTests(environment: environment, bundlePath: bundlePath)
        if runningTests {
            return CloudKitSyncSettings(
                usesCloudKit: false,
                isInMemory: true,
                reason: .xctest
            )
        }

        if isUITesting {
            return CloudKitSyncSettings(
                usesCloudKit: false,
                isInMemory: true,
                reason: .uiTesting
            )
        }

        if arguments.contains(disableLaunchArgument) {
            return CloudKitSyncSettings(
                usesCloudKit: false,
                isInMemory: false,
                reason: .disabledByLaunchArgument
            )
        }

        return CloudKitSyncSettings(
            usesCloudKit: true,
            isInMemory: false,
            reason: nil
        )
    }
}
