import Foundation
import SwiftData

struct MockDataGenerator {
    static func generateItemLimitReachedMockData(in modelContext: ModelContext) {
        let home = Home(name: "Main Home")
        modelContext.insert(home)

        UserDefaults.standard.set(home.id.uuidString, forKey: "lastUsedHomeId")

        let closet = StorageLocation(name: "Closet", home: home)
        modelContext.insert(closet)

        for index in 1...10 {
            let item = InventoryItem(
                title: "Test Item \(index)",
                description: "Seeded to hit the free item limit",
                storageLocation: closet
            )
            item.emoji = "📦"
            modelContext.insert(item)
        }

        try? modelContext.save()
    }

    static func generateFreeTierMockData(in modelContext: ModelContext) {
        let reach = Home(name: "Reach")
        modelContext.insert(reach)

        UserDefaults.standard.set(reach.id.uuidString, forKey: "lastUsedHomeId")

        let armory = StorageLocation(name: "Armory", home: reach)
        let hangar = StorageLocation(name: "Hangar", home: reach)
        let operations = StorageLocation(name: "Operations Center", home: reach)
        let barracks = StorageLocation(name: "Barracks", home: reach)
        let locker = StorageLocation(name: "Locker", home: reach, parentLocation: barracks)

        modelContext.insert(armory)
        modelContext.insert(hangar)
        modelContext.insert(operations)
        modelContext.insert(barracks)
        modelContext.insert(locker)

        let assaultRifle = InventoryItem(
            title: "MA5B Assault Rifle",
            description: "Standard issue rifle",
            storageLocation: armory
        )
        assaultRifle.emoji = "🔫"

        let battleRifle = InventoryItem(
            title: "BR55 Battle Rifle",
            description: "Mid-range precision weapon",
            storageLocation: armory
        )
        battleRifle.emoji = "🔫"

        let magnum = InventoryItem(
            title: "M6G Magnum",
            description: "Sidearm for field ops",
            storageLocation: armory
        )
        magnum.emoji = "🔫"

        let mjolnirArmor = InventoryItem(
            title: "MJOLNIR Armor",
            description: "Spartan armor set",
            storageLocation: locker
        )
        mjolnirArmor.emoji = "🛡️"

        let energySword = InventoryItem(
            title: "Energy Sword",
            description: "Close-quarters weapon",
            storageLocation: locker
        )
        energySword.emoji = "🗡️"

        let pelican = InventoryItem(
            title: "Pelican Dropship",
            description: "VTOL transport craft",
            storageLocation: hangar
        )
        pelican.emoji = "🚁"

        let warthog = InventoryItem(
            title: "Warthog",
            description: "Recon and transport vehicle",
            storageLocation: hangar
        )
        warthog.emoji = "🚙"

        let cortanaChip = InventoryItem(
            title: "Cortana AI Chip",
            description: "AI storage module",
            storageLocation: operations
        )
        cortanaChip.emoji = "💾"

        let navPad = InventoryItem(
            title: "Nav Data Pad",
            description: "Mission nav and coordinates",
            storageLocation: operations
        )
        navPad.emoji = "🧭"

        modelContext.insert(assaultRifle)
        modelContext.insert(battleRifle)
        modelContext.insert(magnum)
        modelContext.insert(mjolnirArmor)
        modelContext.insert(energySword)
        modelContext.insert(pelican)
        modelContext.insert(warthog)
        modelContext.insert(cortanaChip)
        modelContext.insert(navPad)

        try? modelContext.save()
    }

    static func generateEmptyHomeMockData(in modelContext: ModelContext) {
        let home = Home(name: "Empty Home")
        modelContext.insert(home)

        UserDefaults.standard.set(home.id.uuidString, forKey: "lastUsedHomeId")

        let unsorted = StorageLocation(name: "Unsorted", home: home)
        modelContext.insert(unsorted)

        try? modelContext.save()
    }

