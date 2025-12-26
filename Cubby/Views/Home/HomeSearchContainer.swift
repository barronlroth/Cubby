import SwiftUI

struct HomeSearchContainer: View {
    @State private var searchText: String = ""
    @State private var showingAddItem = false
    @State private var canAddItem = false
    @State private var activePaywall: PaywallContext?
    @StateObject private var proAccessManager = ProAccessManager()

    var body: some View {
        MainNavigationView(
            searchText: $searchText,
            showingAddItem: $showingAddItem,
            canAddItem: $canAddItem
        )
        .environmentObject(proAccessManager)
        .environment(\.activePaywall, $activePaywall)
        .sheet(item: $activePaywall) { context in
            ProPaywallSheetView(context: context)
                .environmentObject(proAccessManager)
        }
    }
}
