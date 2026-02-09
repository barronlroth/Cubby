import SwiftUI

struct HomeSearchContainer: View {
    let cloudKitSettings: CloudKitSyncSettings

    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText: String = ""
    @State private var showingAddItem = false
    @State private var canAddItem = false
    @State private var activePaywall: PaywallContext?
    @StateObject private var proAccessManager = ProAccessManager()
    @StateObject private var cloudSyncCoordinator: CloudSyncCoordinator

    init(cloudKitSettings: CloudKitSyncSettings) {
        self.cloudKitSettings = cloudKitSettings
        _cloudSyncCoordinator = StateObject(
            wrappedValue: CloudSyncCoordinator(
                isCloudKitEnabled: cloudKitSettings.usesCloudKit
                    || cloudKitSettings.forcedAvailability != nil,
                forcedAvailability: cloudKitSettings.forcedAvailability
            )
        )
    }

    var body: some View {
        MainNavigationView(
            searchText: $searchText,
            showingAddItem: $showingAddItem,
            canAddItem: $canAddItem
        )
        .environmentObject(proAccessManager)
        .environmentObject(cloudSyncCoordinator)
        .environment(\.activePaywall, $activePaywall)
        .sheet(item: $activePaywall) { context in
            ProPaywallSheetView(context: context)
                .environmentObject(proAccessManager)
        }
        .task {
            cloudSyncCoordinator.handleScenePhase(scenePhase)
        }
        .onChange(of: scenePhase) { _, newPhase in
            cloudSyncCoordinator.handleScenePhase(newPhase)
        }
        .onDisappear {
            cloudSyncCoordinator.stop()
        }
    }
}
