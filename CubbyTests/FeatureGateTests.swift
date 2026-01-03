import Testing
import SwiftData
@testable import Cubby

@Suite("Feature Gate Tests")
struct FeatureGateTests {
    @MainActor
    func createTestContainer() throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: Home.self,
            StorageLocation.self,
            InventoryItem.self,
            configurations: modelConfiguration
        )
    }

    // MARK: - Home Creation Tests

    @Test("Pro user can always create homes")
    @MainActor
    func testProUserCanAlwaysCreateHomes() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // Create 5 homes
        for i in 1...5 {
            let home = Home(name: "Home \(i)")
            context.insert(home)
        }
        try context.save()

        let result = FeatureGate.canCreateHome(modelContext: context, isPro: true)
        #expect(result.isAllowed)
        #expect(result.reason == nil)
    }

    @Test("Free user can create first home")
    @MainActor
    func testFreeUserCanCreateFirstHome() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // No homes exist
        let result = FeatureGate.canCreateHome(modelContext: context, isPro: false)
        #expect(result.isAllowed)
    }

    @Test("Free user blocked at home limit")
    @MainActor
    func testFreeUserBlockedAtHomeLimit() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // Create exactly 1 home (the free limit)
        let home = Home(name: "Home 1")
        context.insert(home)
        try context.save()

        let result = FeatureGate.canCreateHome(modelContext: context, isPro: false)
        #expect(!result.isAllowed)
        #expect(result.reason == .homeLimitReached)
    }

    @Test("Free user over limit shows overLimit reason")
    @MainActor
    func testFreeUserOverLimitHomes() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // Create 2 homes (over the free limit of 1)
        for i in 1...2 {
            let home = Home(name: "Home \(i)")
            context.insert(home)
        }
        try context.save()

        let result = FeatureGate.canCreateHome(modelContext: context, isPro: false)
        #expect(!result.isAllowed)
        #expect(result.reason == .overLimit)
    }

    // MARK: - Item Creation Tests

    @Test("Pro user can always create items")
    @MainActor
    func testProUserCanAlwaysCreateItems() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let home = Home(name: "Test Home")
        let location = StorageLocation(name: "Test Location", home: home)
        context.insert(home)
        context.insert(location)

        // Create 20 items
        for i in 1...20 {
            let item = InventoryItem(title: "Item \(i)", storageLocation: location)
            context.insert(item)
        }
        try context.save()

        let result = FeatureGate.canCreateItem(homeId: home.id, modelContext: context, isPro: true)
        #expect(result.isAllowed)
        #expect(result.reason == nil)
    }

    @Test("Free user can create items under limit")
    @MainActor
    func testFreeUserCanCreateItemsUnderLimit() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let home = Home(name: "Test Home")
        let location = StorageLocation(name: "Test Location", home: home)
        context.insert(home)
        context.insert(location)

        // Create 5 items (under the 10 limit)
        for i in 1...5 {
            let item = InventoryItem(title: "Item \(i)", storageLocation: location)
            context.insert(item)
        }
        try context.save()

        let result = FeatureGate.canCreateItem(homeId: home.id, modelContext: context, isPro: false)
        #expect(result.isAllowed)
    }

    @Test("Free user blocked at item limit")
    @MainActor
    func testFreeUserBlockedAtItemLimit() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let home = Home(name: "Test Home")
        let location = StorageLocation(name: "Test Location", home: home)
        context.insert(home)
        context.insert(location)

        // Create exactly 10 items (the free limit)
        for i in 1...10 {
            let item = InventoryItem(title: "Item \(i)", storageLocation: location)
            context.insert(item)
        }
        try context.save()

        let result = FeatureGate.canCreateItem(homeId: home.id, modelContext: context, isPro: false)
        #expect(!result.isAllowed)
        #expect(result.reason == .itemLimitReached)
    }

    @Test("Items counted across multiple locations in same home")
    @MainActor
    func testItemsCountedAcrossLocations() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let home = Home(name: "Test Home")
        let location1 = StorageLocation(name: "Location 1", home: home)
        let location2 = StorageLocation(name: "Location 2", home: home)
        context.insert(home)
        context.insert(location1)
        context.insert(location2)

        // 6 items in location 1
        for i in 1...6 {
            let item = InventoryItem(title: "Item A\(i)", storageLocation: location1)
            context.insert(item)
        }

        // 4 items in location 2 (total = 10, at limit)
        for i in 1...4 {
            let item = InventoryItem(title: "Item B\(i)", storageLocation: location2)
            context.insert(item)
        }
        try context.save()

        let result = FeatureGate.canCreateItem(homeId: home.id, modelContext: context, isPro: false)
        #expect(!result.isAllowed)
        #expect(result.reason == .itemLimitReached)
    }

    @Test("Over home limit blocks item creation with overLimit reason")
    @MainActor
    func testOverHomeLimitBlocksItemCreation() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // Create 2 homes (over the free limit of 1)
        let home1 = Home(name: "Home 1")
        let home2 = Home(name: "Home 2")
        let location = StorageLocation(name: "Test Location", home: home1)
        context.insert(home1)
        context.insert(home2)
        context.insert(location)
        try context.save()

        // Even though home1 has 0 items, we're over the home limit
        let result = FeatureGate.canCreateItem(homeId: home1.id, modelContext: context, isPro: false)
        #expect(!result.isAllowed)
        #expect(result.reason == .overLimit)
    }

    @Test("Nil homeId allows item creation")
    @MainActor
    func testNilHomeIdAllowsCreation() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let result = FeatureGate.canCreateItem(homeId: nil, modelContext: context, isPro: false)
        #expect(result.isAllowed)
    }
}
