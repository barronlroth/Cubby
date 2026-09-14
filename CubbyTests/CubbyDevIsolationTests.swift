import Testing
@testable import Cubby

struct CubbyDevIsolationTests {
    @Test("A dev binary cannot open storage with the production app identity")
    func devRequiresSeparateIdentity() {
        #expect(!CubbyBuildProfile.acceptsBundleIdentifier("com.barronroth.Cubby", isDevBuild: true))
        #expect(!CubbyBuildProfile.acceptsBundleIdentifier(nil, isDevBuild: true))
        #expect(CubbyBuildProfile.acceptsBundleIdentifier("com.barronroth.Cubby.dev", isDevBuild: true))
    }

    @Test("Cold dev launches remain persistent and cannot initialize CloudKit schema")
    func devColdLaunchIsLocal() {
        for arguments in [[], [CloudKitSyncSettings.initializeSchemaLaunchArgument]] {
            let settings = CloudKitSyncSettings.resolve(
                arguments: arguments,
                environment: [:],
                bundlePath: "/Applications/Cubby.app",
                isUITesting: false,
                isRunningTestsOverride: false,
                isDevBuild: true
            )
            #expect(!settings.usesCloudKit)
            #expect(!settings.isInMemory)
            #expect(settings.strictStartup)
            #expect(!CloudKitSchemaBootstrapper.shouldInitialize(settings: settings))
        }
    }

    @Test("Unit tests remain isolated even when testing a dev build")
    func testsTakePrecedenceOverPersistentDevStorage() {
        let settings = CloudKitSyncSettings.resolve(
            arguments: [],
            environment: [:],
            bundlePath: "/Applications/Cubby.app",
            isUITesting: false,
            isRunningTestsOverride: true,
            isDevBuild: true
        )
        #expect(settings.isInMemory)
        #expect(!settings.usesCloudKit)
    }
}
