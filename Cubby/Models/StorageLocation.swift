import SwiftUI
import SwiftData

@Model
class StorageLocation {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var depth: Int = 0
    
    var home: Home?
    
    var parentLocation: StorageLocation?
    
    @Relationship(deleteRule: .deny, inverse: \StorageLocation.parentLocation)
    var childLocations: [StorageLocation]? = []
    
    @Relationship(deleteRule: .deny, inverse: \InventoryItem.storageLocation)
    var items: [InventoryItem]? = []
    
    var fullPath: String {
        var path = [String]()
        var current: StorageLocation? = self
        while let location = current {
            path.insert(location.name, at: 0)
            current = location.parentLocation
        }
        return path.joined(separator: " > ")
    }
    
    var canDelete: Bool {
        items?.isEmpty == true && childLocations?.isEmpty == true
    }
    
    func canMoveTo(_ targetLocation: StorageLocation?) -> Bool {
        guard let target = targetLocation else { return true }
        
        if target.id == self.id { return false }
        
        var current = target.parentLocation
        while current != nil {
            if current?.id == self.id { return false }
            current = current?.parentLocation
        }
        return true
    }
    
    init(name: String, home: Home, parentLocation: StorageLocation? = nil) {
        self.name = name
        self.home = home
        self.parentLocation = parentLocation
        self.depth = (parentLocation?.depth ?? -1) + 1
    }
    
    static let maxNestingDepth = 10
}
