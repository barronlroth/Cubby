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
    }
}
