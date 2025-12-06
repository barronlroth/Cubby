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
    
    init() {
        let args = ProcessInfo.processInfo.arguments
        // Fastlane snapshot passes "-ui_testing"; support both.
        self.isUITesting = args.contains("UI-TESTING") || args.contains("-ui_testing")
        self.forceOnboardingSnapshot = args.contains("SNAPSHOT_ONBOARDING")
        self.shouldSeedMockData = !forceOnboardingSnapshot && (isUITesting || args.contains("SEED_MOCK_DATA"))

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
                MockDataGenerator.generateMockData(in: modelContainer.mainContext)
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
