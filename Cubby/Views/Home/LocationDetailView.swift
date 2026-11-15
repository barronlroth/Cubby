import SwiftUI

struct LocationDetailView: View {
    let location: AppStorageLocation

    @State private var showingAddItem = false
    @State private var showingAddLocation = false
    @State private var addItemSheetActive = false
    @State private var addLocationSheetActive = false
    @State private var draftTitle = ""
    @State private var renameErrorCount = 0
    @State private var showingDeleteConfirmation = false
    @State private var locationActionErrorMessage: String?

    @State private var moveSubject: LocationMoveSubject?
    @State private var dragLocationID: UUID?
    /// `.some(nil)` is the home (top level); nil means nothing is targeted.
    @State private var dropTarget: UUID??
    @State private var dropErrorCount = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var systemUndoManager

    @Environment(\.activePaywall) private var activePaywall
    @Environment(\.sharedHomesGateService) private var sharedHomesGateService
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @EnvironmentObject private var appStore: AppStore

    private var resolvedLocation: AppStorageLocation? {
        appStore.location(id: location.id)
    }

    private var items: [AppInventoryItem] {
        appStore.items(inLocation: location.id)
    }

    private var childLocations: [AppStorageLocation] {
        appStore.childLocations(of: location.id)
    }

    private var home: AppHome? {
        appStore.home(id: resolvedLocation?.homeID ?? location.homeID)
    }

    private var canMutateLocation: Bool {
        guard sharedHomesGateService.isEnabled() else { return true }
        guard let home else { return true }
        return home.permission.canMutate
    }

    private var currentName: String {
        resolvedLocation?.name ?? location.name
    }

