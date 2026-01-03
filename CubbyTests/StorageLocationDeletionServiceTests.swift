import Testing
import SwiftData
@testable import Cubby

@Suite("Storage Location Deletion Service Tests")
struct StorageLocationDeletionServiceTests {
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

    @Test("Delete succeeds only for empty leaf")
    @MainActor
    func testDeleteEmptyLeafLocation() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let home = Home(name: "Test Home")
        let location = StorageLocation(name: "Leaf", home: home)
        context.insert(home)
        context.insert(location)

        try context.save()

        try StorageLocationDeletionService.deleteLocationIfAllowed(
            locationId: location.id,
            modelContext: context
        )

        let remaining = try context.fetch(FetchDescriptor<StorageLocation>())
            .filter { $0.id == location.id }
        #expect(remaining.isEmpty)
    }

    @Test("Delete blocked when location has children")
    @MainActor
    func testDeleteBlockedForParent() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let home = Home(name: "Test Home")
        let parent = StorageLocation(name: "Parent", home: home)
        let child = StorageLocation(name: "Child", home: home, parentLocation: parent)

        context.insert(home)
        context.insert(parent)
        context.insert(child)
        try context.save()

        do {
            try StorageLocationDeletionService.deleteLocationIfAllowed(
                locationId: parent.id,
                modelContext: context
            )
            #expect(Bool(false))
        } catch let error as StorageLocationDeletionError {
            #expect(error == .hasChildren(1))
        }
    }

    @Test("Delete blocked when location has items")
    @MainActor
    func testDeleteBlockedForItems() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let home = Home(name: "Test Home")
        let location = StorageLocation(name: "Leaf", home: home)
        let item = InventoryItem(title: "Item", storageLocation: location)

        context.insert(home)
        context.insert(location)
        context.insert(item)
        try context.save()

        do {
            try StorageLocationDeletionService.deleteLocationIfAllowed(
                locationId: location.id,
                modelContext: context
            )
            #expect(Bool(false))
        } catch let error as StorageLocationDeletionError {
            #expect(error == .hasItems(1))
        }
    }

    @Test("Defensive re-check blocks stale deletes")
    @MainActor
    func testDeleteStaleState() async throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let home = Home(name: "Test Home")
        let location = StorageLocation(name: "Leaf", home: home)

        context.insert(home)
        context.insert(location)
        try context.save()

        #expect(location.canDelete == true)

        let item = InventoryItem(title: "Item", storageLocation: location)
        context.insert(item)
        try context.save()

        do {
            try StorageLocationDeletionService.deleteLocationIfAllowed(
                locationId: location.id,
                modelContext: context
            )
            #expect(Bool(false))
        } catch let error as StorageLocationDeletionError {
            #expect(error == .hasItems(1))
        }
    }
}
