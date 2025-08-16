//
//  ItemManagementViewModel.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class ItemManagementViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private let modelContext: ModelContext
    private var undoManager = ItemUndoManager()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func moveItems(_ items: [InventoryItem], to location: StorageLocation) async -> Bool {
        isProcessing = true
        defer { isProcessing = false }
        
        for item in items {
            item.storageLocation = location
            item.modifiedAt = Date()
        }
        
        do {
            try modelContext.save()
            return true
        } catch {
            errorMessage = "Failed to move items: \(error.localizedDescription)"
            return false
        }
    }
    
    func deleteItem(_ item: InventoryItem) async -> Bool {
        isProcessing = true
        defer { isProcessing = false }
        
        undoManager.recordDeletion(item: item)
        
        if let photoFileName = item.photoFileName {
            await PhotoService.shared.deletePhoto(fileName: photoFileName)
        }
        
        modelContext.delete(item)
        
        do {
            try modelContext.save()
            return true
        } catch {
            errorMessage = "Failed to delete item: \(error.localizedDescription)"
            return false
        }
    }
    
    func undoLastDeletion() -> Bool {
        return undoManager.undo(in: modelContext)
    }
    
    func canUndo() -> Bool {
        return undoManager.canUndo()
    }
    
    func duplicateItem(_ item: InventoryItem) async -> InventoryItem? {
        isProcessing = true
        defer { isProcessing = false }
        
        let newItem = InventoryItem(
            title: "\(item.title) (Copy)",
            description: item.itemDescription,
            storageLocation: item.storageLocation!
        )
        
        if let photoFileName = item.photoFileName,
           let image = await PhotoService.shared.loadPhoto(fileName: photoFileName) {
            do {
                let newPhotoFileName = try await PhotoService.shared.savePhoto(image)
                newItem.photoFileName = newPhotoFileName
            } catch {
                errorMessage = "Failed to copy photo: \(error.localizedDescription)"
            }
        }
        
        modelContext.insert(newItem)
        
        do {
            try modelContext.save()
            return newItem
        } catch {
            errorMessage = "Failed to duplicate item: \(error.localizedDescription)"
            modelContext.delete(newItem)
            return nil
        }
    }
}