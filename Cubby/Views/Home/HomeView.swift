import SwiftUI
import UIKit
import CloudKit
#if canImport(UIKit)
import LinkPresentation
#endif

struct LocationSection: Identifiable {
    let id: UUID
    let location: AppStorageLocation
    let locationPath: String
    let items: [AppInventoryItem]
}

struct HomeView: View {
    enum SharedStatusPresentation: Equatable {
        case sharedWithYou
        case shared
        case manage
    }

    @Binding var selectedHome: AppHome?
    @Binding var selectedLocation: AppStorageLocation?
    @Binding var searchText: String
    @Binding var showingAddItem: Bool

    @State private var showingAddLocation = false
    @State private var showingAddHome = false
    @State private var showingProStatus = false
    @State private var activeShareSheet: HomeShareSheetContext?
    @State private var shareErrorMessage: String?
    @State private var preparingShareHomeID: UUID?

    @Environment(\.activePaywall) private var activePaywall
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @Environment(\.sharedHomesGateService) private var sharedHomesGateService

    private let debugMockSharingMode = DebugMockSharingMode.resolve()
    private let sharingErrorHandler = SharingErrorHandler()

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

    static func sharedStatusPresentation(
        isOwnedByCurrentUser: Bool,
        hasExistingShare: Bool,
        isDebugMockSharingEnabled: Bool
    ) -> SharedStatusPresentation {
        guard isOwnedByCurrentUser else {
            return .sharedWithYou
        }

        guard !isDebugMockSharingEnabled else {
            return .shared
        }

        return hasExistingShare ? .manage : .shared
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
                switch context.mode {
                case .mockPreview:
                    MockSharePreviewSheet(title: context.title)
                case let .manage(share):
                    CloudSharingControllerRepresentable(
                        share: share,
                        container: appStore.shareContainer,
                        title: context.title,
                        onSave: { appStore.refresh() },
                        onStopSharing: { appStore.refresh() },
                        onError: handleShareError
                    )
                case let .activity(url):
                    ShareURLActivityControllerRepresentable(
                        url: url,
                        title: context.title
                    )
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

                if let selectedHome {
                    shareControl(for: selectedHome)
                }
            }
            .padding(.top, 8)

            if let selectedHome,
               isSharedHomesEnabled,
               selectedHome.isShared {
                sharedHomeStatusRow(for: selectedHome)
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

    private func handleManageShareTapped(for selectedHome: AppHome) {
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
                mode: .mockPreview,
                title: selectedHome.name
            )
            return
        }

        guard let existingShare = appStore.existingShare(homeID: selectedHome.id) else {
            handleShareError(CKError(.unknownItem))
            return
        }
        presentManageShareSheet(existingShare, title: selectedHome.name)
    }

    @MainActor
    private func prepareAndPresentShareLink(for home: AppHome) async {
        guard preparingShareHomeID == nil else { return }
        preparingShareHomeID = home.id
        defer { preparingShareHomeID = nil }

        do {
            let shareURL = try await appStore.shareURL(homeID: home.id)
            presentShareActivitySheet(shareURL, title: home.name)
        } catch {
            handleShareError(error)
        }
    }

    @ViewBuilder
    private func shareControl(for home: AppHome) -> some View {
        if !canShowShareButton {
            EmptyView()
        } else {
            switch shareManagementAccess {
            case .hidden:
                EmptyView()
            case .upgradeRequired:
                ShareHomeButton {
                    activePaywall.wrappedValue = PaywallContext(reason: .manualUpgrade)
                }
            case .allowed:
                if debugMockSharingMode.isEnabled {
                    ShareHomeButton {
                        activeShareSheet = HomeShareSheetContext(
                            mode: .mockPreview,
                            title: home.name
                        )
                    }
                } else {
                    ShareHomeButton(
                        isLoading: preparingShareHomeID == home.id,
                        action: {
                            Task { await prepareAndPresentShareLink(for: home) }
                        }
                    )
                }
            }
        }
    }

    private func presentManageShareSheet(_ share: CKShare, title: String) {
        activeShareSheet = HomeShareSheetContext(
            mode: .manage(share),
            title: title
        )
    }

    private func presentShareActivitySheet(_ url: URL, title: String) {
        activeShareSheet = HomeShareSheetContext(
            mode: .activity(url),
            title: SharedHomeShareBranding.shareTitle(for: title)
        )
    }

    private func handleShareError(_ error: Error) {
        let presentation = sharingErrorHandler.handle(error: error)
        shareErrorMessage = presentation.message
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
    @ViewBuilder
    private func sharedHomeStatusRow(for home: AppHome) -> some View {
        switch Self.sharedStatusPresentation(
            isOwnedByCurrentUser: home.isOwnedByCurrentUser,
            hasExistingShare: appStore.existingShare(homeID: home.id) != nil,
            isDebugMockSharingEnabled: debugMockSharingMode.isEnabled
        ) {
        case .sharedWithYou:
            SharedHomeStatusRow(
                isSharedWithYou: true
            )
        case .manage:
            Button {
                handleManageShareTapped(for: home)
            } label: {
                SharedHomeStatusRow(
                    isSharedWithYou: false,
                    isManageAction: true
                )
            }
            .buttonStyle(.plain)
        case .shared:
            SharedHomeStatusRow(isSharedWithYou: false)
        }
    }
}

private struct HomeShareSheetContext: Identifiable {
    enum Mode {
        case mockPreview
        case manage(CKShare)
        case activity(URL)
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
    var isManageAction = false

    var body: some View {
        HStack(spacing: 6) {
            Text(isSharedWithYou ? "Shared with you" : "Shared")
            if isManageAction {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
        }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background((isSharedWithYou ? Color.blue : Color.secondary).opacity(0.12))
            .foregroundStyle(isSharedWithYou ? .blue : .secondary)
            .clipShape(Capsule())
    }
}

#if canImport(UIKit)
private struct ShareURLActivityControllerRepresentable: UIViewControllerRepresentable {
    let url: URL
    let title: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let source = ShareURLActivityItemSource(url: url, title: title)
        return UIActivityViewController(
            activityItems: [source],
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

private final class ShareURLActivityItemSource: NSObject, UIActivityItemSource {
    private let url: URL
    private let title: String
    private let iconImage: UIImage?

    init(url: URL, title: String) {
        self.url = url
        self.title = title
        self.iconImage = SharedHomeShareBranding.appIconImage()
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        url
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.originalURL = url
        metadata.url = url
        if let iconImage {
            metadata.iconProvider = NSItemProvider(object: iconImage)
        }
        return metadata
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        title
    }
}
#endif

private struct ShareHomeButton: View {
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ShareHomeButtonLabel(isLoading: isLoading)
        }
        .disabled(isLoading)
        .modifier(ShareHomeButtonStyle())
        .accessibilityLabel("Share Home")
    }
}

private struct ShareHomeButtonLabel: View {
    var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.primary)
            } else {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(.circle)
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
