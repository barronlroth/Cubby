import SwiftUI
import SwiftData

struct StorageLocationRow: View {
    let location: StorageLocation
    @Binding var expandedLocations: Set<UUID>
    @Binding var selectedLocation: StorageLocation?
    @State private var showingAddLocation = false
    @State private var showingDeleteAlert = false
    @State private var deletionErrorMessage: String?
    @Environment(\.modelContext) private var modelContext
    
    private var isExpanded: Bool {
        expandedLocations.contains(location.id)
    }
    
    private var hasChildren: Bool {
        !(location.childLocations?.isEmpty ?? true)
    }
    
    private var itemCount: Int {
        location.items?.count ?? 0
    }
    
    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
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
                    StorageLocationRow(
                        location: childLocation,
                        expandedLocations: $expandedLocations,
                        selectedLocation: $selectedLocation
                    )
                    .padding(.leading, 20)
                }
            }
        } label: {
            locationLabel
        }
        .sheet(isPresented: $showingAddLocation) {
            AddLocationView(homeId: location.home?.id, parentLocation: location)
        }
        .alert("Delete Location", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteLocation()
            }
        } message: {
            Text("Are you sure you want to delete \"\(location.name)\"?")
        }
        .alert("Unable to Delete Location", isPresented: Binding(get: { deletionErrorMessage != nil }, set: { isPresented in
            if !isPresented { deletionErrorMessage = nil }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage ?? "")
        }
    }
    
    private var locationLabel: some View {
        HStack {
            Image(systemName: hasChildren ? "folder.fill" : "folder")
                .foregroundStyle(.tint)
            
            Text(location.name)
                .font(.body)
            
            Spacer()
            
            if itemCount > 0 {
                Text("\(itemCount)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedLocation = location
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!location.canDelete)
            .accessibilityHint("Only empty leaf locations can be deleted.")
            
            Button {
                showingAddLocation = true
            } label: {
                Label("Add Nested", systemImage: "folder.badge.plus")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                showingAddLocation = true
            } label: {
                Label("Add Nested Location", systemImage: "folder.badge.plus")
            }
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!location.canDelete)
            .accessibilityHint("Only empty leaf locations can be deleted.")
        }
    }
    
    private func deleteLocation() {
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
}
