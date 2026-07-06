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
    @EnvironmentObject private var appStore: AppStore

    init(
        cloudKitSettings: CloudKitSyncSettings,
        sharedHomesGateService: any SharedHomesGateServiceProtocol,
        homeSharingService: (any HomeSharingServiceProtocol)?
    ) {
        self.cloudKitSettings = cloudKitSettings
        self.sharedHomesGateService = sharedHomesGateService
        self.homeSharingService = homeSharingService
        _activePaywall = State(
            initialValue: ProcessInfo.processInfo.arguments.contains("HARD_PAYWALL_PREVIEW")
                ? PaywallContext(reason: .subscriptionRequired)
                : nil
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
            canAddItem: $canAddItem
        )
        .environmentObject(proAccessManager)
        .environment(\.activePaywall, $activePaywall)
        .environment(\.sharedHomesGateService, sharedHomesGateService)
        .environment(\.homeSharingService, homeSharingService)
        .sheet(item: $activePaywall) { context in
            ProPaywallSheetView(context: context)
                .environmentObject(proAccessManager)
                .interactiveDismissDisabled(context.isBlocking)
        }
        .onAppear(perform: reconcileHardPaywall)
        .onChange(of: proAccessManager.entitlementState) { _, _ in
            reconcileHardPaywall()
        }
        .alert(
            "Storage Recovered",
            isPresented: Binding(
                get: { appStore.recoveryMessage != nil },
                set: { isPresented in
                    if isPresented == false {
                        appStore.recoveryMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                appStore.recoveryMessage = nil
            }
        } message: {
            Text(appStore.recoveryMessage ?? "")
        }
    }

    private func reconcileHardPaywall() {
        if isHardPaywallPreviewForced {
            activePaywall = PaywallContext(reason: .subscriptionRequired)
            return
        }

        let access = HardPaywallPolicy.access(
            hasCompletedOnboarding: true,
            entitlementState: proAccessManager.entitlementState
        )

        switch access {
        case .allowed:
            if activePaywall?.isBlocking == true {
                activePaywall = nil
            }
        case .waitingForEntitlement:
            if activePaywall?.isBlocking == true {
                activePaywall = nil
            }
        case let .blocked(reason):
            if activePaywall?.reason != reason {
                activePaywall = PaywallContext(reason: reason)
            }
        }
    }

    private var isHardPaywallPreviewForced: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("HARD_PAYWALL_PREVIEW")
        #else
        false
        #endif
    }
}
