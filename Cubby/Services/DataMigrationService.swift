import CoreData
import Foundation
import SwiftData

final class DataMigrationService {
    enum Outcome: Equatable {
        case skippedAlreadyCompleted
        case migrated
        case failedWithReset
    }

    static let migrationCompleteUserDefaultsKey = "coreDataMigrationComplete"
    static let recoveryMessageUserInfoKey = "message"
    static let didRequestRecoveryNotification = Notification.Name(
        "DataMigrationService.didRequestRecovery"
    )

    static let recoveryMessage = "We couldn't migrate your existing data. Cubby reset shared-home storage so you can continue."

    private let persistenceController: PersistenceController
    private let userDefaults: UserDefaults
    private let sourceContainerProvider: () throws -> ModelContainer
    private let resetStores: () throws -> Void
    private let notificationCenter: NotificationCenter

    init(
        persistenceController: PersistenceController,
        userDefaults: UserDefaults = .standard,
        sourceContainerProvider: @escaping () throws -> ModelContainer = {
            try DataMigrationService.makeDefaultSourceContainer()
        },
        resetStores: (() throws -> Void)? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.persistenceController = persistenceController
        self.userDefaults = userDefaults
        self.sourceContainerProvider = sourceContainerProvider
        self.resetStores = resetStores ?? { try persistenceController.resetStores() }
        self.notificationCenter = notificationCenter
    }

    func runMigrationIfNeeded() -> Outcome {
        guard userDefaults.bool(forKey: Self.migrationCompleteUserDefaultsKey) == false else {
            return .skippedAlreadyCompleted
        }

        do {
            let sourceContainer = try sourceContainerProvider()
            let sourceContext = ModelContext(sourceContainer)
            try migrate(from: sourceContext)
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

private extension DataMigrationService {
    static func makeDefaultSourceContainer() throws -> ModelContainer {
        let schema = Schema([
            Home.self,
            StorageLocation.self,
            InventoryItem.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(CloudKitSyncSettings.containerIdentifier)
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func migrate(from sourceContext: ModelContext) throws {
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

        var migrationError: Error?
        targetContext.performAndWait {
            do {
                var homesByID: [UUID: NSManagedObject] = [:]
                homesByID.reserveCapacity(homes.count)

                for home in homes {
                    let cdHome = NSEntityDescription.insertNewObject(
                        forEntityName: "CDHome",
                        into: targetContext
                    )
                    targetContext.assign(cdHome, to: privateStore)
                    cdHome.setValue(home.id, forKey: "id")
                    cdHome.setValue(home.name, forKey: "name")
                    cdHome.setValue(home.createdAt, forKey: "createdAt")
                    cdHome.setValue(home.modifiedAt, forKey: "modifiedAt")
                    homesByID[home.id] = cdHome
                }

                var locationsByID: [UUID: NSManagedObject] = [:]
                locationsByID.reserveCapacity(locations.count)

                for location in locations {
                    let cdLocation = NSEntityDescription.insertNewObject(
                        forEntityName: "CDStorageLocation",
                        into: targetContext
                    )
                    targetContext.assign(cdLocation, to: privateStore)
                    cdLocation.setValue(location.id, forKey: "id")
                    cdLocation.setValue(location.name, forKey: "name")
                    cdLocation.setValue(Int16(location.depth), forKey: "depth")
                    cdLocation.setValue(location.createdAt, forKey: "createdAt")
                    cdLocation.setValue(location.modifiedAt, forKey: "modifiedAt")
                    if let homeID = location.home?.id {
                        cdLocation.setValue(homesByID[homeID], forKey: "home")
                    }
                    locationsByID[location.id] = cdLocation
                }

                for location in locations {
                    guard let cdLocation = locationsByID[location.id] else { continue }
                    if let parentID = location.parentLocation?.id {
                        cdLocation.setValue(locationsByID[parentID], forKey: "parentLocation")
                    }
                }

                for item in items {
                    let cdItem = NSEntityDescription.insertNewObject(
                        forEntityName: "CDInventoryItem",
                        into: targetContext
                    )
                    targetContext.assign(cdItem, to: privateStore)
                    cdItem.setValue(item.id, forKey: "id")
                    cdItem.setValue(item.title, forKey: "title")
                    cdItem.setValue(item.itemDescription, forKey: "itemDescription")
                    cdItem.setValue(item.photoFileName, forKey: "photoFileName")
                    cdItem.setValue(item.emoji, forKey: "emoji")
                    cdItem.setValue(item.isPendingAiEmoji, forKey: "isPendingAiEmoji")
                    cdItem.setValue(item.createdAt, forKey: "createdAt")
                    cdItem.setValue(item.modifiedAt, forKey: "modifiedAt")
                    cdItem.setValue(item.tags, forKey: "tags")
                    if let locationID = item.storageLocation?.id {
                        cdItem.setValue(locationsByID[locationID], forKey: "storageLocation")
                    }
                }

                if targetContext.hasChanges {
                    try targetContext.save()
                }
            } catch {
                migrationError = error
            }
        }

        if let migrationError {
            throw migrationError
        }
    }
}
