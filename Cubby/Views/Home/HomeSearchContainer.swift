import SwiftUI

struct HomeSearchContainer: View {
    let cloudKitSettings: CloudKitSyncSettings
    let sharedHomesGateService: any SharedHomesGateServiceProtocol
    let homeSharingService: (any HomeSharingServiceProtocol)?

    @State private var searchText: String = ""
    @State private var showingAddItem = false
    @State private var canAddItem = false
    @State private var activePaywall: PaywallContext?
    @ObservedObject private var proAccessManager: ProAccessManager
    @EnvironmentObject private var appStore: AppStore
    private let initialSelectedHomeID: UUID?

    init(
        cloudKitSettings: CloudKitSyncSettings,
        sharedHomesGateService: any SharedHomesGateServiceProtocol,
        homeSharingService: (any HomeSharingServiceProtocol)?,
        proAccessManager: ProAccessManager,
        initialSelectedHomeID: UUID? = nil
    ) {
        self.cloudKitSettings = cloudKitSettings
        self.sharedHomesGateService = sharedHomesGateService
        self.homeSharingService = homeSharingService
        self.proAccessManager = proAccessManager
        self.initialSelectedHomeID = initialSelectedHomeID
        let shouldStartBlocking = ProcessInfo.processInfo.arguments.contains("HARD_PAYWALL_PREVIEW")
            || proAccessManager.entitlementState == .notPro
        _activePaywall = State(
            initialValue: shouldStartBlocking
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
        Group {
            if proAccessManager.entitlementState == .resolving {
                EntitlementResolutionView()
            } else {
                MainNavigationView(
                    searchText: $searchText,
                    showingAddItem: $showingAddItem,
                    canAddItem: $canAddItem,
                    initialSelectedHomeID: initialSelectedHomeID
                )
            }
        }
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
        let nextReason = HardPaywallPresentationPolicy.nextReason(
            currentReason: activePaywall?.reason,
            entitlementState: proAccessManager.entitlementState,
            isForced: isHardPaywallPreviewForced
        )

        if activePaywall?.reason != nextReason {
            activePaywall = nextReason.map { PaywallContext(reason: $0) }
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

private struct EntitlementResolutionView: View {
    var body: some View {
        VStack(spacing: CubbyDesign.Spacing.standard) {
            ProgressView()
                .controlSize(.large)

            Text("Checking Cubby Pro")
                .font(CubbyDesign.Typography.sectionTitle)

            Text("Your first item is safe. Cubby is checking your subscription before opening your inventory.")
                .font(CubbyDesign.Typography.bodySmall)
                .foregroundStyle(CubbyDesign.Palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(CubbyDesign.Spacing.xLarge)
        .background(CubbyDesign.Palette.canvas)
        .accessibilityElement(children: .combine)
    }
}
