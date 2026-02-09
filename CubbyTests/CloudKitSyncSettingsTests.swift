import Testing
@testable import Cubby

struct CloudKitSyncSettingsTests {
    @Test func testUsesInMemoryForUiTesting() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [],
            environment: [:],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: true
        )

        #expect(settings.usesCloudKit == false)
        #expect(settings.isInMemory == true)
        #expect(settings.reason == .uiTesting)
        #expect(settings.strictStartup == false)
        #expect(settings.shouldInitializeCloudKitSchema == false)
        #expect(settings.forcedAvailability == nil)
    }

    @Test func testUiTestingOverridesDisableFlag() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [CloudKitSyncSettings.disableLaunchArgument],
            environment: [:],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: true
        )

        #expect(settings.usesCloudKit == false)
        #expect(settings.isInMemory == true)
        #expect(settings.reason == .uiTesting)
        #expect(settings.strictStartup == false)
        #expect(settings.shouldInitializeCloudKitSchema == false)
        #expect(settings.forcedAvailability == nil)
    }

    @Test func testDisableLaunchArgumentUsesLocalStore() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [CloudKitSyncSettings.disableLaunchArgument],
            environment: [:],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false
        )

        #expect(settings.usesCloudKit == false)
        #expect(settings.isInMemory == false)
        #expect(settings.reason == .disabledByLaunchArgument)
        #expect(settings.strictStartup == false)
        #expect(settings.shouldInitializeCloudKitSchema == false)
        #expect(settings.forcedAvailability == nil)
    }

    @Test func testDefaultsToCloudKitWhenNotTesting() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [],
            environment: [:],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false
        )

        #expect(settings.usesCloudKit == true)
        #expect(settings.isInMemory == false)
        #expect(settings.reason == nil)
        #expect(settings.strictStartup == false)
        #expect(settings.shouldInitializeCloudKitSchema == false)
        #expect(settings.forcedAvailability == nil)
    }

    @Test func testXCTestUsesInMemory() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [],
            environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfig"],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false
        )

        #expect(settings.usesCloudKit == false)
        #expect(settings.isInMemory == true)
        #expect(settings.reason == .xctest)
        #expect(settings.strictStartup == false)
        #expect(settings.shouldInitializeCloudKitSchema == false)
        #expect(settings.forcedAvailability == nil)
    }

    @Test func testXCTestBundlePathUsesInMemory() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [],
            environment: [:],
            bundlePath: "/Users/USER/Library/Developer/XCTestDevices/ABC/Containers/Bundle/Application/Cubby.app",
            isUITesting: false
        )

        #expect(settings.usesCloudKit == false)
        #expect(settings.isInMemory == true)
        #expect(settings.reason == .xctest)
        #expect(settings.strictStartup == false)
        #expect(settings.shouldInitializeCloudKitSchema == false)
        #expect(settings.forcedAvailability == nil)
    }

    @Test func testOverrideForcesInMemory() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [],
            environment: [:],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false,
            isRunningTestsOverride: true
        )

        #expect(settings.usesCloudKit == false)
        #expect(settings.isInMemory == true)
        #expect(settings.reason == .xctest)
        #expect(settings.strictStartup == false)
        #expect(settings.shouldInitializeCloudKitSchema == false)
        #expect(settings.forcedAvailability == nil)
    }

    @Test func testOverrideAllowsCloudKit() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [],
            environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfig"],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false,
            isRunningTestsOverride: false
        )

        #expect(settings.usesCloudKit == true)
        #expect(settings.isInMemory == false)
        #expect(settings.reason == nil)
        #expect(settings.strictStartup == false)
        #expect(settings.shouldInitializeCloudKitSchema == false)
        #expect(settings.forcedAvailability == nil)
    }

    @Test func testStrictStartupFlagEnabled() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [CloudKitSyncSettings.strictStartupLaunchArgument],
            environment: [:],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false
        )

        #expect(settings.strictStartup == true)
    }

    @Test func testInitializeSchemaFlagEnabled() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [CloudKitSyncSettings.initializeSchemaLaunchArgument],
            environment: [:],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false
        )

        #expect(settings.shouldInitializeCloudKitSchema == true)
    }

    @Test func testForcedAvailabilityAvailableFlag() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [CloudKitSyncSettings.forceAvailabilityAvailableLaunchArgument],
            environment: [:],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false
        )

        #expect(settings.forcedAvailability == .available)
    }

    @Test func testForcedAvailabilityNoAccountFlag() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [CloudKitSyncSettings.forceAvailabilityNoAccountLaunchArgument],
            environment: [:],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false
        )

        #expect(settings.forcedAvailability == .noAccount)
    }

    @Test func testForcedAvailabilityErrorFlag() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [CloudKitSyncSettings.forceAvailabilityErrorLaunchArgument],
            environment: [:],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false
        )

        #expect(settings.forcedAvailability == .error)
    }

    @Test func testForcedAvailabilityAppliesInTestsToo() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [CloudKitSyncSettings.forceAvailabilityRestrictedLaunchArgument],
            environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfig"],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false
        )

        #expect(settings.reason == .xctest)
        #expect(settings.forcedAvailability == .restricted)
    }
}
