//
//  PreviewHelpers.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData

extension ModelContainer {
    static var preview: ModelContainer {
        let schema = Schema([
            Home.self,
            StorageLocation.self,
            InventoryItem.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            let context = container.mainContext
            
            let home = Home(name: "Sample Home")
            context.insert(home)
            
            let bedroom = StorageLocation(name: "Bedroom", home: home)
            let closet = StorageLocation(name: "Closet", home: home, parentLocation: bedroom)
            context.insert(bedroom)
            context.insert(closet)
            
            let item = InventoryItem(title: "Watch", description: "Rolex", storageLocation: closet)
            context.insert(item)
            
            try? context.save()
            
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}