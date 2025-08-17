import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var homes: [Home]
    @State private var selectedItem: InventoryItem?
    @StateObject private var viewModel = SearchViewModel(modelContext: nil)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !homes.isEmpty && homes.count > 1 {
                    Picker("Home", selection: $viewModel.selectedHome) {
                        Text("All Homes")
                            .tag(nil as Home?)
                        ForEach(homes) { home in
                            Text(home.name)
                                .tag(home as Home?)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }
                
                if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty && !viewModel.isSearching {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No items match \"\(viewModel.searchText)\"")
                    )
                } else if viewModel.searchResults.isEmpty && viewModel.searchText.isEmpty {
                    ContentUnavailableView(
                        "Search Your Items",
                        systemImage: "magnifyingglass",
                        description: Text("Enter a search term to find items")
                    )
                } else {
                    List(viewModel.searchResults) { item in
                        SearchResultRow(item: item)
                            .onTapGesture {
                                selectedItem = item
                            }
                    }
                }
            }
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search items"
            )
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.performSearch()
            }
            .onChange(of: viewModel.selectedHome) { _, _ in
                viewModel.performSearch()
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedItem) { item in
                ItemDetailView(item: item)
            }
        }
        .onAppear {
            // Fix for StateObject initialization
            if viewModel.modelContext == nil {
                viewModel.modelContext = modelContext
            }
        }
    }
}

struct SearchResultRow: View {
    let item: InventoryItem
    @State private var photo: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            if let photoFileName = item.photoFileName {
                Group {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 50, height: 50)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "shippingbox")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .frame(width: 50, height: 50)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    Text(item.storageLocation?.fullPath ?? "Unknown")
                        .font(.caption)
                    
                    if let homeName = item.storageLocation?.home?.name {
                        Text("• \(homeName)")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .task {
            if let photoFileName = item.photoFileName {
                photo = await PhotoService.shared.loadPhoto(fileName: photoFileName)
            }
        }
    }
}