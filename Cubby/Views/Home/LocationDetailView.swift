import SwiftUI
import SwiftData

struct LocationDetailView: View {
    let location: StorageLocation
    @State private var showingAddItem = false
    @State private var showingAddLocation = false

    @Environment(\.activePaywall) private var activePaywall
    @Environment(\.modelContext) private var modelContext
    @Environment(\.homeSharingService) private var homeSharingService
    @Environment(\.sharedHomesGateService) private var sharedHomesGateService
    @EnvironmentObject private var proAccessManager: ProAccessManager
    
    private var items: [InventoryItem] {
        location.items ?? []
    }
    
    private var childLocations: [StorageLocation] {
        location.childLocations ?? []
    }

    private var canMutateLocation: Bool {
        guard sharedHomesGateService.isEnabled() else { return true }
        guard let home = location.home else { return true }
        guard let homeSharingService else { return true }
        return homeSharingService.canEdit(home)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Child Locations Section
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
                                        if let itemCount = childLocation.items?.count, itemCount > 0 {
                                            Text("\(itemCount)")
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
                
                // Items Section
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
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.large)
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
        .sheet(isPresented: $showingAddItem) {
            AddItemView(selectedHomeId: location.home?.id, preselectedLocation: location)
        }
        .sheet(isPresented: $showingAddLocation) {
            AddLocationView(homeId: location.home?.id, parentLocation: location)
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.secondary)
                Text(location.fullPath)
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
        let gate = FeatureGate.canCreateItem(
            homeId: location.home?.id,
            modelContext: modelContext,
            isPro: proAccessManager.isPro
        )
        guard gate.isAllowed else {
            DebugLogger.info("FeatureGate denied item creation: \(gate.reason?.description ?? "unknown")")
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
