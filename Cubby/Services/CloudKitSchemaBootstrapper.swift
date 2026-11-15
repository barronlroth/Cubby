import CoreData
import Foundation

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
    /// Only the Core Data sharing schema syncs. The legacy SwiftData store is
    /// local-only, so its schema is not pushed to CloudKit.
    private static func initializeDevelopmentSchema() throws {
        try initializeCoreDataSharingSchema()
    }

    private static func initializeCoreDataSharingSchema() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreDataSchemaBootstrap-\(UUID().uuidString)", isDirectory: true)

        do {
            let persistenceController = try PersistenceController(
                inMemory: false,
                storeDirectory: storeDirectory,
                containerIdentifier: CloudKitSyncSettings.containerIdentifier
            )

            try persistenceController.persistentContainer.initializeCloudKitSchema()

            try persistenceController.resetStores()
            try FileManager.default.removeItem(at: storeDirectory)
        } catch {
            try? FileManager.default.removeItem(at: storeDirectory)
            throw error
        }
    }
    #endif
}
