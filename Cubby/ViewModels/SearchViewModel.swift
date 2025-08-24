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
        
        // Split search into multiple terms for multi-tag search
        let searchTerms = searchTerm.split(separator: " ").map(String.init)
        
        // Filter items based on search criteria
        searchResults = allItems.filter { item in
            // Check home filter if selected
            if let home = selectedHome {
                guard let itemHome = item.storageLocation?.home,
                      itemHome.id == home.id else {
                    return false
                }
            }
            
            // Check if any search term matches
            return searchTerms.allSatisfy { term in
                let titleMatches = item.title.localizedCaseInsensitiveContains(term)
                let descriptionMatches = item.itemDescription?.localizedCaseInsensitiveContains(term) ?? false
                let tagMatches = item.tags.contains { tag in
                    tag.localizedCaseInsensitiveContains(term)
                }
                
                return titleMatches || descriptionMatches || tagMatches
            }
        }
        
        // Sort by relevance (items matching more terms appear first)
        searchResults.sort { item1, item2 in
            let count1 = countMatches(for: item1, with: searchTerms)
            let count2 = countMatches(for: item2, with: searchTerms)
            return count1 > count2
        }
        
        isSearching = false
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
        searchTask?.cancel()
    }
    
    private func countMatches(for item: InventoryItem, with terms: [String]) -> Int {
        terms.reduce(0) { count, term in
            var matches = 0
            if item.title.localizedCaseInsensitiveContains(term) { matches += 1 }
            if item.itemDescription?.localizedCaseInsensitiveContains(term) ?? false { matches += 1 }
            if item.tags.contains(where: { $0.localizedCaseInsensitiveContains(term) }) { matches += 1 }
            return count + matches
        }
    }
}