import AppIntents
import SwiftUI
import UIKit

private struct SiriEligibleItemIDsKey: EnvironmentKey {
    static let defaultValue: Set<UUID> = []
}

private extension EnvironmentValues {
    var siriEligibleItemIDs: Set<UUID> {
        get { self[SiriEligibleItemIDsKey.self] }
        set { self[SiriEligibleItemIDsKey.self] = newValue }
    }
}

/// Resolve eligibility once for the navigation tree, rather than fetching the store per row.
private struct SiriInventoryAnnotationScope: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @State private var eligibleItemIDs: Set<UUID> = []
    @State private var refreshID = UUID()
    @State private var protectedDataAvailable = UIApplication.shared.isProtectedDataAvailable

    func body(content: Content) -> some View {
        content
            .environment(
                \.siriEligibleItemIDs,
                proAccessManager.entitlementState == .pro && scenePhase != .background && protectedDataAvailable
                    ? eligibleItemIDs : []
            )
            .task(id: refreshID) {
                guard scenePhase != .background, protectedDataAvailable,
                      proAccessManager.entitlementState == .pro else { return }
                do {
                    let records = try await SiriInventoryService.shared.entities(matching: "")
                    guard !Task.isCancelled else { return }
                    eligibleItemIDs = Set(records.map(\.id))
                } catch {
                    guard !Task.isCancelled else { return }
                    eligibleItemIDs = []
                }
            }
            .onChange(of: appStore.inventoryRevision) { _, _ in invalidate() }
            .onChange(of: proAccessManager.entitlementState) { _, _ in invalidate() }
            .onChange(of: scenePhase) { _, phase in
                // Siri can make the app inactive while its contents remain onscreen.
                if phase != .inactive { invalidate() }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.protectedDataWillBecomeUnavailableNotification
            )) { _ in
                protectedDataAvailable = false
                invalidate()
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.protectedDataDidBecomeAvailableNotification
            )) { _ in
                protectedDataAvailable = true
                invalidate()
            }
    }

    private func invalidate() {
        eligibleItemIDs = []
        refreshID = UUID()
    }
}

private struct SiriInventoryItemAnnotation: ViewModifier {
    let itemID: UUID
    @Environment(\.siriEligibleItemIDs) private var eligibleItemIDs

    func body(content: Content) -> some View {
        content.appEntityIdentifier(
            eligibleItemIDs.contains(itemID)
                ? EntityIdentifier(for: InventoryItemEntity.self, identifier: itemID)
                : nil
        )
    }
}

extension View {
    func siriInventoryAnnotationScope() -> some View {
        modifier(SiriInventoryAnnotationScope())
    }

    func siriInventoryItem(_ itemID: UUID) -> some View {
        modifier(SiriInventoryItemAnnotation(itemID: itemID))
    }
}
