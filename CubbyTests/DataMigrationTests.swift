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
            sourceContainerProvider: { .available(sourceContainer) }
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
            sourceContainerProvider: { .available(sourceContainer) }
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
            sourceContainerProvider: { .available(sourceContainer) }
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
            sourceContainerProvider: { .available(sourceContainer) }
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
            sourceContainerProvider: { .available(sourceContainer) }
        )

        let outcome = migrationService.runMigrationIfNeeded()

        #expect(outcome == .migrated)
        #expect(
            userDefaults.bool(forKey: DataMigrationService.migrationCompleteUserDefaultsKey)
        )
    }

    @Test
    func test_migration_fallsBackToResetOnCopyFailure() throws {
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(in: sourceContainer)

        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()
        var resetCallCount = 0

        let migrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: { .available(sourceContainer) },
            migrationExecutor: { _ in
                throw TestFailure.forcedFailure
            },
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
    func test_migration_defersWhenLegacySourceUnavailable() throws {
        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()
        var resetCallCount = 0

        let migrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: { .unavailable },
            resetStores: { resetCallCount += 1 }
        )

        let outcome = migrationService.runMigrationIfNeeded()

        #expect(outcome == .deferredSourceUnavailable)
        #expect(resetCallCount == 0)
        #expect(
            userDefaults.bool(forKey: DataMigrationService.migrationCompleteUserDefaultsKey) == false
        )
    }

    @Test
    func test_migration_retriesAfterLegacySourceBecomesAvailable() throws {
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(in: sourceContainer)

        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()
        var isSourceAvailable = false

        let migrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: {
                isSourceAvailable ? .available(sourceContainer) : .unavailable
            }
        )

        let firstOutcome = migrationService.runMigrationIfNeeded()
        #expect(firstOutcome == .deferredSourceUnavailable)
        #expect(
            userDefaults.bool(forKey: DataMigrationService.migrationCompleteUserDefaultsKey) == false
        )

        isSourceAvailable = true

        let secondOutcome = migrationService.runMigrationIfNeeded()
        #expect(secondOutcome == .migrated)
        #expect(
            userDefaults.bool(forKey: DataMigrationService.migrationCompleteUserDefaultsKey)
        )

        let homes = try fetchObjects(
            entityName: "CDHome",
            from: targetController.persistentContainer.viewContext
        )
        #expect(homes.count == 1)
        #expect(homes.first?.value(forKey: "name") as? String == "Primary Home")
    }

    @Test
    func test_migration_canRecoverAfterCopyFailure() throws {
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(in: sourceContainer)

        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()
        var resetCallCount = 0

        let failingMigrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: { .available(sourceContainer) },
            migrationExecutor: { _ in
                throw TestFailure.forcedFailure
            },
            resetStores: { resetCallCount += 1 }
        )

        let failedOutcome = failingMigrationService.runMigrationIfNeeded()
        #expect(failedOutcome == .failedWithReset)
        #expect(resetCallCount == 1)
        #expect(
            userDefaults.bool(forKey: DataMigrationService.migrationCompleteUserDefaultsKey) == false
        )

        let recoveryMigrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: { .available(sourceContainer) }
        )

        let recoveryOutcome = recoveryMigrationService.runMigrationIfNeeded()
        #expect(recoveryOutcome == .migrated)
        #expect(
            userDefaults.bool(forKey: DataMigrationService.migrationCompleteUserDefaultsKey)
        )

        let homes = try fetchObjects(
            entityName: "CDHome",
            from: targetController.persistentContainer.viewContext
        )
        #expect(homes.count == 1)
    }

    @Test
    func test_migration_upsertsExistingObjectsOnRetry() throws {
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(in: sourceContainer)

        let targetController = try makeTargetController()
        let userDefaults = makeUserDefaults()

        let migrationService = DataMigrationService(
            persistenceController: targetController,
            userDefaults: userDefaults,
            sourceContainerProvider: { .available(sourceContainer) }
        )

        let firstOutcome = migrationService.runMigrationIfNeeded()
        #expect(firstOutcome == .migrated)

        userDefaults.set(false, forKey: DataMigrationService.migrationCompleteUserDefaultsKey)

        let retryOutcome = migrationService.runMigrationIfNeeded()
        #expect(retryOutcome == .migrated)

        let context = targetController.persistentContainer.viewContext
        let homes = try fetchObjects(entityName: "CDHome", from: context)
        let locations = try fetchObjects(entityName: "CDStorageLocation", from: context)
        let items = try fetchObjects(entityName: "CDInventoryItem", from: context)

        #expect(homes.count == 1)
        #expect(locations.count == 2)
        #expect(items.count == 1)
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
                return .available(sourceContainer)
            }
        )

        let outcome = migrationService.runMigrationIfNeeded()

        #expect(outcome == .skippedAlreadyCompleted)
        #expect(sourceContainerCallCount == 0)
    }

    @Test
    func test_migration_keepsRowsAlreadyImportedFromCloudKit() throws {
        let homeID = UUID()
        let parentID = UUID()
        let childID = UUID()
        let itemID = UUID()
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(
            in: sourceContainer,
            homeID: homeID,
            parentLocationID: parentID,
            childLocationID: childID,
            itemID: itemID
        )

        let targetController = try makeTargetController()
        let context = targetController.persistentContainer.viewContext
        let privateStore = try #require(targetController.privatePersistentStore())
        // Simulate the same home already imported from iCloud with a newer name.
        let imported = NSEntityDescription.insertNewObject(forEntityName: "CDHome", into: context)
        context.assign(imported, to: privateStore)
        imported.setValue(homeID, forKey: "id")
        imported.setValue("Renamed on iPad", forKey: "name")
        imported.setValue(Date(), forKey: "createdAt")
        imported.setValue(Date(), forKey: "modifiedAt")
        try context.save()

        let outcome = DataMigrationService(
            persistenceController: targetController,
            userDefaults: makeUserDefaults(),
            sourceContainerProvider: { .available(sourceContainer) }
        ).runMigrationIfNeeded()
        #expect(outcome == .migrated)

        context.refreshAllObjects()
        let homes = try fetchObjects(entityName: "CDHome", from: context)
        #expect(homes.count == 1)
        #expect(homes.first?.value(forKey: "name") as? String == "Renamed on iPad")
        // Locations and items that were not imported yet still migrate into that home.
        let locations = try fetchObjects(entityName: "CDStorageLocation", from: context)
        #expect(Set(locations.compactMap { $0.value(forKey: "id") as? UUID }) == [parentID, childID])
        #expect(locations.allSatisfy { ($0.value(forKey: "home") as? NSManagedObject)?.objectID == imported.objectID })
        let items = try fetchObjects(entityName: "CDInventoryItem", from: context)
        #expect(items.compactMap { $0.value(forKey: "id") as? UUID } == [itemID])
    }

    @Test
    func test_migration_doesNotCopySharedStoreHomesIntoPrivateStore() throws {
        let homeID = UUID()
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(in: sourceContainer, homeID: homeID)

        let targetController = try makeTargetController()
        let context = targetController.persistentContainer.viewContext
        let sharedStore = try #require(targetController.sharedPersistentStore())
        let sharedHome = NSEntityDescription.insertNewObject(forEntityName: "CDHome", into: context)
        context.assign(sharedHome, to: sharedStore)
        sharedHome.setValue(homeID, forKey: "id")
        sharedHome.setValue("Shared Home", forKey: "name")
        sharedHome.setValue(Date(), forKey: "createdAt")
        sharedHome.setValue(Date(), forKey: "modifiedAt")
        try context.save()

        let outcome = DataMigrationService(
            persistenceController: targetController,
            userDefaults: makeUserDefaults(),
            sourceContainerProvider: { .available(sourceContainer) }
        ).runMigrationIfNeeded()
        #expect(outcome == .migrated)

        let homes = try fetchObjects(entityName: "CDHome", from: context)
        #expect(homes.count == 1)
        #expect(homes.first?.objectID.persistentStore == sharedStore)
        // Relationships cannot cross stores, so the legacy children are not orphaned into private.
        #expect(try fetchObjects(entityName: "CDStorageLocation", from: context).isEmpty)
        #expect(try fetchObjects(entityName: "CDInventoryItem", from: context).isEmpty)
    }

    @Test
    func test_migration_runTwiceWithoutResetIsIdempotent() throws {
        let sourceContainer = try makeSourceContainer()
        try seedHomeGraph(in: sourceContainer)
        let targetController = try makeTargetController()

        for _ in 0..<2 {
            let outcome = DataMigrationService(
                persistenceController: targetController,
                userDefaults: makeUserDefaults(),
                sourceContainerProvider: { .available(sourceContainer) }
            ).runMigrationIfNeeded()
            #expect(outcome == .migrated)
        }

        let context = targetController.persistentContainer.viewContext
        #expect(try fetchObjects(entityName: "CDHome", from: context).count == 1)
        #expect(try fetchObjects(entityName: "CDStorageLocation", from: context).count == 2)
        #expect(try fetchObjects(entityName: "CDInventoryItem", from: context).count == 1)
        let child = try fetchObjects(entityName: "CDStorageLocation", from: context)
            .first { $0.value(forKey: "name") as? String == "Shelf" }
        #expect((child?.value(forKey: "parentLocation") as? NSManagedObject)?.value(forKey: "name") as? String == "Garage")
    }
}
