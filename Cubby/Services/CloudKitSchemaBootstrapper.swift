import CoreData
import Foundation
import SwiftData

enum CloudKitSchemaBootstrapper {
    enum BootstrapError: Error {
        case managedObjectModelUnavailable
    }

    static func shouldInitialize(settings: CloudKitSyncSettings) -> Bool {
        settings.shouldInitializeCloudKitSchema
            && settings.usesCloudKit
            && settings.isInMemory == false
    }

    static func initializeIfRequested(settings: CloudKitSyncSettings) {
        #if DEBUG
        guard shouldInitialize(settings: settings) else { return }

        do {
            try initializeDevelopmentSchema()
            DebugLogger.success("CloudKit development schema initialized")
        } catch {
            DebugLogger.error("CloudKit schema initialization failed: \(error)")
        }
        #endif
    }

    #if DEBUG
    private static func initializeDevelopmentSchema() throws {
        try autoreleasepool {
            let modelConfiguration = ModelConfiguration(
                schema: Schema([Home.self, StorageLocation.self, InventoryItem.self]),
                cloudKitDatabase: .private(CloudKitSyncSettings.containerIdentifier)
            )

            let storeDescription = NSPersistentStoreDescription()
            storeDescription.url = modelConfiguration.url
            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: CloudKitSyncSettings.containerIdentifier
            )
            storeDescription.shouldAddStoreAsynchronously = false

            guard let managedObjectModel = NSManagedObjectModel.makeManagedObjectModel(
                for: [Home.self, StorageLocation.self, InventoryItem.self]
            ) else {
                throw BootstrapError.managedObjectModelUnavailable
            }

            let persistentContainer = NSPersistentCloudKitContainer(
                name: "CubbyCloudKitBootstrap",
                managedObjectModel: managedObjectModel
            )
            persistentContainer.persistentStoreDescriptions = [storeDescription]

            var loadError: Error?
            persistentContainer.loadPersistentStores { _, error in
                loadError = error
            }

            if let loadError {
                throw loadError
            }

            try persistentContainer.initializeCloudKitSchema()

            if let store = persistentContainer.persistentStoreCoordinator.persistentStores.first {
                try persistentContainer.persistentStoreCoordinator.remove(store)
            }
        }
    }
    #endif
}
