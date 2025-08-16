//
//  MockDataGenerator.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import Foundation
import SwiftData

class MockDataGenerator {
    static func generateSampleData(in context: ModelContext) {
        let home = Home(name: "Sample Home")
        context.insert(home)
        
        let bedroom = StorageLocation(name: "Bedroom", home: home)
        let closet = StorageLocation(name: "Closet", home: home, parentLocation: bedroom)
        let dresser = StorageLocation(name: "Dresser", home: home, parentLocation: bedroom)
        let topDrawer = StorageLocation(name: "Top Drawer", home: home, parentLocation: dresser)
        
        let garage = StorageLocation(name: "Garage", home: home)
        let toolbox = StorageLocation(name: "Toolbox", home: home, parentLocation: garage)
        let shelf = StorageLocation(name: "Shelf", home: home, parentLocation: garage)
        
        context.insert(bedroom)
        context.insert(closet)
        context.insert(dresser)
        context.insert(topDrawer)
        context.insert(garage)
        context.insert(toolbox)
        context.insert(shelf)
        
        let watch = InventoryItem(title: "Rolex Watch", description: "Vintage Submariner", storageLocation: topDrawer)
        let hammer = InventoryItem(title: "Hammer", description: "Stanley 16oz claw hammer", storageLocation: toolbox)
        let jacket = InventoryItem(title: "Winter Jacket", description: "Black North Face jacket", storageLocation: closet)
        let paintCan = InventoryItem(title: "Paint Can", description: "White interior paint", storageLocation: shelf)
        
        context.insert(watch)
        context.insert(hammer)
        context.insert(jacket)
        context.insert(paintCan)
        
        try? context.save()
    }
    
    static func clearAllData(in context: ModelContext) {
        do {
            try context.delete(model: InventoryItem.self)
            try context.delete(model: StorageLocation.self)
            try context.delete(model: Home.self)
            try context.save()
        } catch {
            print("Failed to clear data: \(error)")
        }
    }
}