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
    @Binding var isSelectingItems: Bool

    @State private var showingAddLocation = false
    @State private var showingAddHome = false
    @State private var showingSearch = false
    @State private var showingOptions = false
    @State private var activeShareSheet: HomeShareSheetContext?
    @State private var shareErrorMessage: String?
    @State private var preparingShareHomeID: UUID?
    @State private var collapsedLocationSectionIDs: Set<UUID> = []
    @State private var presentedSheets: Set<BlockingSheet> = []
    @State private var nestedLocationParent: AppStorageLocation?
    @State private var pendingLocationDeletion: AppStorageLocation?
    @State private var locationActionErrorMessage: String?
    @State private var moveSubject: LocationMoveSubject?
    @State private var highlightedLocationID: UUID?
    @State private var highlightGeneration = 0
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var showingBatchDeleteConfirmation = false
    @State private var dragItemID: UUID?
    @State private var dropTargetLocationID: UUID?
    @State private var dropErrorCount = 0

    private enum BlockingSheet {
        case addItem, addLocation, addHome, search, options, sharing, addNestedLocation, move
    }

    @Environment(\.activePaywall) private var activePaywall
    @Environment(\.cubbyReduceMotion) private var reduceMotion
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @Environment(\.sharedHomesGateService) private var sharedHomesGateService
    @Environment(\.undoManager) private var systemUndoManager

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

    private var hasBlockingPresentation: Bool {
        showingAddItem || showingAddLocation || showingAddHome || showingSearch
            || showingOptions || activeShareSheet != nil || shareErrorMessage != nil
            || preparingShareHomeID != nil
            || nestedLocationParent != nil || pendingLocationDeletion != nil
            || moveSubject != nil || showingBatchDeleteConfirmation
            || locationActionErrorMessage != nil
            || !presentedSheets.isEmpty
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
            .background(CubbyDesign.Palette.canvas)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { selectionToolbar }
            .confirmationDialog(
                selectedItemIDs.count == 1 ? "Delete 1 Item?" : "Delete \(selectedItemIDs.count) Items?",
                isPresented: $showingBatchDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: deleteSelectedItems)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can undo this from the banner for a few seconds.")
            }
            .sensoryFeedback(.error, trigger: dropErrorCount)
            .onChange(of: appStore.items) { _, items in
                let existing = Set(items.map(\.id))
                selectedItemIDs.formIntersection(existing)
            }
            .navigationDestination(item: $selectedLocation) { location in
                LocationDetailView(location: location)
            }
            .sheet(isPresented: $showingAddLocation, onDismiss: {
                presentedSheets.remove(.addLocation)
            }) {
                if let homeId = selectedHome?.id {
                    AddLocationView(homeId: homeId, parentLocation: nil)
                        .onAppear { presentedSheets.insert(.addLocation) }
                }
            }
            .sheet(isPresented: $showingAddHome, onDismiss: {
                presentedSheets.remove(.addHome)
            }) {
                AddHomeView(selectedHome: $selectedHome)
                    .onAppear { presentedSheets.insert(.addHome) }
            }
            .sheet(isPresented: $showingSearch, onDismiss: {
                presentedSheets.remove(.search)
            }) {
                SearchView()
                    .onAppear { presentedSheets.insert(.search) }
            }
            .sheet(isPresented: $showingOptions, onDismiss: {
                presentedSheets.remove(.options)
            }) {
                OptionsView(selectedHomeID: selectedHome?.id)
                    .onAppear { presentedSheets.insert(.options) }
            }
            .sheet(isPresented: $showingAddItem, onDismiss: {
                // The binding becomes false before the dismissal animation finishes.
                // Keep Siri deferred until SwiftUI releases the presentation host.
                presentedSheets.remove(.addItem)
            }) {
                if let homeId = selectedHome?.id {
                    AddItemView(selectedHomeId: homeId, preselectedLocation: nil)
                        .onAppear { presentedSheets.insert(.addItem) }
                }
            }
            .sheet(item: $activeShareSheet, onDismiss: {
                presentedSheets.remove(.sharing)
            }) { context in
                Group {
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
                .onAppear { presentedSheets.insert(.sharing) }
            }
            .sheet(item: $nestedLocationParent, onDismiss: {
                presentedSheets.remove(.addNestedLocation)
            }) { parent in
                AddLocationView(homeId: parent.homeID, parentLocation: parent)
                    .onAppear { presentedSheets.insert(.addNestedLocation) }
            }
            .sheet(item: $moveSubject, onDismiss: {
                presentedSheets.remove(.move)
            }) { subject in
                LocationDestinationPicker(subject: subject) { destination in
                    performMove(subject, to: destination)
                }
                .onAppear { presentedSheets.insert(.move) }
            }
            .alert(
                "Delete Location?",
                isPresented: Binding(
                    get: { pendingLocationDeletion != nil },
                    set: { if !$0 { pendingLocationDeletion = nil } }
                ),
                presenting: pendingLocationDeletion
            ) { location in
                Button("Delete", role: .destructive) {
                    CubbyDesign.Haptics.play(.warning)
                    do {
                        try StorageLocationDeletionService.deleteLocationIfAllowed(
                            locationId: location.id,
                            appStore: appStore
                        )
                    } catch {
                        locationActionErrorMessage = error.localizedDescription
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { location in
                Text("This will delete \u{201C}\(location.name)\u{201D}.")
            }
            .alert(
                "Couldn\u{2019}t Update Location",
                isPresented: Binding(
                    get: { locationActionErrorMessage != nil },
                    set: { if !$0 { locationActionErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(locationActionErrorMessage ?? "")
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
                collapsedLocationSectionIDs.removeAll()
                endSelection()
            }
            .siriPresentationBlocker(isPresented: hasBlockingPresentation)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if isSelectingItems {
                    Text(selectedItemIDs.count == 1 ? "1 Selected" : "\(selectedItemIDs.count) Selected")
                        .font(CubbyDesign.Typography.title)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("home-selection-count")
                } else {
                    HomePicker(
                        selectedHome: $selectedHome,
                        showingAddHome: $showingAddHome,
                        showingSearch: $showingSearch,
                        showingOptions: $showingOptions
                    )
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 8)

                if canSelectItems {
                    Button(isSelectingItems ? "Done" : "Select") {
                        if isSelectingItems {
                            endSelection()
                        } else {
                            withAnimation(CubbyDesign.Motion.animation(for: .standard, reduceMotion: reduceMotion)) {
                                isSelectingItems = true
                            }
                        }
                    }
                    .font(CubbyDesign.Typography.bodyEmphasized)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .frame(minHeight: CubbyDesign.Layout.minimumTapTarget)
                    .accessibilityIdentifier("home-select-button")
                }

                if let selectedHome, !isSelectingItems {
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
        ScrollViewReader { proxy in
        // Bind selection only in Select mode so row taps keep navigating otherwise.
        List(selection: isSelectingItems ? $selectedItemIDs : nil) {
            header
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .selectionDisabled()

            if sections.isEmpty {
                emptyState
                    .selectionDisabled()
            } else {
                ForEach(sections) { section in
                    let isCollapsed = isSectionCollapsed(section)
                    Section {
                        if !isCollapsed {
                            ForEach(section.items) { item in
                                ItemRow(
                                    item: item,
                                    showLocation: false,
                                    onMove: canMutateSelectedHome ? { moveSubject = .items([item]) } : nil
                                )
                                .modifier(
                                    ItemDragSource(
                                        item: item,
                                        isEnabled: canMutateSelectedHome && !isSelectingItems,
                                        onDragStart: { dragItemID = item.id }
                                    )
                                )
                                .tag(item.id)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    } header: {
                        LocationSectionHeader(
                            locationPath: section.locationPath,
                            itemCount: section.items.count,
                            isCollapsed: isCollapsed,
                            allowsCollapse: !isSearching,
                            actions: isSelectingItems ? .readOnly : headerActions(for: section.location),
                            dropState: dropState(for: section.location),
                            onCollapse: { collapseSection(section) },
                            onExpand: { expandSection(section) },
                            onSelect: { selectedLocation = section.location }
                        )
                        .background {
                            if highlightedLocationID == section.id {
                                RoundedRectangle(cornerRadius: CubbyDesign.Radius.medium)
                                    .fill(CubbyDesign.Palette.accent.opacity(0.14))
                                    .padding(.horizontal, CubbyDesign.Spacing.small)
                                    .transition(.opacity)
                            }
                        }
                        .modifier(
                            ItemDropTarget(isEnabled: canMutateSelectedHome && !isSelectingItems) { refs in
                                handleItemDrop(refs, onto: section.location)
                            } onTargetChange: { isTargeted in
                                updateDropTarget(section.location, isTargeted: isTargeted)
                            }
                        )
                        .id(section.id)
                    }
                }
            }
        }
        .environment(\.editMode, .constant(isSelectingItems ? .active : .inactive))
        .onChange(of: highlightedLocationID) { _, locationID in
            guard let locationID else { return }
            withAnimation(CubbyDesign.Motion.animation(for: .standard, reduceMotion: reduceMotion)) {
                proxy.scrollTo(locationID, anchor: .center)
            }
        }
        }
    }

    private var canMutateSelectedHome: Bool {
        guard let selectedHome else { return false }
        return (appStore.home(id: selectedHome.id) ?? selectedHome).permission.canMutate
    }

    private func headerActions(for location: AppStorageLocation) -> LocationSectionHeaderActions {
        guard canMutateSelectedHome else { return .readOnly }
        return LocationSectionHeaderActions(
            onRename: { name in
                try InventoryReorganizer.renameLocation(
                    id: location.id,
                    to: name,
                    appStore: appStore,
                    systemUndoManager: systemUndoManager
                )
            },
            onMove: { moveSubject = .location(location) },
            onAddNested: location.depth < StorageLocation.maxNestingDepth - 1
                ? { nestedLocationParent = location }
                : nil,
            onDelete: { pendingLocationDeletion = location },
            canDelete: location.canDelete
        )
    }

    // MARK: Select mode

    private var canSelectItems: Bool {
        canMutateSelectedHome && !locationSections.isEmpty
    }

    private var selectedItems: [AppInventoryItem] {
        guard let selectedHome else { return [] }
        return appStore.items(in: selectedHome.id).filter { selectedItemIDs.contains($0.id) }
    }

    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        if isSelectingItems {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    moveSubject = .items(selectedItems)
                } label: {
                    Text(selectedItemIDs.count == 1 ? "Move 1 Item\u{2026}" : "Move \(selectedItemIDs.count) Items\u{2026}")
                }
                .disabled(selectedItemIDs.isEmpty)
                .accessibilityIdentifier("home-selection-move")
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    showingBatchDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedItemIDs.isEmpty)
                .accessibilityIdentifier("home-selection-delete")
            }
        }
    }

    private func endSelection() {
        withAnimation(CubbyDesign.Motion.animation(for: .standard, reduceMotion: reduceMotion)) {
            isSelectingItems = false
            selectedItemIDs.removeAll()
        }
    }

    private func deleteSelectedItems() {
        let ids = selectedItems.map(\.id)
        guard !ids.isEmpty else { return }
        CubbyDesign.Haptics.play(.warning)
        let snapshots = ids.compactMap(appStore.deleteSnapshot(for:))
        var deleted: [AppDeletedItemSnapshot] = []
        do {
            for snapshot in snapshots {
                try appStore.deleteItem(id: snapshot.itemID)
                deleted.append(snapshot)
            }
        } catch {
            locationActionErrorMessage = error.localizedDescription
        }
        if !deleted.isEmpty {
            UndoManager.shared.record(
                deleted.count == 1 ? .itemDeleted(deleted[0]) : .itemsDeleted(deleted),
                message: deleted.count == 1 ? "\"\(deleted[0].title)\"" : "\(deleted.count) items",
                appStore: nil,
                systemUndoManager: nil
            )
        }
        endSelection()
    }

    // MARK: Drag and drop

    private func isValidItemDrop(itemID: UUID?, onto location: AppStorageLocation) -> Bool {
        guard let itemID, let item = appStore.item(id: itemID) else { return false }
        return item.homeID == location.homeID && item.storageLocationID != location.id
    }

    private func dropState(for location: AppStorageLocation) -> LocationSectionHeader.DropTargetState {
        guard dropTargetLocationID == location.id else { return .none }
        return isValidItemDrop(itemID: dragItemID, onto: location) ? .valid : .invalid
    }

    private func updateDropTarget(_ location: AppStorageLocation, isTargeted: Bool) {
        if isTargeted {
            guard dropTargetLocationID != location.id else { return }
            dropTargetLocationID = location.id
            if isValidItemDrop(itemID: dragItemID, onto: location) {
                CubbyDesign.Haptics.play(.selection)
            }
        } else if dropTargetLocationID == location.id {
            dropTargetLocationID = nil
        }
    }

    private func handleItemDrop(_ refs: [ItemDragRef], onto location: AppStorageLocation) -> Bool {
        dropTargetLocationID = nil
        dragItemID = nil
        let ids = refs.map(\.id).filter { isValidItemDrop(itemID: $0, onto: location) }
        guard !ids.isEmpty else {
            dropErrorCount += 1
            return false
        }
        do {
            try InventoryReorganizer.moveItems(
                ids,
                to: location.id,
                appStore: appStore,
                systemUndoManager: systemUndoManager
            )
            highlight(location.id)
            return true
        } catch {
            dropErrorCount += 1
            locationActionErrorMessage = error.localizedDescription
            return false
        }
    }

    private func performMove(_ subject: LocationMoveSubject, to destination: UUID?) {
        do {
            switch subject {
            case .location(let location):
                try InventoryReorganizer.moveLocation(
                    location,
                    toParent: destination,
                    appStore: appStore,
                    systemUndoManager: systemUndoManager
                )
                highlight(location.id)
            case .items(let items):
                guard let destination else { return }
                try InventoryReorganizer.moveItems(
                    items.map(\.id),
                    to: destination,
                    appStore: appStore,
                    systemUndoManager: systemUndoManager
                )
                highlight(destination)
                endSelection()
            }
        } catch {
            locationActionErrorMessage = error.localizedDescription
        }
    }

    /// Briefly tints the section a change landed in, and scrolls it into view.
    private func highlight(_ locationID: UUID) {
        collapsedLocationSectionIDs.remove(locationID)
        highlightGeneration += 1
        let generation = highlightGeneration
        withAnimation(CubbyDesign.Motion.animation(for: .emphasized, reduceMotion: reduceMotion)) {
            highlightedLocationID = locationID
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard highlightGeneration == generation else { return }
            withAnimation(CubbyDesign.Motion.animation(for: .standard, reduceMotion: reduceMotion)) {
                highlightedLocationID = nil
            }
        }
    }

    private func isSectionCollapsed(_ section: LocationSection) -> Bool {
        !isSearching && collapsedLocationSectionIDs.contains(section.id)
    }

    private func collapseSection(_ section: LocationSection) {
        guard !isSearching else { return }
        withAnimation(CubbyDesign.Motion.animation(for: .quick, reduceMotion: reduceMotion)) {
            _ = collapsedLocationSectionIDs.insert(section.id)
        }
    }

    private func expandSection(_ section: LocationSection) {
        withAnimation(CubbyDesign.Motion.animation(for: .quick, reduceMotion: reduceMotion)) {
            _ = collapsedLocationSectionIDs.remove(section.id)
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

/// Makes an item row draggable as an `ItemDragRef`, with a compact preview.
private struct ItemDragSource: ViewModifier {
    let item: AppInventoryItem
    let isEnabled: Bool
    let onDragStart: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.draggable(ItemDragRef(id: item.id)) {
                ItemDragPreview(item: item)
                    .onAppear(perform: onDragStart)
            }
        } else {
            content
        }
    }
}

struct ItemDragPreview: View {
    let item: AppInventoryItem

    var body: some View {
        HStack(spacing: CubbyDesign.Spacing.small) {
            Text(item.emoji ?? EmojiPicker.emoji(for: item.id))
                .font(.title3)
            Text(item.title)
                .font(CubbyDesign.Typography.bodyCompactEmphasized)
                .lineLimit(1)
        }
        .padding(.horizontal, CubbyDesign.Spacing.medium)
        .padding(.vertical, CubbyDesign.Spacing.small)
        .background(CubbyDesign.Palette.elevatedSurface, in: Capsule())
    }
}

/// Accepts dropped `ItemDragRef`s when enabled.
private struct ItemDropTarget: ViewModifier {
    let isEnabled: Bool
    let onDrop: ([ItemDragRef]) -> Bool
    let onTargetChange: (Bool) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.dropDestination(for: ItemDragRef.self) { refs, _ in
                onDrop(refs)
            } isTargeted: { isTargeted in
                onTargetChange(isTargeted)
            }
        } else {
            content
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
                    .font(.body.weight(.semibold))
                    // The glyph sits in a fixed 44-point glass circle, so it stops
                    // growing at accessibility sizes; Large Content Viewer covers the rest.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(.circle)
        .accessibilityShowsLargeContentViewer {
            Label("Share Home", systemImage: "square.and.arrow.up")
        }
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
    @Binding var showingSearch: Bool
    @Binding var showingOptions: Bool

    @State private var isPickerPresented = false
    @State private var isEditingHomes = false
    @State private var pendingHomeAction: PendingHomeAction?
    @State private var homeActionErrorMessage: String?
    @State private var isPerformingHomeAction = false
    @State private var renamingHomeID: UUID?
    @State private var homeDraftName = ""
    @State private var homeRenameErrorCount = 0
    @FocusState private var isHomeNameFieldFocused: Bool
    @ScaledMetric(relativeTo: .body) private var removeBadgeSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var checkmarkColumnWidth: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var utilityIconColumnWidth: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var pickerPanelWidth: CGFloat = 320
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Environment(\.activePaywall) private var activePaywall
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.undoManager) private var systemUndoManager

    private var hasBlockingPresentation: Bool {
        isPickerPresented || pendingHomeAction != nil || homeActionErrorMessage != nil
            || isPerformingHomeAction
    }

    var body: some View {
        Button {
            isPickerPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(selectedHome?.name ?? "Select Home")
                    .font(CubbyDesign.Typography.title)
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
                CubbyDesign.Haptics.play(.warning)
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
        .sensoryFeedback(.error, trigger: homeRenameErrorCount)
        .onChange(of: isPickerPresented) { _, isPresented in
            if !isPresented { cancelHomeRename() }
        }
        .siriPresentationBlocker(isPresented: hasBlockingPresentation)
    }

    private func beginHomeRename(_ home: AppHome) {
        commitHomeRenameIfNeeded()
        homeDraftName = home.name
        renamingHomeID = home.id
        DispatchQueue.main.async { isHomeNameFieldFocused = true }
    }

    private func commitHomeRenameIfNeeded() {
        guard let homeID = renamingHomeID else { return }
        do {
            let renamed = try InventoryReorganizer.renameHome(
                id: homeID,
                to: homeDraftName,
                appStore: appStore,
                systemUndoManager: systemUndoManager
            )
            if selectedHome?.id == homeID {
                selectedHome = renamed
            }
            CubbyDesign.Haptics.play(.success)
            cancelHomeRename()
        } catch {
            homeRenameErrorCount += 1
            homeActionErrorMessage = error.localizedDescription
        }
    }

    private func cancelHomeRename() {
        renamingHomeID = nil
        homeDraftName = ""
        isHomeNameFieldFocused = false
    }

    private var pickerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditingHomes {
                HStack {
                    Text("Edit Homes")
                        .font(.headline.weight(.semibold))

                    Spacer()

                    Button("Done") {
                        commitHomeRenameIfNeeded()
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
                utilityRow(title: "Search All Items", systemImage: "magnifyingglass") {
                    isPickerPresented = false
                    showingSearch = true
                }

                utilityRow(title: "Options", systemImage: "slider.horizontal.3") {
                    isPickerPresented = false
                    showingOptions = true
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
        // Grow with text size, but never wider than a compact iPhone allows.
        .frame(width: min(pickerPanelWidth, 360))
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
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: removeBadgeSize, height: removeBadgeSize)
                        .background(Color.red, in: Circle())
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
                .disabled(isPerformingHomeAction)
                .accessibilityLabel(PendingHomeAction(home: home).accessibilityLabel)

                Image(systemName: "checkmark")
                    .font(.callout.weight(.semibold))
                    .opacity(selectedHome?.id == home.id ? 1 : 0)
                    .frame(width: checkmarkColumnWidth)

                VStack(alignment: .leading, spacing: 2) {
                    if renamingHomeID == home.id {
                        TextField("Home name", text: $homeDraftName)
                            .font(.body)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .focused($isHomeNameFieldFocused)
                            .onSubmit(commitHomeRenameIfNeeded)
                            .accessibilityLabel("Rename \(home.name)")
                    } else {
                        Text(home.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(homeNameLineLimit)
                    }

                    if let badgeText = shareBadgeText(for: home) {
                        Text(badgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if !home.isOwnedByCurrentUser {
                        Text("Only the owner can rename")
                            .font(CubbyDesign.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                if home.isOwnedByCurrentUser, renamingHomeID != home.id {
                    Button {
                        beginHomeRename(home)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(
                                minWidth: CubbyDesign.Layout.minimumTapTarget,
                                minHeight: CubbyDesign.Layout.minimumTapTarget
                            )
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPerformingHomeAction)
                    .accessibilityLabel("Rename \(home.name)")
                }
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
                        .lineLimit(homeNameLineLimit)

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
                            .font(.callout.weight(.semibold))
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

    private var homeNameLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 3 : 1
    }

    private func utilityRow(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: utilityIconColumnWidth)

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if title != "Add New Home" {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
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