    var body: some View {
        content
            .modifier(
                LocationTitleModifier(
                    title: currentName,
                    isRenamable: canMutateLocation,
                    draftTitle: $draftTitle,
                    menu: { titleMenu }
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { draftTitle = currentName }
            .onChange(of: currentName) { _, newName in draftTitle = newName }
            .onChange(of: draftTitle) { _, newTitle in commitTitle(newTitle) }
            .sensoryFeedback(.error, trigger: renameErrorCount)
            .sheet(item: $moveSubject) { subject in
                LocationDestinationPicker(subject: subject) { destination in
                    performMove(subject, to: destination)
                }
            }
            .alert("Delete Location?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive, action: deleteLocation)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete \u{201C}\(currentName)\u{201D}.")
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
    }

    @ViewBuilder
    private var titleMenu: some View {
        RenameButton()
        Button {
            moveSubject = .location(resolvedLocation ?? location)
        } label: {
            Label("Move to\u{2026}", systemImage: "folder")
        }
        Divider()
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .disabled(!(resolvedLocation ?? location).canDelete)
    }

    private func commitTitle(_ newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canMutateLocation, trimmed != currentName else { return }
        do {
            try InventoryReorganizer.renameLocation(
                id: location.id,
                to: trimmed,
                appStore: appStore,
                systemUndoManager: systemUndoManager
            )
        } catch {
            renameErrorCount += 1
            draftTitle = currentName
            locationActionErrorMessage = error.localizedDescription
        }
    }

    // MARK: Path bar and drag and drop

    /// The home (top level), then every ancestor, then this location.
    private var pathSegments: [(id: UUID?, name: String)] {
        let current = resolvedLocation ?? location
        let ancestors = appStore.ancestorLocations(of: current.id).map { (id: Optional($0.id), name: $0.name) }
        return [(id: nil, name: home?.name ?? current.homeName)] + ancestors + [(id: Optional(current.id), name: current.name)]
    }

    private var pathBar: some View {
        let segments = pathSegments
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CubbyDesign.Spacing.xSmall) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    let isCurrent = index == segments.count - 1
                    let isTargeted = !isCurrent && dropTarget == .some(segment.id)
                        && isValidLocationDrop(dragLocationID, toParent: segment.id)
                    Label {
                        Text(segment.name)
                            .font(isCurrent ? CubbyDesign.Typography.captionEmphasized : CubbyDesign.Typography.caption)
                            .lineLimit(1)
                    } icon: {
                        if index == 0 {
                            Image(systemName: "house")
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(isTargeted ? Color.white : (isCurrent ? Color.primary : Color.secondary))
                    .padding(.horizontal, CubbyDesign.Spacing.small)
                    .padding(.vertical, CubbyDesign.Spacing.xSmall)
                    .frame(minHeight: CubbyDesign.Layout.compactIcon + CubbyDesign.Spacing.small)
                    .background {
                        Capsule().fill(isTargeted ? CubbyDesign.Palette.accent : Color.clear)
                    }
                    .contentShape(Capsule())
                    .modifier(
                        PathSegmentDropTarget(isEnabled: canMutateLocation && !isCurrent) { refs in
                            handleLocationDrop(refs, toParent: segment.id)
                        } onTargetChange: { targeted in
                            updateDropTarget(segment.id, isTargeted: targeted)
                        }
                    )
                    .accessibilityLabel(index == 0 ? "\(segment.name), top level" : segment.name)

                    if !isCurrent {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, CubbyDesign.Spacing.xSmall)
        }
        .cubbyAnimation(.quick, value: dropTarget)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Path")
    }

    private func isValidLocationDrop(_ draggedID: UUID?, toParent parentID: UUID?) -> Bool {
        guard let draggedID, draggedID != parentID,
              let dragged = appStore.location(id: draggedID),
              dragged.parentLocationID != parentID else { return false }
        return appStore.canMoveLocation(id: draggedID, toParent: parentID)
    }

    private func updateDropTarget(_ parentID: UUID?, isTargeted: Bool) {
        if isTargeted {
            guard dropTarget != .some(parentID) else { return }
            dropTarget = .some(parentID)
            if isValidLocationDrop(dragLocationID, toParent: parentID) {
                CubbyDesign.Haptics.play(.selection)
            }
        } else if dropTarget == .some(parentID) {
            dropTarget = nil
        }
    }

    private func handleLocationDrop(_ refs: [LocationDragRef], toParent parentID: UUID?) -> Bool {
        dropTarget = nil
        dragLocationID = nil
        guard let ref = refs.first,
              isValidLocationDrop(ref.id, toParent: parentID),
              let dragged = appStore.location(id: ref.id) else {
            dropErrorCount += 1
            return false
        }
        do {
            try InventoryReorganizer.moveLocation(
                dragged,
                toParent: parentID,
                appStore: appStore,
                systemUndoManager: systemUndoManager
            )
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
            case .location(let moving):
                try InventoryReorganizer.moveLocation(
                    moving,
                    toParent: destination,
                    appStore: appStore,
                    systemUndoManager: systemUndoManager
                )
            case .items(let items):
                guard let destination else { return }
                try InventoryReorganizer.moveItems(
                    items.map(\.id),
                    to: destination,
                    appStore: appStore,
                    systemUndoManager: systemUndoManager
                )
            }
        } catch {
            locationActionErrorMessage = error.localizedDescription
        }
    }

    private func deleteLocation() {
        CubbyDesign.Haptics.play(.warning)
        do {
            try StorageLocationDeletionService.deleteLocationIfAllowed(
                locationId: location.id,
                appStore: appStore
            )
            dismiss()
        } catch {
            locationActionErrorMessage = error.localizedDescription
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !childLocations.isEmpty || location.depth < StorageLocation.maxNestingDepth {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Nested Locations")
                                .font(.headline)
                            Spacer()
                            if canMutateLocation, location.depth < StorageLocation.maxNestingDepth {
                                Button(action: { showingAddLocation = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }

                        if !childLocations.isEmpty {
                            ForEach(childLocations) { childLocation in
                                NavigationLink(destination: LocationDetailView(location: childLocation)) {
                                    NestedLocationCard(
                                        location: childLocation,
                                        isDropTarget: dropTarget == .some(childLocation.id)
                                            && isValidLocationDrop(dragLocationID, toParent: childLocation.id)
                                    )
                                }
                                .buttonStyle(.plain)
                                .modifier(
                                    LocationDragAndDrop(
                                        location: childLocation,
                                        isEnabled: canMutateLocation,
                                        onDragStart: { dragLocationID = childLocation.id },
                                        onDrop: { refs in handleLocationDrop(refs, toParent: childLocation.id) },
                                        onTargetChange: { updateDropTarget(childLocation.id, isTargeted: $0) }
                                    )
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Items")
                        .font(.headline)
                        .padding(.horizontal)

                    if items.isEmpty {
                        ContentUnavailableView(
                            "No Items",
                            systemImage: "shippingbox",
                            description: Text("Add items to this location to keep track of them")
                        )
                        .frame(minHeight: 200)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { item in
                                ItemRow(
                                    item: item,
                                    onMove: canMutateLocation ? { moveSubject = .items([item]) } : nil
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .toolbar {
            if canMutateLocation {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: handleAddItemTapped) {
                            Label("Add Item", systemImage: "plus")
                        }
                        if location.depth < StorageLocation.maxNestingDepth {
                            Button(action: { showingAddLocation = true }) {
                                Label("Add Nested Location", systemImage: "folder.badge.plus")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem, onDismiss: { addItemSheetActive = false }) {
            AddItemView(
                selectedHomeId: home?.id,
                preselectedLocation: resolvedLocation ?? location
            )
            .onAppear { addItemSheetActive = true }
        }
        .sheet(isPresented: $showingAddLocation, onDismiss: { addLocationSheetActive = false }) {
            AddLocationView(homeId: home?.id, parentLocation: resolvedLocation ?? location)
                .onAppear { addLocationSheetActive = true }
        }
        .siriPresentationBlocker(
            isPresented: showingAddItem || showingAddLocation || addItemSheetActive || addLocationSheetActive
                || moveSubject != nil
        )
        .safeAreaInset(edge: .top) { pathBar }
        .sensoryFeedback(.error, trigger: dropErrorCount)
    }

    private func handleAddItemTapped() {
        guard canMutateLocation else { return }
        let gate = appStore.canCreateItem(homeID: home?.id, isPro: proAccessManager.isPro)
        guard gate.isAllowed else {
            if gate.reason == .overLimit {
                activePaywall.wrappedValue = PaywallContext(reason: .overLimit)
            } else {
                activePaywall.wrappedValue = PaywallContext(reason: .itemLimitReached)
            }
            return
        }
        showingAddItem = true
    }
}

/// An editable navigation title with a title menu when the home is mutable; a plain title otherwise.
private struct LocationTitleModifier<Menu: View>: ViewModifier {
    let title: String
    let isRenamable: Bool
    @Binding var draftTitle: String
    @ViewBuilder let menu: () -> Menu

    func body(content: Content) -> some View {
        if isRenamable {
            content
                .navigationTitle($draftTitle)
                .toolbarTitleMenu { menu() }
        } else {
            content.navigationTitle(title)
        }
    }
}

private struct NestedLocationCard: View {
    let location: AppStorageLocation
    let isDropTarget: Bool

    var body: some View {
        HStack {
            Image(systemName: isDropTarget ? "folder.fill.badge.plus" : "folder.fill")
                .foregroundStyle(.tint)
            Text(location.name)
                .font(CubbyDesign.Typography.body)
            Spacer()
            if isDropTarget {
                Text("Move into \(location.name)")
                    .font(CubbyDesign.Typography.captionEmphasized)
                    .foregroundStyle(CubbyDesign.Palette.accent)
            } else if location.itemCount > 0 {
                Text("\(location.itemCount)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            isDropTarget ? CubbyDesign.Palette.accent.opacity(0.12) : Color.gray.opacity(0.1),
            in: RoundedRectangle(cornerRadius: CubbyDesign.Radius.medium)
        )
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: CubbyDesign.Radius.medium)
                    .strokeBorder(CubbyDesign.Palette.accent, lineWidth: CubbyDesign.Stroke.emphasized)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: CubbyDesign.Radius.medium))
        .cubbyAnimation(.quick, value: isDropTarget)
    }
}

/// Nested-location cards are both drag sources and drop targets ("move into").
private struct LocationDragAndDrop: ViewModifier {
    let location: AppStorageLocation
    let isEnabled: Bool
    let onDragStart: () -> Void
    let onDrop: ([LocationDragRef]) -> Bool
    let onTargetChange: (Bool) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .draggable(LocationDragRef(id: location.id)) {
                    Label(location.name, systemImage: "folder.fill")
                        .font(CubbyDesign.Typography.bodyCompactEmphasized)
                        .padding(.horizontal, CubbyDesign.Spacing.medium)
                        .padding(.vertical, CubbyDesign.Spacing.small)
                        .background(CubbyDesign.Palette.elevatedSurface, in: Capsule())
                        .onAppear(perform: onDragStart)
                }
                .dropDestination(for: LocationDragRef.self) { refs, _ in
                    onDrop(refs)
                } isTargeted: { isTargeted in
                    onTargetChange(isTargeted)
                }
        } else {
            content
        }
    }
}

/// Path-bar segments accept a dragged location, meaning "move up to here".
private struct PathSegmentDropTarget: ViewModifier {
    let isEnabled: Bool
    let onDrop: ([LocationDragRef]) -> Bool
    let onTargetChange: (Bool) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.dropDestination(for: LocationDragRef.self) { refs, _ in
                onDrop(refs)
            } isTargeted: { isTargeted in
                onTargetChange(isTargeted)
            }
        } else {
            content
        }
    }
}
