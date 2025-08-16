//
//  InventoryItem.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import Foundation
import SwiftData

@Model
class InventoryItem {
    var id: UUID = UUID()
    var title: String
    var itemDescription: String?
    var photoFileName: String?
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    
    var storageLocation: StorageLocation?
    
    init(title: String, description: String? = nil, storageLocation: StorageLocation) {
        self.title = title
        self.itemDescription = description
        self.storageLocation = storageLocation
    }
}