import Foundation
import SwiftData

struct MockDataGenerator {
    static func generateMockData(in modelContext: ModelContext) {
        // Create sample homes
        let mainHome = Home(name: "Main Home")
        let vacationHome = Home(name: "Beach House")
        
        modelContext.insert(mainHome)
        modelContext.insert(vacationHome)
        
        // Create storage locations for main home
        let garage = StorageLocation(name: "Garage", home: mainHome)
        let bedroom = StorageLocation(name: "Master Bedroom", home: mainHome)
        let kitchen = StorageLocation(name: "Kitchen", home: mainHome)
        let office = StorageLocation(name: "Home Office", home: mainHome)
        
        modelContext.insert(garage)
        modelContext.insert(bedroom)
        modelContext.insert(kitchen)
        modelContext.insert(office)
        
        // Create nested locations
        let closet = StorageLocation(name: "Walk-in Closet", home: mainHome, parentLocation: bedroom)
        let drawer = StorageLocation(name: "Top Drawer", home: mainHome, parentLocation: closet)
        let workbench = StorageLocation(name: "Workbench", home: mainHome, parentLocation: garage)
        let toolbox = StorageLocation(name: "Red Toolbox", home: mainHome, parentLocation: workbench)
        let pantry = StorageLocation(name: "Pantry", home: mainHome, parentLocation: kitchen)
        let desk = StorageLocation(name: "Standing Desk", home: mainHome, parentLocation: office)
        let filingCabinet = StorageLocation(name: "Filing Cabinet", home: mainHome, parentLocation: office)
        
        modelContext.insert(closet)
        modelContext.insert(drawer)
        modelContext.insert(workbench)
        modelContext.insert(toolbox)
        modelContext.insert(pantry)
        modelContext.insert(desk)
        modelContext.insert(filingCabinet)
        
        // Create sample items
        let watch = InventoryItem(title: "Rolex Submariner", description: "Black dial, steel bracelet", storageLocation: drawer)
        let powerDrill = InventoryItem(title: "DeWalt 20V Drill", description: "Cordless drill with 2 batteries", storageLocation: toolbox)
        let laptop = InventoryItem(title: "MacBook Pro 16\"", description: "M3 Max, 64GB RAM, Space Black", storageLocation: desk)
        let passport = InventoryItem(title: "Passport", description: "Expires 2028", storageLocation: filingCabinet)
        let winterCoat = InventoryItem(title: "Canada Goose Parka", description: "Black, size L", storageLocation: closet)
        let coffeemaker = InventoryItem(title: "Nespresso Machine", description: "Vertuo Next model", storageLocation: kitchen)
        let riceStock = InventoryItem(title: "Basmati Rice", description: "5 bags of 10lb each", storageLocation: pantry)
        let bikeHelmet = InventoryItem(title: "Giro Bike Helmet", description: "White with MIPS", storageLocation: garage)
        
        modelContext.insert(watch)
        modelContext.insert(powerDrill)
        modelContext.insert(laptop)
        modelContext.insert(passport)
        modelContext.insert(winterCoat)
        modelContext.insert(coffeemaker)
        modelContext.insert(riceStock)
        modelContext.insert(bikeHelmet)
        
        // Create locations for vacation home
        let beachGarage = StorageLocation(name: "Garage", home: vacationHome)
        let beachShed = StorageLocation(name: "Beach Equipment Shed", home: vacationHome)
        
        modelContext.insert(beachGarage)
        modelContext.insert(beachShed)
        
        // Add items to vacation home
        let surfboard = InventoryItem(title: "Surfboard", description: "7' funboard", storageLocation: beachShed)
        let beachChairs = InventoryItem(title: "Beach Chairs", description: "4 folding chairs", storageLocation: beachShed)
        let golfClubs = InventoryItem(title: "Golf Clubs", description: "Full set of Callaway clubs", storageLocation: beachGarage)
        
        modelContext.insert(surfboard)
        modelContext.insert(beachChairs)
        modelContext.insert(golfClubs)
        
        // Save all changes
        try? modelContext.save()
    }
    
    static func clearAllData(in modelContext: ModelContext) {
        // Delete all items first (due to relationships)
        let itemDescriptor = FetchDescriptor<InventoryItem>()
        if let items = try? modelContext.fetch(itemDescriptor) {
            items.forEach { modelContext.delete($0) }
        }
        
        // Delete all storage locations
        let locationDescriptor = FetchDescriptor<StorageLocation>()
        if let locations = try? modelContext.fetch(locationDescriptor) {
            locations.forEach { modelContext.delete($0) }
        }
        
        // Delete all homes
        let homeDescriptor = FetchDescriptor<Home>()
        if let homes = try? modelContext.fetch(homeDescriptor) {
            homes.forEach { modelContext.delete($0) }
        }
        
        try? modelContext.save()
    }
}

// Extension for preview support
extension ModelContainer {
    @MainActor
    static var preview: ModelContainer {
        let schema = Schema([
            Home.self,
            StorageLocation.self,
            InventoryItem.self
        ])
        
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        
        MockDataGenerator.generateMockData(in: container.mainContext)
        
        return container
    }
}