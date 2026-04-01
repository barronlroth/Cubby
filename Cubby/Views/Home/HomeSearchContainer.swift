import SwiftUI

struct HomeSearchContainer: View {
    let cloudKitSettings: CloudKitSyncSettings
    let sharedHomesGateService: any SharedHomesGateServiceProtocol
    let homeSharingService: (any HomeSharingServiceProtocol)?

    @State private var searchText: String = ""
    @State private var showingAddItem = false
    @State private var canAddItem = false
    @State private var activePaywall: PaywallContext?
    @StateObject private var proAccessManager = ProAccessManager()

    init(
        cloudKitSettings: CloudKitSyncSettings,
        sharedHomesGateService: any SharedHomesGateServiceProtocol,
        homeSharingService: (any HomeSharingServiceProtocol)?
    ) {
        self.cloudKitSettings = cloudKitSettings
        self.sharedHomesGateService = sharedHomesGateService
        self.homeSharingService = homeSharingService

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
