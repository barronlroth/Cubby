import SwiftUI

struct HomeSearchContainer: View {
    let cloudKitSettings: CloudKitSyncSettings
    let persistenceController: PersistenceController?

    @State private var searchText: String = ""
    @State private var showingAddItem = false
    @State private var canAddItem = false
    @State private var activePaywall: PaywallContext?
    @StateObject private var proAccessManager = ProAccessManager()
    private let sharedHomesGateService: any SharedHomesGateServiceProtocol
    private let homeSharingService: (any HomeSharingServiceProtocol)?

    init(
        cloudKitSettings: CloudKitSyncSettings,
        persistenceController: PersistenceController? = nil
    ) {
        self.cloudKitSettings = cloudKitSettings
        self.persistenceController = persistenceController
        let args = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let mockSharingMode = DebugMockSharingMode.resolve(
            arguments: args,
            environment: environment
        )

        let resolvedSharedHomesGateService: any SharedHomesGateServiceProtocol
        if mockSharingMode.isEnabled {
            resolvedSharedHomesGateService = SharedHomesGateService(
                arguments: args,
                environment: environment,
                distributionEnabled: true,
                runtimeOverride: true,
                localOverride: true,
                allowLocalOverride: true
            )
            DebugLogger.warning("Running with debug mock sharing mode: \(mockSharingMode)")
        } else {
            resolvedSharedHomesGateService = SharedHomesGateService(
                arguments: args,
                environment: environment
            )
        }
        self.sharedHomesGateService = resolvedSharedHomesGateService

        if mockSharingMode.isEnabled {
            self.homeSharingService = DebugMockHomeSharingService(mode: mockSharingMode)
        } else if resolvedSharedHomesGateService.isEnabled(),
                  PersistenceController.isCoreDataSharingStackEnabled,
                  let persistenceController {
            let service = HomeSharingService(persistenceController: persistenceController)
            self.homeSharingService = service
        } else {
            self.homeSharingService = nil
        }

#if canImport(UIKit)
        let resolvedService = self.homeSharingService
        AppDelegate.makeHomeSharingService = {
            resolvedService
        }
#endif
    }

    var body: some View {
        MainNavigationView(
            searchText: $searchText,
            showingAddItem: $showingAddItem,
            canAddItem: $canAddItem
        )
        .environmentObject(proAccessManager)
        .environment(\.activePaywall, $activePaywall)
        .environment(\.sharedHomesGateService, sharedHomesGateService)
        .environment(\.homeSharingService, homeSharingService)
        .sheet(item: $activePaywall) { context in
            ProPaywallSheetView(context: context)
                .environmentObject(proAccessManager)
        }
    }
}
