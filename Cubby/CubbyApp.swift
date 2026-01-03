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
    private let shouldSeedMockData: Bool
    private let forceOnboardingSnapshot: Bool
    private let shouldSeedItemLimitReachedData: Bool
    private let shouldSeedFreeTierData: Bool
    private let shouldSeedEmptyHomeData: Bool
    private let skipSeeding: Bool
    
    init() {
        let args = ProcessInfo.processInfo.arguments
        // Fastlane snapshot passes "-ui_testing"; support both.
        self.isUITesting = args.contains("UI-TESTING") || args.contains("-ui_testing")
        self.forceOnboardingSnapshot = args.contains("SNAPSHOT_ONBOARDING")
        self.shouldSeedItemLimitReachedData = args.contains("SEED_ITEM_LIMIT_REACHED")
        self.shouldSeedFreeTierData = args.contains("SEED_FREE_TIER")
        self.shouldSeedEmptyHomeData = args.contains("SEED_EMPTY_HOME")
        self.skipSeeding = args.contains("SKIP_SEEDING") || args.contains("SEED_NONE")
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

        do {
            let schema = Schema([
                Home.self,
                StorageLocation.self,
                InventoryItem.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: isUITesting
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

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
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
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
                await DataCleanupService.shared.performCleanup(
                    modelContext: modelContainer.mainContext
                )
            }
        }
    }
}
