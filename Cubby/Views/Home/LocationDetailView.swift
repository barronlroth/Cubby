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

    @Environment(\.dismiss) private var dismiss

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
            try appStore.renameLocation(id: location.id, to: trimmed)
        } catch {
            renameErrorCount += 1
            draftTitle = currentName
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
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundStyle(.tint)
                                        Text(childLocation.name)
                                        Spacer()
                                        if childLocation.itemCount > 0 {
                                            Text("\(childLocation.itemCount)")
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
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
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
                                ItemRow(item: item)
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
        )
        .safeAreaInset(edge: .top) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.secondary)
                Text(resolvedLocation?.fullPath ?? location.fullPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
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
