import Foundation
import SwiftData

@MainActor
class UndoManager: ObservableObject {
    static let shared = UndoManager()
    
    private struct DeletedItem {
        let item: InventoryItem
        let locationId: UUID
        let title: String
        let description: String?
        let photoFileName: String?
        let timestamp: Date
    }
    
    @Published private(set) var canUndo = false
    @Published private(set) var timeRemaining: Int = 0
    private var deletedItems: [DeletedItem] = []
    private let maxUndoItems = 10
    private let autoHideDelay: Int = 8 // seconds
    private var autoHideTimer: Timer?
    
    private init() {}
    
    func recordDeletion(item: InventoryItem) {
        let deletedItem = DeletedItem(
            item: item,
            locationId: item.storageLocation?.id ?? UUID(),
            title: item.title,
            description: item.itemDescription,
            photoFileName: item.photoFileName,
            timestamp: Date()
        )
        
        deletedItems.append(deletedItem)
        
        if deletedItems.count > maxUndoItems {
            // Remove oldest item and its photo if exists
            let removed = deletedItems.removeFirst()
            if let photoFileName = removed.photoFileName {
                Task {
                    await PhotoService.shared.deletePhoto(fileName: photoFileName)
                }
            }
        }
        
        canUndo = !deletedItems.isEmpty
        startAutoHideTimer()
    }
    
    func undo(in context: ModelContext) -> Bool {
        guard let lastDeleted = deletedItems.popLast() else { return false }
        
        // Cancel the auto-hide timer since user manually undid
        cancelAutoHideTimer()
        
        // Find the storage location
        let locationId = lastDeleted.locationId
        let descriptor = FetchDescriptor<StorageLocation>(
            predicate: #Predicate { location in
                location.id == locationId
            }
        )
        
        guard let locations = try? context.fetch(descriptor),
              let location = locations.first else {
            // Location no longer exists, can't restore
            canUndo = !deletedItems.isEmpty
            return false
        }
        
        // Recreate the item
        let newItem = InventoryItem(
            title: lastDeleted.title,
            description: lastDeleted.description,
            storageLocation: location
        )
        newItem.photoFileName = lastDeleted.photoFileName
        
        context.insert(newItem)
        
        do {
            try context.save()
            canUndo = !deletedItems.isEmpty
            return true
        } catch {
            print("Failed to undo deletion: \(error)")
            // Restore the deleted item to the stack since undo failed
            deletedItems.append(lastDeleted)
            return false
        }
    }
    
    func clearUndoStack() {
        // Cancel any running timer
        cancelAutoHideTimer()
        
        // Clean up any photos from the undo stack
        for item in deletedItems {
            if let photoFileName = item.photoFileName {
                Task {
                    await PhotoService.shared.deletePhoto(fileName: photoFileName)
                }
            }
        }
        deletedItems.removeAll()
        canUndo = false
    }
    
    var undoDescription: String? {
        guard let lastDeleted = deletedItems.last else { return nil }
        return "Undo delete \"\(lastDeleted.title)\""
    }
    
    func dismissUndo() {
        cancelAutoHideTimer()
        canUndo = false
    }
    
    private func startAutoHideTimer() {
        cancelAutoHideTimer()
        timeRemaining = autoHideDelay
        
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.timeRemaining -= 1
            
            if self.timeRemaining <= 0 {
                self.dismissUndo()
            }
        }
    }
    
    private func cancelAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        timeRemaining = 0
    }
}