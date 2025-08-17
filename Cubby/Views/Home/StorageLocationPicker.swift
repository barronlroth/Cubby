import SwiftUI
import SwiftData

struct StorageLocationPicker: View {
    let selectedHome: Home?
    @Binding var selectedLocation: StorageLocation?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showingAddLocation = false
    @State private var expandedLocations = Set<UUID>()
    
    private var rootLocations: [StorageLocation] {
        selectedHome?.storageLocations?.filter { $0.parentLocation == nil } ?? []
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
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
                AddLocationView(home: selectedHome, parentLocation: nil)
            }
        }
    }
}

struct LocationPickerRow: View {
    let location: StorageLocation
    @Binding var selectedLocation: StorageLocation?
    @Binding var expandedLocations: Set<UUID>
    let searchText: String
    @State private var showingAddLocation = false
    
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
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationView(home: location.home, parentLocation: location)
            }
        }
    }
}