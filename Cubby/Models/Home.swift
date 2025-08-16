//
//  Home.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import Foundation
import SwiftData

@Model
class Home {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \StorageLocation.home)
    var storageLocations: [StorageLocation]? = []
    
    init(name: String) {
        self.name = name
    }
}