    static func generateMockData(in modelContext: ModelContext) {
        // Create sample homes
        let mainHome = Home(name: "Main Home")
        let vacationHome = Home(name: "Beach House")
        
        modelContext.insert(mainHome)
        modelContext.insert(vacationHome)

        // Default to the primary home so UI tests/snapshots land in a predictable spot.
        UserDefaults.standard.set(mainHome.id.uuidString, forKey: "lastUsedHomeId")
        
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
        
        // Create sample items (rarely used / easy to misplace)
        let watch = InventoryItem(title: "Rolex Submariner", description: "Dress watch for special occasions", storageLocation: drawer)
        watch.emoji = "⌚️"
        let travelAdapters = InventoryItem(title: "Travel Adapter Kit", description: "EU/UK/AU plugs + USB-C", storageLocation: drawer)
        travelAdapters.emoji = "🔌"

        let winterCoat = InventoryItem(title: "Canada Goose Parka", description: "Black, size L", storageLocation: closet)
        winterCoat.emoji = "🧥"
        let skiPants = InventoryItem(title: "Ski Pants", description: "Insulated, size L", storageLocation: closet)
        skiPants.emoji = "🎿"
        let skiGloves = InventoryItem(title: "Ski Gloves", description: "Waterproof, insulated", storageLocation: closet)
        skiGloves.emoji = "🧤"

        let cargoBox = InventoryItem(title: "Roof Cargo Box", description: "Thule XL, winter storage", storageLocation: garage)
        cargoBox.emoji = "🛄"
        let snowChains = InventoryItem(title: "Snow Chains", description: "Set of 2, fits 20\" tires", storageLocation: garage)
        snowChains.emoji = "⛓️"

        let studFinder = InventoryItem(title: "Stud Finder", description: "Battery powered", storageLocation: toolbox)
        studFinder.emoji = "📡"
        let solderingIron = InventoryItem(title: "Soldering Iron", description: "60W with fine tip", storageLocation: toolbox)
        solderingIron.emoji = "🪛"

        let fondueSet = InventoryItem(title: "Fondue Set", description: "Ceramic pot, 6 forks", storageLocation: kitchen)
        fondueSet.emoji = "🫕"
        let emergencyWater = InventoryItem(title: "Emergency Water Jugs", description: "3 gallons stored away", storageLocation: pantry)
        emergencyWater.emoji = "💧"

        let backupDrive = InventoryItem(title: "Backup Hard Drive", description: "4TB archives", storageLocation: desk)
        backupDrive.emoji = "💽"
        let passport = InventoryItem(title: "Passport", description: "Expires 2028", storageLocation: filingCabinet)
        passport.emoji = "🛂"
        let birthCertificates = InventoryItem(title: "Birth Certificates", description: "Family documents", storageLocation: filingCabinet)
        birthCertificates.emoji = "📜"
        
        modelContext.insert(watch)
        modelContext.insert(travelAdapters)
        modelContext.insert(passport)
        modelContext.insert(winterCoat)
        modelContext.insert(skiPants)
        modelContext.insert(skiGloves)
        modelContext.insert(cargoBox)
        modelContext.insert(snowChains)
        modelContext.insert(studFinder)
        modelContext.insert(solderingIron)
        modelContext.insert(fondueSet)
        modelContext.insert(emergencyWater)
        modelContext.insert(backupDrive)
        modelContext.insert(birthCertificates)
        
        // Create locations for vacation home
        let beachGarage = StorageLocation(name: "Garage", home: vacationHome)
        let beachShed = StorageLocation(name: "Beach Equipment Shed", home: vacationHome)
        
        modelContext.insert(beachGarage)
        modelContext.insert(beachShed)
        
        // Add items to vacation home
        let surfboard = InventoryItem(title: "Surfboard", description: "7' funboard", storageLocation: beachShed)
        surfboard.emoji = "🏄"
        let beachChairs = InventoryItem(title: "Beach Chairs", description: "4 folding chairs", storageLocation: beachShed)
        beachChairs.emoji = "🏖️"
        let golfClubs = InventoryItem(title: "Golf Clubs", description: "Full set of Callaway clubs", storageLocation: beachGarage)
        golfClubs.emoji = "⛳️"
        let sunscreen = InventoryItem(title: "Sunscreen SPF50", description: "Water resistant, reef safe", storageLocation: beachShed)
        sunscreen.emoji = "🧴"
        let snorkelSet = InventoryItem(title: "Snorkel Set", description: "Mask, snorkel, and fins", storageLocation: beachShed)
        snorkelSet.emoji = "🤿"
        let beachUmbrella = InventoryItem(title: "Beach Umbrella", description: "UV 50+ canopy", storageLocation: beachShed)
        beachUmbrella.emoji = "⛱️"
        let beachCooler = InventoryItem(title: "Beach Cooler", description: "Keeps drinks cold all day", storageLocation: beachGarage)
        beachCooler.emoji = "🧊"
        
        modelContext.insert(surfboard)
        modelContext.insert(beachChairs)
        modelContext.insert(golfClubs)
        modelContext.insert(sunscreen)
        modelContext.insert(snorkelSet)
        modelContext.insert(beachUmbrella)
        modelContext.insert(beachCooler)
        
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
