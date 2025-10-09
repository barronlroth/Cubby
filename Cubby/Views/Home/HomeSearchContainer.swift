import SwiftUI

struct HomeSearchContainer: View {
    @State private var searchText: String = ""
    @State private var showingAddItem = false
    @State private var canAddItem = false

    var body: some View {
        MainNavigationView(
            searchText: $searchText,
            showingAddItem: $showingAddItem,
            canAddItem: $canAddItem
        )
    }
}
