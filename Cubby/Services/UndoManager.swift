import Foundation

@MainActor
class UndoManager: ObservableObject {
    static let shared = UndoManager()
    
    private struct DeletedItem {
        let snapshot: AppDeletedItemSnapshot
        let timestamp: Date
    }
    
    @Published private(set) var canUndo = false
    @Published private(set) var timeRemaining: Int = 0
    private var deletedItems: [DeletedItem] = []
    private let maxUndoItems = 10
    private let autoHideDelay: Int = 8 // seconds
    private var autoHideTimer: Timer?
    
    private init() {}
    
    func recordDeletion(snapshot: AppDeletedItemSnapshot) {
        let deletedItem = DeletedItem(
            snapshot: snapshot,
            timestamp: Date()
        )
        
        deletedItems.append(deletedItem)
        
        if deletedItems.count > maxUndoItems {
            // Remove oldest item and its photo if exists
            let removed = deletedItems.removeFirst()
            if let photoFileName = removed.snapshot.photoFileName {
                Task {
                    await PhotoService.shared.deletePhoto(fileName: photoFileName)
                }
            }
        }
        
        canUndo = !deletedItems.isEmpty
        startAutoHideTimer()
    }
    
    func undo(using appStore: AppStore) -> Bool {
        guard let lastDeleted = deletedItems.popLast() else { return false }
        
        // Cancel the auto-hide timer since user manually undid
        cancelAutoHideTimer()
        
        guard appStore.location(id: lastDeleted.snapshot.storageLocationID) != nil else {
            canUndo = !deletedItems.isEmpty
            return false
        }

        do {
            try appStore.restoreDeletedItem(lastDeleted.snapshot)
            canUndo = !deletedItems.isEmpty
            return true
        } catch {
            print("Failed to undo deletion: \(error)")
            deletedItems.append(lastDeleted)
            return false
        }
    }
    
    func clearUndoStack() {
        // Cancel any running timer
        cancelAutoHideTimer()
        
        // Clean up any photos from the undo stack
        for item in deletedItems {
            if let photoFileName = item.snapshot.photoFileName {
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
        return "Undo delete \"\(lastDeleted.snapshot.title)\""
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

            Task { @MainActor in
                self.timeRemaining -= 1

                if self.timeRemaining <= 0 {
                    self.dismissUndo()
                }
            }
        }
    }
    
    private func cancelAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        timeRemaining = 0
    }
}
