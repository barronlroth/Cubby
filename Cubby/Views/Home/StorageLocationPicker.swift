import SwiftUI

struct StorageLocationPicker: View {
    let selectedHomeId: UUID?
    @Binding var selectedLocation: AppStorageLocation?
    let onCancel: (() -> Void)?
    let onDone: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appStore: AppStore

    @State private var searchText = ""
    @State private var showingAddLocation = false
    /// Parent of the sub-location being created. The sheet lives here, outside
    /// the List, because a sheet attached to a row is torn down when that row's
    /// cell is reloaded (tapping a row's plus also toggles its disclosure group,
    /// which inserts or removes child rows), so it closed as soon as it opened.
    @State private var subLocationParent: AppStorageLocation?
    @State private var expandedLocations = Set<UUID>()

    private var rootLocations: [AppStorageLocation] {
        appStore.rootLocations(in: selectedHomeId)
    }

    init(
        selectedHomeId: UUID?,
        selectedLocation: Binding<AppStorageLocation?>,
        onCancel: (() -> Void)? = nil,
        onDone: (() -> Void)? = nil
    ) {
        self.selectedHomeId = selectedHomeId
        self._selectedLocation = selectedLocation
        self.onCancel = onCancel
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            List {
                if !rootLocations.isEmpty {
                    ForEach(rootLocations) { location in
                        LocationPickerRow(
                            location: location,
                            selectedLocation: $selectedLocation,
                            expandedLocations: $expandedLocations,
                            searchText: searchText,
                            onAddSubLocation: { subLocationParent = $0 }
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "No Locations",
                        systemImage: "folder",
                        description: Text("Create a storage location first")
                    )
                }
            }
            .searchable(text: $searchText, prompt: "Search locations")
            .scrollContentBackground(.hidden)
            .background(CubbyDesign.Palette.canvas)
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onCancel?()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        onDone?()
                    }
                    .disabled(selectedLocation == nil)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New", systemImage: "plus") {
                        showingAddLocation = true
                    }
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationView(
                    homeId: selectedHomeId,
                    parentLocation: nil,
                    onLocationCreated: handleLocationCreated
                )
            }
            .sheet(item: $subLocationParent) { parent in
                AddLocationView(
                    homeId: parent.homeID,
                    parentLocation: parent,
                    onLocationCreated: handleLocationCreated
                )
            }
        }
    }

    private func handleLocationCreated(_ location: AppStorageLocation) {
        selectedLocation = location
        searchText = ""
        expandAncestors(of: location)
    }

    private func expandAncestors(of location: AppStorageLocation) {
        var parentID = location.parentLocationID
        while let id = parentID {
            expandedLocations.insert(id)
            parentID = appStore.location(id: id)?.parentLocationID
        }
    }

}

struct LocationPickerRow: View {
    @State private var selectionFeedbackCount = 0
    let location: AppStorageLocation
    @Binding var selectedLocation: AppStorageLocation?
    @Binding var expandedLocations: Set<UUID>
    let searchText: String
    let onAddSubLocation: (AppStorageLocation) -> Void

    @State private var showingDeleteConfirmation = false
    @State private var deletionErrorMessage: String?

    @EnvironmentObject private var appStore: AppStore

    private var isSelected: Bool {
        selectedLocation?.id == location.id
    }

    private var isExpanded: Bool {
        expandedLocations.contains(location.id)
    }

    private var children: [AppStorageLocation] {
        appStore.childLocations(of: location.id)
    }

    private var hasChildren: Bool {
        !children.isEmpty
    }

    private var matchesSearch: Bool {
        searchText.isEmpty || location.name.localizedCaseInsensitiveContains(searchText)
    }

    private var childrenMatchSearch: Bool {
        guard !searchText.isEmpty else { return true }
        return children.contains { child in
            child.name.localizedCaseInsensitiveContains(searchText) || childrenMatchSearchRecursive(child)
        }
    }

    private func childrenMatchSearchRecursive(_ location: AppStorageLocation) -> Bool {
        appStore.childLocations(of: location.id).contains { child in
            child.name.localizedCaseInsensitiveContains(searchText) || childrenMatchSearchRecursive(child)
        }
    }

    var body: some View {
        if matchesSearch || childrenMatchSearch {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { isExpanded || !searchText.isEmpty },
                    set: { newValue in
                        if newValue {
                            expandedLocations.insert(location.id)
                        } else {
                            expandedLocations.remove(location.id)
                        }
                    }
                )
            ) {
                if hasChildren {
                    ForEach(children) { childLocation in
                        LocationPickerRow(
                            location: childLocation,
                            selectedLocation: $selectedLocation,
                            expandedLocations: $expandedLocations,
                            searchText: searchText,
                            onAddSubLocation: onAddSubLocation
                        )
                        .padding(.leading, 20)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: hasChildren ? "folder.fill" : "folder")
                        .foregroundStyle(isSelected ? .white : Color.accentColor)

                    Text(location.name)
                        .foregroundStyle(isSelected ? .white : .primary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    }

                    Button(action: { onAddSubLocation(location) }) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(isSelected ? .white : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add sub-location under \(location.name)")
                    .accessibilityHint("Creates a nested storage location inside \(location.name).")
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(isSelected ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedLocation?.id != location.id {
                        selectionFeedbackCount += 1
                    }
                    selectedLocation = location
                }
                .sensoryFeedback(.selection, trigger: selectionFeedbackCount)
                .contextMenu {
                    Button {
                        onAddSubLocation(location)
                    } label: {
                        Label("Add Nested Location", systemImage: "folder.badge.plus")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(!location.canDelete)
                    .accessibilityHint("Only empty leaf locations can be deleted.")
                }
            }
            .alert("Delete Location?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    CubbyDesign.Haptics.play(.warning)
                    do {
                        try StorageLocationDeletionService.deleteLocationIfAllowed(
                            locationId: location.id,
                            appStore: appStore
                        )
                    } catch {
                        deletionErrorMessage = error.localizedDescription
                    }
                }
            } message: {
                Text("This will delete “\(location.name)”.")
            }
            .alert(
                "Unable to Delete Location",
                isPresented: Binding(
                    get: { deletionErrorMessage != nil },
                    set: { if !$0 { deletionErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deletionErrorMessage ?? "")
            }
        }
    }
}
