import SwiftUI
import SwiftData

struct StorageLocationPicker: View {
    let selectedHomeId: UUID?
    @Binding var selectedLocation: StorageLocation?
    let onCancel: (() -> Void)?
    let onDone: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Query private var allStorageLocations: [StorageLocation]
    @Query private var homes: [Home]
    @State private var searchText = ""
    @State private var showingAddLocation = false
    @State private var expandedLocations = Set<UUID>()
    
    private var selectedHome: Home? {
        homes.first { $0.id == selectedHomeId }
    }
    
    private var rootLocations: [StorageLocation] {
        let locations = allStorageLocations.filter { location in
            location.home?.id == selectedHomeId && location.parentLocation == nil
        }
        print("🔍 StorageLocationPicker - Found \(locations.count) root locations for homeId: \(String(describing: selectedHomeId))")
        print("🔍 StorageLocationPicker - Total locations in query: \(allStorageLocations.count)")
        return locations
    }

    init(
        selectedHomeId: UUID?,
        selectedLocation: Binding<StorageLocation?>,
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
                            searchText: searchText
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
            .background(appBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Select Location")
                        .font(.custom("AwesomeSerif-ExtraTall", size: 20))
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        if let onCancel {
                            Task { @MainActor in onCancel() }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        if let onDone {
                            Task { @MainActor in onDone() }
                        }
                    }
                        .fontWeight(.semibold)
                        .disabled(selectedLocation == nil)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New", systemImage: "plus") {
                        showingAddLocation = true
                    }
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationView(homeId: selectedHomeId, parentLocation: nil)
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

struct LocationPickerRow: View {
    let location: StorageLocation
    @Binding var selectedLocation: StorageLocation?
    @Binding var expandedLocations: Set<UUID>
    let searchText: String
    @State private var showingAddLocation = false
    @State private var showingDeleteConfirmation = false
    @State private var deletionErrorMessage: String?
    @Environment(\.modelContext) private var modelContext
    
    private var isSelected: Bool {
        selectedLocation?.id == location.id
    }
    
    private var isExpanded: Bool {
        expandedLocations.contains(location.id)
    }
    
    private var hasChildren: Bool {
        !(location.childLocations?.isEmpty ?? true)
    }
    
    private var matchesSearch: Bool {
        searchText.isEmpty || location.name.localizedCaseInsensitiveContains(searchText)
    }
    
    private var childrenMatchSearch: Bool {
        guard !searchText.isEmpty else { return true }
        return location.childLocations?.contains { child in
            child.name.localizedCaseInsensitiveContains(searchText) || childrenMatchSearchRecursive(child)
        } ?? false
    }
    
    private func childrenMatchSearchRecursive(_ location: StorageLocation) -> Bool {
        location.childLocations?.contains { child in
            child.name.localizedCaseInsensitiveContains(searchText) || childrenMatchSearchRecursive(child)
        } ?? false
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
                    ForEach(location.childLocations ?? []) { childLocation in
                        LocationPickerRow(
                            location: childLocation,
                            selectedLocation: $selectedLocation,
                            expandedLocations: $expandedLocations,
                            searchText: searchText
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
                    
                    Button(action: { showingAddLocation = true }) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(isSelected ? .white : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(isSelected ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedLocation = location
                }
                .contextMenu {
                    Button {
                        showingAddLocation = true
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
            .sheet(isPresented: $showingAddLocation) {
                AddLocationView(homeId: location.home?.id, parentLocation: location)
            }
            .alert("Delete Location?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    do {
                        try StorageLocationDeletionService.deleteLocationIfAllowed(
                            locationId: location.id,
                            modelContext: modelContext
                        )
                    } catch let error as StorageLocationDeletionError {
                        deletionErrorMessage = error.localizedDescription
                    } catch {
                        deletionErrorMessage = "Couldn’t delete this location. Please try again."
                    }
                }
            } message: {
                Text("This will delete “\(location.name)”.")
            }
            .alert("Unable to Delete Location", isPresented: Binding(get: { deletionErrorMessage != nil }, set: { isPresented in
                if !isPresented { deletionErrorMessage = nil }
            })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deletionErrorMessage ?? "")
            }
        }
    }
}
