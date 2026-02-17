import CloudKit
import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("PersistenceController Tests")
struct PersistenceControllerTests {
    private func makeController() throws -> PersistenceController {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistenceControllerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try PersistenceController(storeDirectory: directory)
    }

    @Test
    func test_dualStoreSetup_loadsPrivateAndSharedStores() throws {
        let controller = try makeController()

        let stores = controller.persistentContainer.persistentStoreCoordinator.persistentStores
        #expect(stores.count == 2)
        #expect(controller.privatePersistentStore() != nil)
        #expect(controller.sharedPersistentStore() != nil)
    }

    @Test
    func test_privateStore_hasCorrectDatabaseScope() throws {
        let controller = try makeController()
        guard let privateStore = controller.privatePersistentStore() else {
            Issue.record("Expected private store to be loaded")
            return
        }

        let options = privateStore.options?[NSPersistentCloudKitContainerOptionsKey] as? NSPersistentCloudKitContainerOptions
        #expect(options?.databaseScope == .private)
    }

    @Test
    func test_sharedStore_hasCorrectDatabaseScope() throws {
        let controller = try makeController()
        guard let sharedStore = controller.sharedPersistentStore() else {
            Issue.record("Expected shared store to be loaded")
            return
        }

        let options = sharedStore.options?[NSPersistentCloudKitContainerOptionsKey] as? NSPersistentCloudKitContainerOptions
        #expect(options?.databaseScope == .shared)
    }

    @Test
    func test_historyTrackingEnabled_onBothStores() throws {
        let controller = try makeController()

        guard let privateStore = controller.privatePersistentStore() else {
            Issue.record("Expected private store to be loaded")
            return
        }
        guard let sharedStore = controller.sharedPersistentStore() else {
            Issue.record("Expected shared store to be loaded")
            return
        }

        let privateHistoryEnabled = (privateStore.options?[NSPersistentHistoryTrackingKey] as? NSNumber)?.boolValue
        let sharedHistoryEnabled = (sharedStore.options?[NSPersistentHistoryTrackingKey] as? NSNumber)?.boolValue

        #expect(privateHistoryEnabled == true)
        #expect(sharedHistoryEnabled == true)
    }

    @Test
    func test_viewContext_mergesChangesAutomatically() throws {
        let controller = try makeController()
        #expect(controller.persistentContainer.viewContext.automaticallyMergesChangesFromParent == true)
    }

    @Test
    func test_viewContext_usesCorrectMergePolicy() throws {
        let controller = try makeController()
        #expect(
            controller.persistentContainer.viewContext.mergePolicy.mergeType
                == .mergeByPropertyObjectTrumpMergePolicyType
        )
    }
}
