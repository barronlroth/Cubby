import SwiftUI
import UIKit
import SwiftData

struct LocationSection: Identifiable {
    let id: UUID
    let location: StorageLocation
    let locationPath: String
    let items: [InventoryItem]
    
    var isEmpty: Bool {
        items.isEmpty
    }

    init(location: StorageLocation, locationPath: String, items: [InventoryItem]) {
        self.id = location.id
        self.location = location
        self.locationPath = locationPath
        self.items = items
    }
}

struct HomeView: View {
    @Query private var homes: [Home]
    @Query private var allItems: [InventoryItem]
    @Binding var selectedHome: Home?
    @Binding var selectedLocation: StorageLocation?
    @Binding var searchText: String
    @Binding var showingAddItem: Bool
    @State private var showingAddLocation = false
    @State private var showingAddHome = false
    @State private var showingProStatus = false
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

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private var displayedSections: [LocationSection] {
        guard isSearching else { return locationSections }

        var result: [LocationSection] = []
        for section in locationSections {
            var matchedItems: [InventoryItem] = []
            for item in section.items {
                if itemMatchesSearch(item) {
                    matchedItems.append(item)
                }
            }
            if !matchedItems.isEmpty {
                result.append(
                    LocationSection(
                        location: section.location,
                        locationPath: section.locationPath,
                        items: matchedItems
                    )
                )
            }
        }
        return result
    }

    var body: some View {
        let sections = displayedSections

        return listView(for: sections)
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
        .onChange(of: selectedHome?.id) { _, _ in
            searchText = ""
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomePicker(
                selectedHome: $selectedHome,
                showingAddHome: $showingAddHome,
                showingProStatus: $showingProStatus
            )
                .buttonStyle(.plain)
                .padding(.top, 8)
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

    private func itemMatchesSearch(_ item: InventoryItem) -> Bool {
        guard isSearching else { return true }

        let query = trimmedSearchText

        if item.title.localizedCaseInsensitiveContains(query) {
            return true
        }

        if let description = item.itemDescription,
           description.localizedCaseInsensitiveContains(query) {
            return true
        }

        return false
    }
    
    @ViewBuilder
    private func listView(for sections: [LocationSection]) -> some View {
        List {
            header
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
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
}

struct HomePicker: View {
    @Query private var homes: [Home]
    @Binding var selectedHome: Home?
    @Binding var showingAddHome: Bool
    @Binding var showingProStatus: Bool

    @Environment(\.activePaywall) private var activePaywall
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var proAccessManager: ProAccessManager
    
    var body: some View {
        Menu {
            ForEach(homes) { home in
                Button(action: { selectedHome = home }) {
                    Label(home.name, systemImage: selectedHome?.id == home.id ? "checkmark" : "")
                }
            }
            Divider()
            Button(action: { showingProStatus = true }) {
                Label("Cubby Pro", systemImage: "crown")
            }
            Button(action: handleAddHomeTapped) {
                Label("Add New Home", systemImage: "plus")
            }
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
    }

    private func handleAddHomeTapped() {
        let gate = FeatureGate.canCreateHome(modelContext: modelContext, isPro: proAccessManager.isPro)
        guard gate.isAllowed else {
            DebugLogger.info("FeatureGate denied home creation: \(gate.reason?.description ?? "unknown")")
            if gate.reason == .overLimit {
                activePaywall.wrappedValue = PaywallContext(reason: .overLimit)
            } else {
                activePaywall.wrappedValue = PaywallContext(reason: .homeLimitReached)
            }
            return
        }
        showingAddHome = true
    }
}

#if DEBUG
private enum HomeViewPreviewData {
    @MainActor
    static func make() -> (container: ModelContainer, home: Home) {
        let schema = Schema([
            Home.self,
            StorageLocation.self,
            InventoryItem.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try! ModelContainer(for: schema, configurations: [config])
        let ctx = container.mainContext

        // Home
        let home = Home(name: "Hayes Valley")
        ctx.insert(home)

        // Locations: Under My Bed → Travel Bags → Treasure Chest
        let underMyBed = StorageLocation(name: "Under My Bed", home: home)
        ctx.insert(underMyBed)
        let travelBags = StorageLocation(name: "Travel Bags", home: home, parentLocation: underMyBed)
        ctx.insert(travelBags)
        let treasureChest = StorageLocation(name: "Treasure Chest", home: home, parentLocation: travelBags)
        ctx.insert(treasureChest)

        // Items — Under My Bed
        ctx.insert(InventoryItem(title: "Rare Book", description: "On a high shelf, hidden behind other books", storageLocation: underMyBed))
        ctx.insert(InventoryItem(title: "Emergency Flashlight", description: "In the back of a kitchen drawer", storageLocation: underMyBed))
        ctx.insert(InventoryItem(title: "Art Supplies", description: "In a storage box under the bed", storageLocation: underMyBed))

        // Items — Travel Bags
        ctx.insert(InventoryItem(title: "Acoustic Guitar", description: "In a case at the corner of the living room", storageLocation: travelBags))
        ctx.insert(InventoryItem(title: "Old Keys", description: "Taped to the bottom of a desk drawer", storageLocation: travelBags))
        ctx.insert(InventoryItem(title: "Childhood Plush Toy", description: "In a closet with seasonal decorations", storageLocation: travelBags))

        // Items — Treasure Chest
        ctx.insert(InventoryItem(title: "Vintage Film Camera", description: "On a shelf behind some magazines", storageLocation: treasureChest))
        ctx.insert(InventoryItem(title: "Paint Palette", description: "In a hidden compartment of an art desk", storageLocation: treasureChest))
        ctx.insert(InventoryItem(title: "Travel Suitcase", description: "Under the bed, filled with souvenirs", storageLocation: treasureChest))
        ctx.insert(InventoryItem(title: "Family Heirloom Ring", description: "In a secret compartment of a jewelry box", storageLocation: treasureChest))

        try? ctx.save()
        return (container, home)
    }
}

private struct HomeViewPreviewHarness: View {
    @State private var selectedHome: Home?
    @State private var selectedLocation: StorageLocation?
    @State private var searchText: String = ""
    @State private var showingAddItem = false

    init(initialHome: Home?) {
        _selectedHome = State(initialValue: initialHome)
    }

    var body: some View {
        NavigationStack {
            HomeView(
                selectedHome: $selectedHome,
                selectedLocation: $selectedLocation,
                searchText: $searchText,
                showingAddItem: $showingAddItem
            )
        }
    }
}

#Preview("Home – Figma Mock Data") {
    let data = HomeViewPreviewData.make()
    return HomeViewPreviewHarness(initialHome: data.home)
        .modelContainer(data.container)
        .environmentObject(ProAccessManager())
}
#endif
