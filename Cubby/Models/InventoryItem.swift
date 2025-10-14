import SwiftUI
import SwiftData

@Model
class InventoryItem {
    var id: UUID = UUID()
    var title: String
    var itemDescription: String?
    var photoFileName: String?
    var emoji: String? = nil
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var tags: [String] = []
    
    var storageLocation: StorageLocation?
    
    var sortedTags: [String] {
        tags.sorted()
    }
    
    var tagsSet: Set<String> {
        get { Set(tags) }
        set { tags = Array(newValue).sorted() }
    }
    
    init(title: String, description: String? = nil, storageLocation: StorageLocation) {
        self.title = title
        self.itemDescription = description
        self.storageLocation = storageLocation
    }
}
