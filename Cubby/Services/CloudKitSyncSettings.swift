import Foundation

struct CloudKitSyncSettings: Equatable {
    static let containerIdentifier = "iCloud.com.barronroth.Cubby"
    static let disableLaunchArgument = "DISABLE_CLOUDKIT"
    static let initializeSchemaLaunchArgument = "INIT_CLOUDKIT_SCHEMA"
    static let strictStartupLaunchArgument = "STRICT_CLOUDKIT_STARTUP"
    static let forceAvailabilityAvailableLaunchArgument = "FORCE_CLOUDKIT_AVAILABILITY_AVAILABLE"
    static let forceAvailabilityNoAccountLaunchArgument = "FORCE_CLOUDKIT_AVAILABILITY_NO_ACCOUNT"
    static let forceAvailabilityRestrictedLaunchArgument = "FORCE_CLOUDKIT_AVAILABILITY_RESTRICTED"
    static let forceAvailabilityCouldNotDetermineLaunchArgument = "FORCE_CLOUDKIT_AVAILABILITY_UNKNOWN"
    static let forceAvailabilityTemporarilyUnavailableLaunchArgument = "FORCE_CLOUDKIT_AVAILABILITY_TEMP_UNAVAILABLE"
    static let forceAvailabilityErrorLaunchArgument = "FORCE_CLOUDKIT_AVAILABILITY_ERROR"

    let usesCloudKit: Bool
    let isInMemory: Bool
    let reason: Reason?
    let strictStartup: Bool
    let shouldInitializeCloudKitSchema: Bool
    let forcedAvailability: ForcedAvailability?

    enum Reason: String {
        case uiTesting
        case disabledByLaunchArgument
        case xctest
    }

    enum ForcedAvailability: String {
        case available
        case noAccount
        case restricted
        case couldNotDetermine
        case temporarilyUnavailable
        case error
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
        let strictStartup = arguments.contains(strictStartupLaunchArgument)
        let shouldInitializeCloudKitSchema = arguments.contains(initializeSchemaLaunchArgument)
        let forcedAvailability = parseForcedAvailability(arguments: arguments)

        let runningTests = isRunningTestsOverride
            ?? isRunningTests(environment: environment, bundlePath: bundlePath)
        if runningTests {
            return CloudKitSyncSettings(
                usesCloudKit: false,
                isInMemory: true,
                reason: .xctest,
                strictStartup: strictStartup,
                shouldInitializeCloudKitSchema: shouldInitializeCloudKitSchema,
                forcedAvailability: forcedAvailability
            )
        }

        if isUITesting {
            return CloudKitSyncSettings(
                usesCloudKit: false,
                isInMemory: true,
                reason: .uiTesting,
                strictStartup: strictStartup,
                shouldInitializeCloudKitSchema: shouldInitializeCloudKitSchema,
                forcedAvailability: forcedAvailability
            )
        }

        if arguments.contains(disableLaunchArgument) {
            return CloudKitSyncSettings(
                usesCloudKit: false,
                isInMemory: false,
                reason: .disabledByLaunchArgument,
                strictStartup: strictStartup,
                shouldInitializeCloudKitSchema: shouldInitializeCloudKitSchema,
                forcedAvailability: forcedAvailability
            )
        }

        return CloudKitSyncSettings(
            usesCloudKit: true,
            isInMemory: false,
            reason: nil,
            strictStartup: strictStartup,
            shouldInitializeCloudKitSchema: shouldInitializeCloudKitSchema,
            forcedAvailability: forcedAvailability
        )
    }

    private static func parseForcedAvailability(arguments: [String]) -> ForcedAvailability? {
        if arguments.contains(forceAvailabilityAvailableLaunchArgument) { return .available }
        if arguments.contains(forceAvailabilityNoAccountLaunchArgument) { return .noAccount }
        if arguments.contains(forceAvailabilityRestrictedLaunchArgument) { return .restricted }
        if arguments.contains(forceAvailabilityCouldNotDetermineLaunchArgument) { return .couldNotDetermine }
        if arguments.contains(forceAvailabilityTemporarilyUnavailableLaunchArgument) { return .temporarilyUnavailable }
        if arguments.contains(forceAvailabilityErrorLaunchArgument) { return .error }
        return nil
    }
}
