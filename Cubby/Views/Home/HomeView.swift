import SwiftUI
import SwiftData

struct LocationSection: Identifiable {
    let id = UUID()
    let location: StorageLocation
    let locationPath: String
    let items: [InventoryItem]
    
    var isEmpty: Bool {
        items.isEmpty
    }
}

struct HomeView: View {
    @Query private var homes: [Home]
    @Query private var allItems: [InventoryItem]
    @Binding var selectedHome: Home?
    @Binding var selectedLocation: StorageLocation?
    @State private var showingAddLocation = false
    @State private var showingAddHome = false
    @State private var showingAddItem = false
    @Environment(\.modelContext) private var modelContext
    
    private var locationSections: [LocationSection] {
        let homeItems = allItems.filter { item in
            item.storageLocation?.home?.id == selectedHome?.id
        }
        
        let groupedDict = Dictionary(grouping: homeItems) { item in
            item.storageLocation
        }
        
        return groupedDict.compactMap { (location, items) in
            guard let location = location, !items.isEmpty else { return nil }
            return LocationSection(
                location: location,
                locationPath: location.fullPath,
                items: items.sorted { $0.title < $1.title }
            )
        }
        .sorted { $0.locationPath < $1.locationPath }
    }
    
    var body: some View {
        List {
            if locationSections.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "shippingbox",
                    description: Text("Add items to your storage locations to see them here")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                ForEach(locationSections) { section in
                    Section {
                        ForEach(section.items) { item in
                            ItemRow(item: item, showLocation: false)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
        .listStyle(PlainListStyle())
        .navigationTitle(selectedHome?.name ?? "Select Home")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HomePicker(selectedHome: $selectedHome, showingAddHome: $showingAddHome)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if selectedHome != nil {
                    Menu {
                        Button(action: { 
                            DebugLogger.info("HomeView - Add Item pressed, selectedHome: \(String(describing: selectedHome?.name)), ID: \(String(describing: selectedHome?.id))")
                            showingAddItem = true 
                        }) {
                            Label("Add Item", systemImage: "plus")
                        }
                        
                        Button(action: { 
                            showingAddLocation = true
                        }) {
                            Label("Add Location", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddLocation) {
            if let homeId = selectedHome?.id {
                AddLocationView(homeId: homeId, parentLocation: nil)
            }
        }
        .sheet(isPresented: $showingAddHome) {
            AddHomeView(selectedHome: $selectedHome)
        }
        .sheet(isPresented: $showingAddItem) {
            if let homeId = selectedHome?.id {
                AddItemView(selectedHomeId: homeId, preselectedLocation: nil)
            }
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