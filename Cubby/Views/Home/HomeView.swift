import SwiftUI
import UIKit
import CloudKit

struct LocationSection: Identifiable {
    let id: UUID
    let location: AppStorageLocation
    let locationPath: String
    let items: [AppInventoryItem]
}

struct HomeView: View {
    @Binding var selectedHome: AppHome?
    @Binding var selectedLocation: AppStorageLocation?
    @Binding var searchText: String
    @Binding var showingAddItem: Bool

    @State private var showingAddLocation = false
    @State private var showingAddHome = false
    @State private var showingProStatus = false
    @State private var activeShareSheet: HomeShareSheetContext?
    @State private var shareErrorMessage: String?

    @Environment(\.activePaywall) private var activePaywall
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @Environment(\.sharedHomesGateService) private var sharedHomesGateService

    private let debugMockSharingMode = DebugMockSharingMode.resolve()

    private var locationSections: [LocationSection] {
        guard let selectedHome else { return [] }
        let homeItems = appStore.items(in: selectedHome.id)
        let grouped = Dictionary(grouping: homeItems) { $0.storageLocationID }

        return grouped.compactMap { (key, items) -> LocationSection? in
            guard let key,
                  let location = appStore.location(id: key),
                  !items.isEmpty else {
                return nil
            }
            return LocationSection(
                id: location.id,
                location: location,
                locationPath: location.fullPath,
                items: items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            )
        }
        .sorted { $0.locationPath.localizedCaseInsensitiveCompare($1.locationPath) == .orderedAscending }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private var displayedSections: [LocationSection] {
        guard isSearching else { return locationSections }

        return locationSections.compactMap { section -> LocationSection? in
            let matchedItems = section.items.filter(itemMatchesSearch)
            guard !matchedItems.isEmpty else { return nil }
            return LocationSection(
                id: section.location.id,
                location: section.location,
                locationPath: section.locationPath,
                items: matchedItems
            )
        }
    }

    private var isSharedHomesEnabled: Bool {
        sharedHomesGateService.isEnabled()
    }

    private var shareManagementAccess: ShareManagementAccess {
        appStore.shareManagementAccess(
            for: selectedHome,
            isPro: proAccessManager.isPro,
            sharedHomesEnabled: isSharedHomesEnabled
        )
    }

    private var canShowShareButton: Bool {
        shareManagementAccess.showsAffordance
    }

    var body: some View {
        listView(for: displayedSections)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(appBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddLocation) {
                if let homeId = selectedHome?.id {
                    AddLocationView(homeId: homeId, parentLocation: nil)
                }
            }
            .sheet(isPresented: $showingAddHome) {
                AddHomeView(selectedHome: $selectedHome)
            }
            .sheet(isPresented: $showingProStatus) {
                ProStatusView()
            }
            .sheet(isPresented: $showingAddItem) {
                if let homeId = selectedHome?.id {
                    AddItemView(selectedHomeId: homeId, preselectedLocation: nil)
                }
            }
            .sheet(item: $activeShareSheet) { context in
#if canImport(UIKit)
                if debugMockSharingMode.isEnabled {
                    MockSharePreviewSheet(title: context.title)
                } else {
                    switch context.mode {
                    case let .existing(share):
                        CloudSharingControllerRepresentable(
                            share: share,
                            container: appStore.shareContainer,
                            title: context.title,
                            onSave: { appStore.refresh() },
                            onStopSharing: { appStore.refresh() },
                            onError: { error in
                                shareErrorMessage = error.localizedDescription
                            }
                        )
                    case let .new(homeID):
                        CloudSharingControllerRepresentable(
                            title: context.title,
                            preparationHandler: { completion in
                                Task { @MainActor in
                                    do {
                                        let share = try await appStore.shareHome(homeID: homeID)
                                        completion(share, appStore.shareContainer, nil)
                                    } catch HomeSharingServiceError.homeAlreadyShared {
                                        if let existingShare = appStore.existingShare(homeID: homeID) {
                                            completion(existingShare, appStore.shareContainer, nil)
                                        } else {
                                            let error = HomeSharingServiceError.shareCreationFailed
                                            shareErrorMessage = error.localizedDescription
                                            completion(nil, nil, error)
                                        }
                                    } catch {
                                        shareErrorMessage = error.localizedDescription
                                        completion(nil, nil, error)
                                    }
                                }
                            },
                            onSave: { appStore.refresh() },
                            onStopSharing: { appStore.refresh() },
                            onError: { error in
                                shareErrorMessage = error.localizedDescription
                            }
                        )
                    }
                }
#else
                Text("Sharing is unavailable on this platform.")
#endif
            }
            .alert(
                "Share Home Error",
                isPresented: Binding(
                    get: { shareErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            shareErrorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(shareErrorMessage ?? "Unable to share this home.")
            }
            .onChange(of: selectedHome?.id) { _, _ in
                searchText = ""
            }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                HomePicker(
                    selectedHome: $selectedHome,
                    showingAddHome: $showingAddHome,
                    showingProStatus: $showingProStatus
                )
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                if canShowShareButton {
                    ShareHomeButton(action: handleShareHomeTapped)
                }
            }
            .padding(.top, 8)

            if let selectedHome,
               isSharedHomesEnabled,
               selectedHome.isShared {
                SharedHomeStatusRow(
                    isSharedWithYou: !selectedHome.isOwnedByCurrentUser,
                    participantSummary: selectedHome.participantSummary
                )
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var emptyState: some View {
        if isSearching {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("No items match \"\(trimmedSearchText)\" in this home")
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            ContentUnavailableView(
                "No Items",
                systemImage: "shippingbox",
                description: Text("Add items to your storage locations to see them here")
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity, minHeight: 400)
        }
    }

    private func itemMatchesSearch(_ item: AppInventoryItem) -> Bool {
        guard isSearching else { return true }

        if item.title.localizedCaseInsensitiveContains(trimmedSearchText) {
            return true
        }

        if let description = item.itemDescription,
           description.localizedCaseInsensitiveContains(trimmedSearchText) {
            return true
        }

        return false
    }

    private func handleShareHomeTapped() {
        guard let selectedHome else { return }
        switch shareManagementAccess {
        case .hidden:
            return
        case .upgradeRequired:
            activePaywall.wrappedValue = PaywallContext(reason: .manualUpgrade)
            return
        case .allowed:
            break
        }

        if debugMockSharingMode.isEnabled {
            activeShareSheet = HomeShareSheetContext(
                mode: .existing(makeMockShare(for: selectedHome)),
                title: selectedHome.name
            )
            return
        }

        if let existingShare = appStore.existingShare(homeID: selectedHome.id) {
            activeShareSheet = HomeShareSheetContext(
                mode: .existing(existingShare),
                title: selectedHome.name
            )
        } else {
            activeShareSheet = HomeShareSheetContext(
                mode: .new(selectedHome.id),
                title: selectedHome.name
            )
        }
    }

    private func makeMockShare(for home: AppHome) -> CKShare {
        let rootRecord = CKRecord(recordType: "CDHome")
        rootRecord["id"] = home.id.uuidString as CKRecordValue
        let share = CKShare(rootRecord: rootRecord)
        if home.name.isEmpty == false {
            share[CKShare.SystemFieldKey.title] = home.name as CKRecordValue
        }
        return share
    }

    @ViewBuilder
    private func listView(for sections: [LocationSection]) -> some View {
        List {
            header
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            if sections.isEmpty {
                emptyState
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            ItemRow(item: item, showLocation: false)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        LocationSectionHeader(
                            locationPath: section.locationPath,
                            itemCount: section.items.count
                        )
                    }
                }
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    private var appBackground: Color {
        if colorScheme == .light, UIColor(named: "AppBackground") != nil {
            return Color("AppBackground")
        } else {
            return Color(.systemBackground)
        }
    }
}

private struct HomeShareSheetContext: Identifiable {
    enum Mode {
        case existing(CKShare)
        case new(UUID)
    }

    let id = UUID()
    let mode: Mode
    let title: String
}

#if canImport(UIKit)
private struct MockSharePreviewSheet: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mock Share Preview")
                    .font(.headline)
                Text("Home: \(title)")
                Text("This is a UX-only mock. Real invite/accept flow requires iCloud + CloudKit sharing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Share Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif

private struct SharedHomeStatusRow: View {
    let isSharedWithYou: Bool
    let participantSummary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isSharedWithYou ? "Shared with you" : "Shared")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((isSharedWithYou ? Color.blue : Color.secondary).opacity(0.12))
                .foregroundStyle(isSharedWithYou ? .blue : .secondary)
                .clipShape(Capsule())

            if let participantSummary {
                Text(participantSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ShareHomeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .modifier(ShareHomeButtonStyle())
        .accessibilityLabel("Share Home")
    }
}

private struct ShareHomeButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
        }
        #else
        content
        #endif
    }
}

struct HomePicker: View {
    @Binding var selectedHome: AppHome?
    @Binding var showingAddHome: Bool
    @Binding var showingProStatus: Bool

    @Environment(\.activePaywall) private var activePaywall
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        Menu {
            ForEach(appStore.homes) { home in
                Button(action: { selectedHome = home }) {
                    HStack(spacing: 8) {
                        Text(home.name)

                        if let badgeText = shareBadgeText(for: home) {
                            Text(badgeText)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        Spacer()

                        if selectedHome?.id == home.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button(action: { showingProStatus = true }) {
                Label("Cubby Pro", systemImage: "crown")
            }
            Button(action: handleAddHomeTapped) {
                Label("Add New Home", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedHome?.name ?? "Select Home")
                    .font(CubbyTypography.homeTitleSerif)
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
            }
        }
    }

    private func handleAddHomeTapped() {
        let gate = appStore.canCreateHome(isPro: proAccessManager.isPro)
        guard gate.isAllowed else {
            if gate.reason == .overLimit {
                activePaywall.wrappedValue = PaywallContext(reason: .overLimit)
            } else {
                activePaywall.wrappedValue = PaywallContext(reason: .homeLimitReached)
            }
            return
        }
        showingAddHome = true
    }

    private func shareBadgeText(for home: AppHome) -> String? {
        guard home.isShared else { return nil }
        return home.isOwnedByCurrentUser ? "Shared" : "Shared with you"
    }
}
