//
//  CubbyApp.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData

@main
struct CubbyApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    let modelContainer: ModelContainer
    private let isUITesting: Bool
    private let cloudKitSettings: CloudKitSyncSettings
    private let shouldSeedMockData: Bool
    private let forceOnboardingSnapshot: Bool
    private let shouldSeedItemLimitReachedData: Bool
    private let shouldSeedFreeTierData: Bool
    private let shouldSeedEmptyHomeData: Bool
    private let skipSeeding: Bool

    private static func logModelContainerError(_ message: String, error: Error) {
        let nsError = error as NSError
        let details = "\(message): \(String(reflecting: error)) (domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo))"
        DebugLogger.error(details)
        NSLog("%@", details)
        if let data = (details + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
    
    init() {
        let args = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let bundlePath = Bundle.main.bundlePath
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCInjectBundle"] != nil
            || environment["XCInjectBundleInto"] != nil
            || bundlePath.contains("XCTest")
            || NSClassFromString("XCTestCase") != nil
        // Fastlane snapshot passes "-ui_testing"; support both.
        self.isUITesting = args.contains("UI-TESTING") || args.contains("-ui_testing")
        self.forceOnboardingSnapshot = args.contains("SNAPSHOT_ONBOARDING")
        self.shouldSeedItemLimitReachedData = args.contains("SEED_ITEM_LIMIT_REACHED")
        self.shouldSeedFreeTierData = args.contains("SEED_FREE_TIER")
        self.shouldSeedEmptyHomeData = args.contains("SEED_EMPTY_HOME")
        self.skipSeeding = args.contains("SKIP_SEEDING") || args.contains("SEED_NONE")
        self.cloudKitSettings = CloudKitSyncSettings.resolve(
            arguments: args,
            environment: environment,
            bundlePath: bundlePath,
            isUITesting: isUITesting,
            isRunningTestsOverride: isRunningTests
        )
        self.shouldSeedMockData = !skipSeeding && !forceOnboardingSnapshot && (
            isUITesting
                || args.contains("SEED_MOCK_DATA")
                || shouldSeedItemLimitReachedData
                || shouldSeedFreeTierData
                || shouldSeedEmptyHomeData
        )

        if isUITesting, let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.synchronize()
        }
        if forceOnboardingSnapshot {
            hasCompletedOnboarding = false
        }

        let schema = Schema([
            Home.self,
            StorageLocation.self,
            InventoryItem.self
        ])

        let modelConfiguration: ModelConfiguration
        if cloudKitSettings.isInMemory {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else if cloudKitSettings.usesCloudKit {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(CloudKitSyncSettings.containerIdentifier)
            )
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .none
            )
        }

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            #if DEBUG
            Self.logModelContainerError("Failed to create ModelContainer", error: error)
            do {
                let fallbackConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [fallbackConfiguration]
                )
            } catch {
                Self.logModelContainerError("Failed to create fallback ModelContainer", error: error)
                fatalError("Failed to create fallback ModelContainer: \(error)")
            }
            #else
            fatalError("Failed to create ModelContainer: \(error)")
            #endif
        }

        if shouldSeedMockData {
            // Recreate data for UI runs so snapshots and previews have content.
            MockDataGenerator.clearAllData(in: modelContainer.mainContext)
            if shouldSeedItemLimitReachedData {
                MockDataGenerator.generateItemLimitReachedMockData(in: modelContainer.mainContext)
            } else if shouldSeedFreeTierData {
                MockDataGenerator.generateFreeTierMockData(in: modelContainer.mainContext)
            } else if shouldSeedEmptyHomeData {
                MockDataGenerator.generateEmptyHomeMockData(in: modelContainer.mainContext)
            } else {
                MockDataGenerator.generateMockData(in: modelContainer.mainContext)
            }
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    HomeSearchContainer()
                } else {
                    OnboardingView()
                }
            }
            .modelContainer(modelContainer)
            .task {
                if cloudKitSettings.usesCloudKit {
                    await CloudKitAvailabilityChecker.logIfUnavailable()
                }
                await DataCleanupService.shared.performCleanup(
                    modelContext: modelContainer.mainContext
                )
            }
        }
    }
}
