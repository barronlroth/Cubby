import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var homes: [Home]
    @Query private var allStorageLocations: [StorageLocation]
    @Binding var selectedHome: Home?
    @Binding var selectedLocation: StorageLocation?
    @State private var showingAddLocation = false
    @State private var showingAddHome = false
    @State private var expandedLocations = Set<UUID>()
    
    private var rootStorageLocations: [StorageLocation] {
        allStorageLocations.filter { location in
            location.home?.id == selectedHome?.id && location.parentLocation == nil
        }
    }
    
    var body: some View {
        List(selection: $selectedLocation) {
            if !rootStorageLocations.isEmpty {
                ForEach(rootStorageLocations) { location in
                    StorageLocationRow(
                        location: location,
                        expandedLocations: $expandedLocations,
                        selectedLocation: $selectedLocation
                    )
                }
            } else {
                ContentUnavailableView(
                    "No Storage Locations",
                    systemImage: "folder.badge.plus",
                    description: Text("Add your first storage location to get started")
                )
            }
        }
        .navigationTitle(selectedHome?.name ?? "Select Home")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HomePicker(selectedHome: $selectedHome, showingAddHome: $showingAddHome)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Add Location", systemImage: "folder.badge.plus") {
                    showingAddLocation = true
                }
                .disabled(selectedHome == nil)
            }
        }
        .sheet(isPresented: $showingAddLocation) {
            AddLocationView(home: selectedHome, parentLocation: nil)
        }
        .sheet(isPresented: $showingAddHome) {
            AddHomeView(selectedHome: $selectedHome)
        }
    }
}

struct HomePicker: View {
    @Query private var homes: [Home]
    @Binding var selectedHome: Home?
    @Binding var showingAddHome: Bool
    
    var body: some View {
        Menu {
            ForEach(homes) { home in
                Button(action: { selectedHome = home }) {
                    Label(home.name, systemImage: selectedHome?.id == home.id ? "checkmark" : "")
                }
            }
            Divider()
            Button(action: { showingAddHome = true }) {
                Label("Add New Home", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedHome?.name ?? "Select Home")
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
    }
}