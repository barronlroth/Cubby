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
    
    init() {
        do {
            let schema = Schema([
                Home.self,
                StorageLocation.self,
                InventoryItem.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainNavigationView()
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
