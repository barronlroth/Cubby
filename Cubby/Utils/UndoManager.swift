//
//  UndoManager.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import Foundation
import SwiftData

struct ItemUndoManager {
    private var deletedItems: [(item: InventoryItem, locationId: UUID)] = []
    private let maxUndoItems = 10
    
    mutating func recordDeletion(item: InventoryItem) {
        if let locationId = item.storageLocation?.id {
            deletedItems.append((item, locationId))
            if deletedItems.count > maxUndoItems {
                deletedItems.removeFirst()
            }
        }
    }
    
    func canUndo() -> Bool {
        !deletedItems.isEmpty
    }
    
    mutating func undo(in context: ModelContext) -> Bool {
        guard let lastDeleted = deletedItems.popLast() else { return false }
        
        let newItem = InventoryItem(
            title: lastDeleted.item.title,
            description: lastDeleted.item.itemDescription,
            storageLocation: nil
        )
        
        let descriptor = FetchDescriptor<StorageLocation>()
        if let locations = try? context.fetch(descriptor),
           let location = locations.first(where: { $0.id == lastDeleted.locationId }) {
            newItem.storageLocation = location
        }
        
        context.insert(newItem)
        
        do {
            try context.save()
            return true
        } catch {
            context.delete(newItem)
            return false
        }
    }
}