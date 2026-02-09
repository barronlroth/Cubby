import Testing
@testable import Cubby

struct CloudKitStartupBehaviorTests {
    @Test func testFallbackEnabledWhenStrictStartupDisabled() {
        let settings = CloudKitSyncSettings(
            usesCloudKit: true,
            isInMemory: false,
            reason: nil,
            strictStartup: false,
            shouldInitializeCloudKitSchema: false,
            forcedAvailability: nil
        )

        #expect(
            CloudKitStartupPolicy.shouldFallbackToInMemoryAfterContainerError(
                settings: settings
            ) == true
        )
    }

    @Test func testFallbackDisabledWhenStrictStartupEnabled() {
        let settings = CloudKitSyncSettings(
            usesCloudKit: true,
            isInMemory: false,
            reason: nil,
            strictStartup: true,
            shouldInitializeCloudKitSchema: false,
            forcedAvailability: nil
        )

        #expect(
            CloudKitStartupPolicy.shouldFallbackToInMemoryAfterContainerError(
                settings: settings
            ) == false
        )
    }

    @Test func testSchemaInitializationRequiresCloudKitAndLaunchFlag() {
        let shouldRun = CloudKitSchemaBootstrapper.shouldInitialize(
            settings: CloudKitSyncSettings(
                usesCloudKit: true,
                isInMemory: false,
                reason: nil,
                strictStartup: false,
                shouldInitializeCloudKitSchema: true,
                forcedAvailability: nil
            )
        )

        let skipsWhenCloudKitDisabled = CloudKitSchemaBootstrapper.shouldInitialize(
            settings: CloudKitSyncSettings(
                usesCloudKit: false,
                isInMemory: false,
                reason: .disabledByLaunchArgument,
                strictStartup: false,
                shouldInitializeCloudKitSchema: true,
                forcedAvailability: nil
            )
        )

        let skipsWhenInMemory = CloudKitSchemaBootstrapper.shouldInitialize(
            settings: CloudKitSyncSettings(
                usesCloudKit: true,
                isInMemory: true,
                reason: .uiTesting,
                strictStartup: false,
                shouldInitializeCloudKitSchema: true,
                forcedAvailability: nil
            )
        )

        let skipsWithoutFlag = CloudKitSchemaBootstrapper.shouldInitialize(
            settings: CloudKitSyncSettings(
                usesCloudKit: true,
                isInMemory: false,
                reason: nil,
                strictStartup: false,
                shouldInitializeCloudKitSchema: false,
                forcedAvailability: nil
            )
        )

        #expect(shouldRun == true)
        #expect(skipsWhenCloudKitDisabled == false)
        #expect(skipsWhenInMemory == false)
        #expect(skipsWithoutFlag == false)
    }
}
