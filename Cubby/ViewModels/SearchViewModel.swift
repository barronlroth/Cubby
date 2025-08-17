import SwiftUI
import SwiftData

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedHome: Home?
    @Published var searchResults: [InventoryItem] = []
    @Published var isSearching = false
    
    private var searchTask: Task<Void, Never>?
    var modelContext: ModelContext?
    
    init(modelContext: ModelContext?) {
        self.modelContext = modelContext
    }
    
    func performSearch() {
        searchTask?.cancel()
        
        searchTask = Task {
            isSearching = true
            
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else {
                isSearching = false
                return
            }
            
            await performSearchWork()
        }
    }
    
    @MainActor
    private func performSearchWork() async {
        let searchTerm = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if searchTerm.isEmpty {
            searchResults = []
            isSearching = false
            return
        }
        
        guard let modelContext = modelContext else {
            searchResults = []
            isSearching = false
            return
        }
        
        // Fetch all items first, then filter in memory to avoid complex predicate
        let descriptor = FetchDescriptor<InventoryItem>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        
        let allItems = (try? modelContext.fetch(descriptor)) ?? []
        
        // Filter items based on search criteria
        searchResults = allItems.filter { item in
            // Check home filter if selected
            if let home = selectedHome {
                guard let itemHome = item.storageLocation?.home,
                      itemHome.id == home.id else {
                    return false
                }
            }
            
            // Check search term
            let titleMatches = item.title.localizedCaseInsensitiveContains(searchTerm)
            let descriptionMatches = item.itemDescription?.localizedCaseInsensitiveContains(searchTerm) ?? false
            
            return titleMatches || descriptionMatches
        }
        
        isSearching = false
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
        searchTask?.cancel()
    }
}