import CloudKit
import CoreData
import Foundation

final class PersistenceController {
    static let modelName = "Cubby"

    static let shared: PersistenceController = {
        do {
            return try PersistenceController()
        } catch {
            fatalError("Failed to initialize PersistenceController: \(error)")
        }
    }()

    static var isCoreDataSharingStackEnabled: Bool {
        FeatureGate.shouldUseCoreDataSharingStack()
    }

    let persistentContainer: NSPersistentCloudKitContainer

    private let privateStoreURL: URL
    private let sharedStoreURL: URL

    init(
        inMemory: Bool = false,
        storeDirectory: URL? = nil,
        containerIdentifier: String = CloudKitSyncSettings.containerIdentifier
    ) throws {
        let managedObjectModel = try Self.loadManagedObjectModel()
        persistentContainer = NSPersistentCloudKitContainer(
            name: Self.modelName,
            managedObjectModel: managedObjectModel
        )

        let directoryURL: URL
        if inMemory {
            directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("PersistenceController-\(UUID().uuidString)", isDirectory: true)
        } else {
            directoryURL = storeDirectory ?? Self.defaultStoreDirectory()
        }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        privateStoreURL = directoryURL.appendingPathComponent("Private.sqlite")
        sharedStoreURL = directoryURL.appendingPathComponent("Shared.sqlite")

        let privateStoreDescription = makeStoreDescription(
            url: privateStoreURL,
            containerIdentifier: containerIdentifier,
            databaseScope: .private
        )
        let sharedStoreDescription = makeStoreDescription(
            url: sharedStoreURL,
            containerIdentifier: containerIdentifier,
            databaseScope: .shared
        )
        persistentContainer.persistentStoreDescriptions = [privateStoreDescription, sharedStoreDescription]

        var loadError: Error?
        persistentContainer.loadPersistentStores { _, error in
            if let error {
                loadError = error
            }
        }
        if let loadError {
            throw loadError
        }

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func privatePersistentStore() -> NSPersistentStore? {
        store(for: privateStoreURL)
    }

    func sharedPersistentStore() -> NSPersistentStore? {
        store(for: sharedStoreURL)
    }

    func isShared(_ object: NSManagedObject) -> Bool {
        guard let persistentStore = object.objectID.persistentStore else { return false }
        return persistentStore == sharedPersistentStore()
    }

    func canEdit(_ object: NSManagedObject) -> Bool {
        guard isShared(object) else { return true }
        guard object.objectID.isTemporaryID == false else { return false }

        do {
            let shares = try fetchShares(matching: [object.objectID])
            guard let share = shares[object.objectID],
                  let participant = share.currentUserParticipant else {
                return false
            }

            if participant.role == .owner {
                return true
            }

            switch participant.permission {
            case .readWrite:
                return true
            case .none, .readOnly, .unknown:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func fetchShares(matching objectIDs: [NSManagedObjectID]) throws -> [NSManagedObjectID: CKShare] {
        if objectIDs.isEmpty {
            return [:]
        }
        return try persistentContainer.fetchShares(matching: objectIDs)
    }

    func resetStores() throws {
        let coordinator = persistentContainer.persistentStoreCoordinator
        let stores = coordinator.persistentStores

        for store in stores {
            guard let storeURL = store.url else { continue }
            let options = persistentContainer.persistentStoreDescriptions.first {
                $0.url?.standardizedFileURL == storeURL.standardizedFileURL
            }?.options

            try coordinator.remove(store)
            try coordinator.destroyPersistentStore(
                at: storeURL,
                type: .sqlite,
                options: options
            )

            removeSQLiteSidecarFiles(for: storeURL)
        }

        var loadError: Error?
        persistentContainer.loadPersistentStores { _, error in
            if let error {
                loadError = error
            }
        }

        if let loadError {
            throw loadError
        }
    }
}

private extension PersistenceController {
    static func defaultStoreDirectory() -> URL {
        NSPersistentContainer.defaultDirectoryURL()
    }

    static func loadManagedObjectModel() throws -> NSManagedObjectModel {
        let bundles = [Bundle.main, Bundle(for: PersistenceController.self)] + Bundle.allBundles + Bundle.allFrameworks
        if let model = NSManagedObjectModel.mergedModel(from: bundles),
           model.entitiesByName["CDHome"] != nil {
            return model
        }

        throw NSError(
            domain: "PersistenceController",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to load Core Data model containing CDHome."]
        )
    }

    func makeStoreDescription(
        url: URL,
        containerIdentifier: String,
        databaseScope: CKDatabase.Scope
    ) -> NSPersistentStoreDescription {
        let description = NSPersistentStoreDescription(url: url)
        description.type = NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false

        let cloudKitOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
        cloudKitOptions.databaseScope = databaseScope
        description.cloudKitContainerOptions = cloudKitOptions

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        return description
    }

    func store(for expectedURL: URL) -> NSPersistentStore? {
        let normalizedExpectedURL = expectedURL.standardizedFileURL
        return persistentContainer.persistentStoreCoordinator.persistentStores.first { store in
            store.url?.standardizedFileURL == normalizedExpectedURL
        }
    }

    func removeSQLiteSidecarFiles(for storeURL: URL) {
        let path = storeURL.path
        let sidecars = ["-wal", "-shm"]
        for suffix in sidecars {
            let sidecarURL = URL(fileURLWithPath: path + suffix)
            try? FileManager.default.removeItem(at: sidecarURL)
        }
    }
}
