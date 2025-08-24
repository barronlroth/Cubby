import SwiftUI
import SwiftData

@Model
class InventoryItem {
    var id: UUID = UUID()
    var title: String
    var itemDescription: String?
    var photoFileName: String?
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var tags: Set<String> = []
    
    var storageLocation: StorageLocation?
    
    var sortedTags: [String] {
        Array(tags).sorted()
    }
    
    init(title: String, description: String? = nil, storageLocation: StorageLocation) {
        self.title = title
        self.itemDescription = description
        self.storageLocation = storageLocation
    }
}