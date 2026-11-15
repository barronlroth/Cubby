import CoreData
import Foundation
import SwiftData

final class DataMigrationService {
    enum Outcome: Equatable {
        case skippedAlreadyCompleted
        case deferredSourceUnavailable
        case migrated
        case failedWithReset
    }

    enum SourceContainerResolution {
        case available(ModelContainer)
        case unavailable
    }

    static let migrationCompleteUserDefaultsKey = "coreDataMigrationComplete"
    static let recoveryMessageUserInfoKey = "message"
    static let didRequestRecoveryNotification = Notification.Name(
        "DataMigrationService.didRequestRecovery"
    )

    static let recoveryMessage = "We couldn't migrate your existing data. Cubby reset shared-home storage so you can continue."
    static let legacyStoreFileName = "default.store"

    private let persistenceController: PersistenceController
    private let userDefaults: UserDefaults
    private let sourceContainerProvider: () -> SourceContainerResolution
    private let migrationExecutor: (ModelContext) throws -> Void
    private let resetStores: () throws -> Void
    private let notificationCenter: NotificationCenter

    init(
        persistenceController: PersistenceController,
        userDefaults: UserDefaults = .standard,
        sourceContainerProvider: @escaping () -> SourceContainerResolution = {
            DataMigrationService.makeDefaultSourceContainer()
        },
        migrationExecutor: ((ModelContext) throws -> Void)? = nil,
        resetStores: (() throws -> Void)? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.persistenceController = persistenceController
        self.userDefaults = userDefaults
        self.sourceContainerProvider = sourceContainerProvider
        self.migrationExecutor = migrationExecutor ?? { sourceContext in
            try DataMigrationService.migrate(from: sourceContext, into: persistenceController)
        }
        self.resetStores = resetStores ?? { try persistenceController.resetStores() }
        self.notificationCenter = notificationCenter
    }

    func runMigrationIfNeeded() -> Outcome {
        guard userDefaults.bool(forKey: Self.migrationCompleteUserDefaultsKey) == false else {
            return .skippedAlreadyCompleted
        }

        switch sourceContainerProvider() {
        case .unavailable:
            DebugLogger.warning("Legacy SwiftData source unavailable. Migration will retry on a future launch.")
            return .deferredSourceUnavailable
        case .available(let sourceContainer):
            let sourceContext = ModelContext(sourceContainer)
            do {
                try migrationExecutor(sourceContext)
                userDefaults.set(true, forKey: Self.migrationCompleteUserDefaultsKey)
                DebugLogger.success("SwiftData to Core Data migration completed.")
                return .migrated
            } catch {
                DebugLogger.error("SwiftData to Core Data migration failed: \(error)")

                do {
                    try resetStores()
                    DebugLogger.warning("Core Data stores reset after migration failure.")
                } catch {
                    DebugLogger.error("Failed to reset Core Data stores after migration failure: \(error)")
                }

                notificationCenter.post(
                    name: Self.didRequestRecoveryNotification,
                    object: self,
                    userInfo: [Self.recoveryMessageUserInfoKey: Self.recoveryMessage]
                )
                return .failedWithReset
            }
        }
    }
}

private extension DataMigrationService {
    static func makeDefaultSourceContainer() -> SourceContainerResolution {
        let schema = Schema([
            Home.self,
            StorageLocation.self,
            InventoryItem.self
        ])
        let storeURL = legacyStoreURL()
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return .unavailable
        }

