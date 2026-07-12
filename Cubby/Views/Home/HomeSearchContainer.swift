import SwiftUI

struct HomeSearchContainer: View {
    let cloudKitSettings: CloudKitSyncSettings
    let sharedHomesGateService: any SharedHomesGateServiceProtocol
    let homeSharingService: (any HomeSharingServiceProtocol)?

    @State private var searchText: String = ""
    @State private var showingAddItem = false
    @State private var canAddItem = false
    @State private var activePaywall: PaywallContext?
    @StateObject private var proAccessManager: ProAccessManager
    private let initialSelectedHomeID: UUID?

    init(
        cloudKitSettings: CloudKitSyncSettings,
        sharedHomesGateService: any SharedHomesGateServiceProtocol,
        homeSharingService: (any HomeSharingServiceProtocol)?,
        proAccessManager: ProAccessManager? = nil,
        initialSelectedHomeID: UUID? = nil
    ) {
        self.cloudKitSettings = cloudKitSettings
        self.sharedHomesGateService = sharedHomesGateService
        self.homeSharingService = homeSharingService
        self.initialSelectedHomeID = initialSelectedHomeID
        _proAccessManager = StateObject(
            wrappedValue: proAccessManager ?? ProAccessManager()
        )

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
            canAddItem: $canAddItem,
            initialSelectedHomeID: initialSelectedHomeID
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
