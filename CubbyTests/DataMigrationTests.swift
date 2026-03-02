import CoreData
import Foundation
import SwiftData
import Testing
@testable import Cubby

@Suite("Data Migration Tests")
struct DataMigrationTests {
    private enum TestFailure: Error {
        case forcedFailure
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "DataMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeSourceContainer() throws -> ModelContainer {
        let schema = Schema([
            Home.self,
            StorageLocation.self,
            InventoryItem.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeTargetController() throws -> PersistenceController {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DataMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try PersistenceController(storeDirectory: directory)
    }

    private func seedHomeGraph(
        in container: ModelContainer,
        homeID: UUID = UUID(),
        parentLocationID: UUID = UUID(),
        childLocationID: UUID = UUID(),
        itemID: UUID = UUID()
    ) throws {
        let context = ModelContext(container)

        let home = Home(name: "Primary Home")
        home.id = homeID
        context.insert(home)

        let parent = StorageLocation(name: "Garage", home: home)
        parent.id = parentLocationID
        context.insert(parent)

        let child = StorageLocation(name: "Shelf", home: home, parentLocation: parent)
        child.id = childLocationID
        context.insert(child)

        let item = InventoryItem(title: "Bike Pump", storageLocation: child)
        item.id = itemID
        item.tags = ["tool", "bike"]
        context.insert(item)

        try context.save()
    }

    private func fetchObjects(
        entityName: String,
        from context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        return try context.fetch(request)
    }

    @Test
    func test_migration_copiesHomesFromSwiftDataToCoreData() throws {
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(in: sourceContainer)

        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()
        let migrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: { sourceContainer }
        )

        _ = migrationService.runMigrationIfNeeded()

        let homes = try fetchObjects(
            entityName: "CDHome",
            from: targetController.persistentContainer.viewContext
        )
        #expect(homes.count == 1)
        #expect(homes.first?.value(forKey: "name") as? String == "Primary Home")
    }

    @Test
    func test_migration_copiesLocationsWithRelationships() throws {
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(in: sourceContainer)

        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()
        let migrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: { sourceContainer }
        )

        _ = migrationService.runMigrationIfNeeded()

        let locations = try fetchObjects(
            entityName: "CDStorageLocation",
            from: targetController.persistentContainer.viewContext
        )

        #expect(locations.count == 2)

        let garage = locations.first { $0.value(forKey: "name") as? String == "Garage" }
        let shelf = locations.first { $0.value(forKey: "name") as? String == "Shelf" }
        let shelfParent = shelf?.value(forKey: "parentLocation") as? NSManagedObject

        #expect(garage != nil)
        #expect(shelf != nil)
        #expect(shelfParent?.value(forKey: "name") as? String == "Garage")
        #expect(shelf?.value(forKey: "home") as? NSManagedObject != nil)
    }

    @Test
    func test_migration_copiesItemsWithRelationships() throws {
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(in: sourceContainer)

        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()
        let migrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: { sourceContainer }
        )

        _ = migrationService.runMigrationIfNeeded()

        let items = try fetchObjects(
            entityName: "CDInventoryItem",
            from: targetController.persistentContainer.viewContext
        )
        #expect(items.count == 1)

        let itemLocation = items.first?.value(forKey: "storageLocation") as? NSManagedObject
        #expect(itemLocation?.value(forKey: "name") as? String == "Shelf")
    }

    @Test
    func test_migration_preservesUUIDs() throws {
        let homeID = UUID()
        let parentLocationID = UUID()
        let childLocationID = UUID()
        let itemID = UUID()

        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(
            in: sourceContainer,
            homeID: homeID,
            parentLocationID: parentLocationID,
            childLocationID: childLocationID,
            itemID: itemID
        )

        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()
        let migrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: { sourceContainer }
        )

        _ = migrationService.runMigrationIfNeeded()

        let context = targetController.persistentContainer.viewContext
        let homes = try fetchObjects(entityName: "CDHome", from: context)
        let locations = try fetchObjects(entityName: "CDStorageLocation", from: context)
        let items = try fetchObjects(entityName: "CDInventoryItem", from: context)

        #expect(homes.first?.value(forKey: "id") as? UUID == homeID)
        #expect(locations.contains { $0.value(forKey: "id") as? UUID == parentLocationID })
        #expect(locations.contains { $0.value(forKey: "id") as? UUID == childLocationID })
        #expect(items.first?.value(forKey: "id") as? UUID == itemID)
    }

    @Test
    func test_migration_marksCompleteOnSuccess() throws {
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(in: sourceContainer)

        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()
        let migrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: { sourceContainer }
        )

        let outcome = migrationService.runMigrationIfNeeded()

        #expect(outcome == .migrated)
        #expect(
            userDefaults.bool(forKey: DataMigrationService.migrationCompleteUserDefaultsKey)
        )
    }

    @Test
    func test_migration_fallsBackToResetOnFailure() throws {
        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()
        var resetCallCount = 0

        let migrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: { throw TestFailure.forcedFailure },
            resetStores: { resetCallCount += 1 }
        )

        let outcome = migrationService.runMigrationIfNeeded()

        #expect(outcome == .failedWithReset)
        #expect(resetCallCount == 1)
        #expect(
            userDefaults.bool(forKey: DataMigrationService.migrationCompleteUserDefaultsKey) == false
        )
    }

    @Test
    func test_migration_skipsIfAlreadyCompleted() throws {
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(in: sourceContainer)

        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()
        userDefaults.set(true, forKey: DataMigrationService.migrationCompleteUserDefaultsKey)

        var sourceContainerCallCount = 0
        let migrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: {
                sourceContainerCallCount += 1
                return sourceContainer
            }
        )

        let outcome = migrationService.runMigrationIfNeeded()

        #expect(outcome == .skippedAlreadyCompleted)
        #expect(sourceContainerCallCount == 0)
    }
}