        let configuration = ModelConfiguration(
            "LegacyMigration",
            schema: schema,
            url: storeURL,
            allowsSave: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            return .available(container)
        } catch {
            DebugLogger.error("Failed to open legacy SwiftData store for migration: \(error)")
            return .unavailable
        }
    }

    static func legacyStoreURL() -> URL {
        let applicationSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? NSPersistentContainer.defaultDirectoryURL()
        return applicationSupportDirectory.appendingPathComponent(Self.legacyStoreFileName)
    }

    static func migrate(from sourceContext: ModelContext, into persistenceController: PersistenceController) throws {
        let homes = try sourceContext.fetch(FetchDescriptor<Home>())
        let locations = try sourceContext.fetch(FetchDescriptor<StorageLocation>())
        let items = try sourceContext.fetch(FetchDescriptor<InventoryItem>())

        let targetContext = persistenceController.persistentContainer.newBackgroundContext()
        targetContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        guard let privateStore = persistenceController.privatePersistentStore() else {
            throw NSError(
                domain: "DataMigrationService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing private persistent store."]
            )
        }

        let sharedStore = persistenceController.sharedPersistentStore()

        var migrationError: Error?
        targetContext.performAndWait {
            do {
                // Rows Core Data already holds, whether written by an earlier
                // migration attempt or imported from iCloud, are kept as they are.
                // Overwriting them would roll back newer cloud edits, and inserting
                // a second row with the same id would duplicate the record.
                let existingIDs = try existingIDsByEntity(
                    in: targetContext,
                    stores: [privateStore, sharedStore].compactMap { $0 }
                )
                var stats = MigrationStats()

                var homesByID = try existingObjectsByID(
                    entityName: "CDHome",
                    in: targetContext,
                    store: privateStore
                )
                homesByID.reserveCapacity(max(homesByID.count, homes.count))
                var insertedHomeIDs = Set<UUID>()

                for home in homes {
                    guard existingIDs.homes.contains(home.id) == false,
                          insertedHomeIDs.insert(home.id).inserted else {
                        stats.skippedHomes += 1
                        continue
                    }
                    let cdHome = insertObject(
                        entityName: "CDHome",
                        id: home.id,
                        existingObjects: &homesByID,
                        in: targetContext,
                        store: privateStore
                    )
                    cdHome.setValue(home.name, forKey: "name")
                    cdHome.setValue(home.createdAt, forKey: "createdAt")
                    cdHome.setValue(home.modifiedAt, forKey: "modifiedAt")
                }

                var locationsByID = try existingObjectsByID(
                    entityName: "CDStorageLocation",
                    in: targetContext,
                    store: privateStore
                )
                locationsByID.reserveCapacity(max(locationsByID.count, locations.count))
                var insertedLocationIDs = Set<UUID>()

                for location in locations {
                    guard existingIDs.locations.contains(location.id) == false else {
                        stats.skippedLocations += 1
                        continue
                    }
                    // A new location must hang off a private-store home; Core Data
                    // relationships cannot cross stores.
                    guard let homeID = location.home?.id, let cdHome = homesByID[homeID] else {
                        stats.orphanedLocations += 1
                        continue
                    }
                    guard insertedLocationIDs.insert(location.id).inserted else {
                        stats.skippedLocations += 1
                        continue
                    }
                    let cdLocation = insertObject(
                        entityName: "CDStorageLocation",
                        id: location.id,
                        existingObjects: &locationsByID,
                        in: targetContext,
                        store: privateStore
                    )
                    cdLocation.setValue(location.name, forKey: "name")
                    cdLocation.setValue(Int16(location.depth), forKey: "depth")
                    cdLocation.setValue(location.createdAt, forKey: "createdAt")
                    cdLocation.setValue(location.modifiedAt, forKey: "modifiedAt")
                    cdLocation.setValue(cdHome, forKey: "home")
                }

                for location in locations where insertedLocationIDs.contains(location.id) {
                    guard let cdLocation = locationsByID[location.id] else { continue }
                    let parent = location.parentLocation.flatMap { locationsByID[$0.id] }
                    let sameHome = parent.map {
                        ($0.value(forKey: "home") as? NSManagedObject)?.objectID
                            == (cdLocation.value(forKey: "home") as? NSManagedObject)?.objectID
                    } ?? true
                    cdLocation.setValue(sameHome ? parent : nil, forKey: "parentLocation")
                }

                var itemsByID = try existingObjectsByID(
                    entityName: "CDInventoryItem",
                    in: targetContext,
                    store: privateStore
                )
                itemsByID.reserveCapacity(max(itemsByID.count, items.count))
                var insertedItemIDs = Set<UUID>()

                for item in items {
                    guard existingIDs.items.contains(item.id) == false else {
                        stats.skippedItems += 1
                        continue
                    }
                    guard let locationID = item.storageLocation?.id,
                          let cdLocation = locationsByID[locationID] else {
                        stats.orphanedItems += 1
                        continue
                    }
                    guard insertedItemIDs.insert(item.id).inserted else {
                        stats.skippedItems += 1
                        continue
                    }
                    let cdItem = insertObject(
                        entityName: "CDInventoryItem",
                        id: item.id,
                        existingObjects: &itemsByID,
                        in: targetContext,
                        store: privateStore
                    )
                    cdItem.setValue(item.title, forKey: "title")
                    cdItem.setValue(item.itemDescription, forKey: "itemDescription")
                    cdItem.setValue(item.photoFileName, forKey: "photoFileName")
                    cdItem.setValue(item.emoji, forKey: "emoji")
                    cdItem.setValue(item.isPendingAiEmoji, forKey: "isPendingAiEmoji")
                    cdItem.setValue(item.createdAt, forKey: "createdAt")
                    cdItem.setValue(item.modifiedAt, forKey: "modifiedAt")
                    cdItem.setValue(item.tags, forKey: "tags")
                    cdItem.setValue(cdLocation, forKey: "storageLocation")
                }

                if stats.hasSkips {
                    DebugLogger.warning("Legacy migration kept existing Core Data rows: \(stats)")
                }

                if targetContext.hasChanges {
                    try targetContext.save()
                }
            } catch {
                targetContext.rollback()
                migrationError = error
            }
        }

        if let migrationError {
            throw migrationError
        }
    }

    static func existingObjectsByID(
        entityName: String,
        in context: NSManagedObjectContext,
        store: NSPersistentStore
    ) throws -> [UUID: NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.affectedStores = [store]
        return try context.fetch(request).reduce(into: [:]) { partialResult, object in
            guard let id = object.value(forKey: "id") as? UUID else { return }
            partialResult[id] = object
        }
    }

    /// Inserts a new private-store object with `id`, or returns the private
    /// object already inserted for it in this pass.
    static func insertObject(
        entityName: String,
        id: UUID,
        existingObjects: inout [UUID: NSManagedObject],
        in context: NSManagedObjectContext,
        store: NSPersistentStore
    ) -> NSManagedObject {
        if let existingObject = existingObjects[id] {
            return existingObject
        }

        let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        context.assign(object, to: store)
        object.setValue(id, forKey: "id")
        existingObjects[id] = object
        return object
    }

    struct ExistingIDs {
        var homes = Set<UUID>()
        var locations = Set<UUID>()
        var items = Set<UUID>()
    }

    struct MigrationStats: CustomStringConvertible {
        var skippedHomes = 0
        var skippedLocations = 0
        var skippedItems = 0
        var orphanedLocations = 0
        var orphanedItems = 0

        var hasSkips: Bool {
            skippedHomes + skippedLocations + skippedItems + orphanedLocations + orphanedItems > 0
        }

        var description: String {
            "skipped homes \(skippedHomes), locations \(skippedLocations), items \(skippedItems); "
                + "orphaned locations \(orphanedLocations), items \(orphanedItems)"
        }
    }

    static func existingIDsByEntity(
        in context: NSManagedObjectContext,
        stores: [NSPersistentStore]
    ) throws -> ExistingIDs {
        func ids(_ entityName: String) throws -> Set<UUID> {
            let request = NSFetchRequest<NSDictionary>(entityName: entityName)
            request.affectedStores = stores
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["id"]
            return Set(try context.fetch(request).compactMap { $0["id"] as? UUID })
        }
        return ExistingIDs(
            homes: try ids("CDHome"),
            locations: try ids("CDStorageLocation"),
            items: try ids("CDInventoryItem")
        )
    }
}
