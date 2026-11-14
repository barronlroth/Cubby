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
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return []
        }

        return appStore.searchItems(query: searchText, homeID: selectedHomeID)
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
                        .siriInventoryItem(item.id)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledIconSize = CubbyDesign.Layout.rowIcon

    private var iconSize: CGFloat {
        min(scaledIconSize, CubbyDesign.Layout.rowIconMaximum)
    }

    private var locationText: String {
        let path = item.storageLocationPath ?? "Unknown"
        guard let homeName = item.homeName else { return path }
        return "\(path) • \(homeName)"
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CubbyDesign.Spacing.small))
            : AnyLayout(HStackLayout(spacing: CubbyDesign.Spacing.medium))
        layout {
            ZStack {
                Circle()
                    .fill(CubbyDesign.Palette.itemIconBackground)
                    .frame(width: iconSize, height: iconSize)
                // Emoji is sized from the scaled, capped icon metric rather than a text style.
                Text(item.emoji ?? EmojiPicker.emoji(for: item.id))
                    .font(.system(size: iconSize / 2))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

                if let description = item.itemDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                }

                Text("\(Image(systemName: "location.fill")) \(locationText)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}
