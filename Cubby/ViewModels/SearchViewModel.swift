//
//  SearchViewModel.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedHome: Home?
    @Published var searchResults: [InventoryItem] = []
    @Published var isSearching = false
    
    private var searchTask: Task<Void, Never>?
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func performSearch() {
        searchTask?.cancel()
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isSearching = true
            }
            
            let searchTerm = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if searchTerm.isEmpty {
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
                return
            }
            
            let descriptor: FetchDescriptor<InventoryItem>
            
            if let home = selectedHome {
                descriptor = FetchDescriptor<InventoryItem>(
                    sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<InventoryItem>(
                    sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
                )
            }
            
            do {
                let allItems = try modelContext.fetch(descriptor)
                
                let filteredItems = allItems.filter { item in
                    if let home = selectedHome {
                        guard item.storageLocation?.home?.id == home.id else {
                            return false
                        }
                    }
                    
                    return item.title.localizedCaseInsensitiveContains(searchTerm) ||
                           (item.itemDescription?.localizedCaseInsensitiveContains(searchTerm) ?? false)
                }
                
                await MainActor.run {
                    searchResults = filteredItems
                    isSearching = false
                }
            } catch {
                print("Search failed: \(error)")
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
        selectedHome = nil
        searchTask?.cancel()
    }
}