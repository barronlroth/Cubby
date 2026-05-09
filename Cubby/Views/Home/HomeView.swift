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

    @State private var isPickerPresented = false
    @State private var isEditingHomes = false
    @State private var pendingHomeAction: PendingHomeAction?
    @State private var homeActionErrorMessage: String?
    @State private var isPerformingHomeAction = false

    @Environment(\.activePaywall) private var activePaywall
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        Button {
            isPickerPresented.toggle()
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
        .accessibilityLabel("Home Picker")
        .popover(isPresented: $isPickerPresented, arrowEdge: .top) {
            pickerPanel
                .presentationCompactAdaptation(.popover)
        }
        .alert(
            pendingHomeAction?.confirmationTitle ?? "",
            isPresented: Binding(
                get: { pendingHomeAction != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingHomeAction = nil
                    }
                }
            ),
            presenting: pendingHomeAction
        ) { action in
            Button(action.confirmationButtonTitle, role: .destructive) {
                Task { await perform(action) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.confirmationMessage)
        }
        .alert(
            "Home Update Failed",
            isPresented: Binding(
                get: { homeActionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        homeActionErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(homeActionErrorMessage ?? "Unable to update homes.")
        }
    }

    private var pickerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditingHomes {
                HStack {
                    Text("Edit Homes")
                        .font(.headline.weight(.semibold))

                    Spacer()

                    Button("Done") {
                        isEditingHomes = false
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 10)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(appStore.homes) { home in
                        homeRow(for: home)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, isEditingHomes ? 0 : 12)
            }
            .frame(maxHeight: 360)

            Divider()
                .padding(.horizontal, 18)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 2) {
                utilityRow(title: "Cubby Pro", systemImage: "crown") {
                    isPickerPresented = false
                    showingProStatus = true
                }

                utilityRow(title: "Manage Homes", systemImage: "gearshape") {
                    isEditingHomes = true
                }

                utilityRow(title: "Add New Home", systemImage: "plus") {
                    handleAddHomeTapped()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .frame(width: 320)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func homeRow(for home: AppHome) -> some View {
        if isEditingHomes {
            HStack(spacing: 14) {
                Button {
                    pendingHomeAction = PendingHomeAction(home: home)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.red, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isPerformingHomeAction)
                .accessibilityLabel(PendingHomeAction(home: home).accessibilityLabel)

                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .opacity(selectedHome?.id == home.id ? 1 : 0)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(home.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let badgeText = shareBadgeText(for: home) {
                        Text(badgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: 42)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        } else {
            Button {
                selectedHome = home
                isPickerPresented = false
            } label: {
                HStack(spacing: 10) {
                    Text(home.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let badgeText = shareBadgeText(for: home) {
                        Text(badgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }

                    Spacer(minLength: 12)

                    if selectedHome?.id == home.id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(minHeight: 42)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func utilityRow(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 28)

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if title != "Add New Home" {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minHeight: 42)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        isPickerPresented = false
        showingAddHome = true
    }

    @MainActor
    private func perform(_ action: PendingHomeAction) async {
        guard !isPerformingHomeAction else { return }
        isPerformingHomeAction = true
        defer { isPerformingHomeAction = false }

        do {
            switch action.kind {
            case .delete:
                try await appStore.deleteHome(id: action.home.id)
            case .leave:
                try await appStore.leaveSharedHome(id: action.home.id)
            }
            selectedHome = MainNavigationView.selectionAfterRemovingHome(
                action.home.id,
                currentSelection: selectedHome,
                remainingHomes: appStore.homes
            )
            if appStore.homes.isEmpty {
                isPickerPresented = false
            }
        } catch {
            homeActionErrorMessage = error.localizedDescription
        }
    }

    private func shareBadgeText(for home: AppHome) -> String? {
        guard home.isShared else { return nil }
        return home.isOwnedByCurrentUser ? "Shared" : "Shared with you"
    }
}

private struct PendingHomeAction: Identifiable {
    enum Kind {
        case delete
        case leave
    }

    let id = UUID()
    let home: AppHome
    let kind: Kind

    init(home: AppHome) {
        self.home = home
        if home.isShared && !home.isOwnedByCurrentUser {
            kind = .leave
        } else {
            kind = .delete
        }
    }

    var confirmationTitle: String {
        switch kind {
        case .leave:
            "Leave Shared Home?"
        case .delete where home.isShared:
            "Delete Shared Home for Everyone?"
        case .delete:
            "Delete Home?"
        }
    }

    var confirmationMessage: String {
        switch kind {
        case .leave:
            "You'll lose access to \"\(home.name)\" on this device and through iCloud sharing. The owner's home is not deleted."
        case .delete where home.isShared:
            "This permanently deletes \"\(home.name)\" for you and collaborators. This can't be undone."
        case .delete:
            "This permanently deletes \"\(home.name)\" and every location and item in it. This can't be undone."
        }
    }

    var confirmationButtonTitle: String {
        switch kind {
        case .leave:
            "Leave Home"
        case .delete where home.isShared:
            "Delete Shared Home"
        case .delete:
            "Delete Home"
        }
    }

    var accessibilityLabel: String {
        switch kind {
        case .leave:
            "Leave \(home.name)"
        case .delete:
            "Delete \(home.name)"
        }
    }
}
