import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appStore: AppStore

    @State private var searchText = ""
    @State private var selectedHomeID: UUID?

    private var homes: [AppHome] {
        appStore.homes
    }

    private var searchResults: [AppInventoryItem] {
        appStore.searchItems(query: searchText, homeID: selectedHomeID)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if homes.count > 1 {
                    Picker("Home", selection: $selectedHomeID) {
                        Text("All Homes")
                            .tag(nil as UUID?)
                        ForEach(homes) { home in
                            Text(home.name)
                                .tag(home.id as UUID?)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }

                if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No items match \"\(searchText)\"")
                    )
                } else if searchResults.isEmpty && searchText.isEmpty {
                    ContentUnavailableView(
                        "Search Your Items",
                        systemImage: "magnifyingglass",
                        description: Text("Enter a search term to find items")
                    )
                } else {
                    List(searchResults) { item in
                        NavigationLink {
                            ItemDetailView(itemId: item.id)
                        } label: {
                            SearchResultRow(item: item)
                        }
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search items"
            )
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let item: AppInventoryItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(UIColor(named: "ItemIconBackground") != nil ? Color("ItemIconBackground") : Color(.secondarySystemBackground))
                    .frame(width: 48, height: 48)
                Text(item.emoji ?? EmojiPicker.emoji(for: item.id))
                    .font(.system(size: 24))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                if let description = item.itemDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(item.storageLocationPath ?? "Unknown")
                        .font(.caption)

                    if let homeName = item.homeName {
                        Text("• \(homeName)")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}
