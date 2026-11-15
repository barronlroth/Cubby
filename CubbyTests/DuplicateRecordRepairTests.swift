import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("Duplicate Record Repair Tests")
@MainActor
struct DuplicateRecordRepairTests {
    private func makeController() throws -> PersistenceController {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DuplicateRecordRepairTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try PersistenceController(storeDirectory: directory)
    }

    @discardableResult
    private func insert(
        _ entityName: String,
        id: UUID?,
        name: String,
        modifiedAt: Date,
        store: NSPersistentStore,
        context: NSManagedObjectContext,
        relationships: [String: NSManagedObject?] = [:]
    ) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        context.assign(object, to: store)
        object.setValue(id, forKey: "id")
        object.setValue(modifiedAt, forKey: "createdAt")
        object.setValue(modifiedAt, forKey: "modifiedAt")
        switch entityName {
        case "CDInventoryItem":
            object.setValue(name, forKey: "title")
            object.setValue(false, forKey: "isPendingAiEmoji")
            object.setValue([String](), forKey: "tags")
        case "CDStorageLocation":
            object.setValue(name, forKey: "name")
            object.setValue(Int16(0), forKey: "depth")
        default:
            object.setValue(name, forKey: "name")
        }
        for (key, value) in relationships {
            object.setValue(value, forKey: key)
        }
        return object
    }

    private func fetch(
        _ entityName: String,
        in context: NSManagedObjectContext,
        store: NSPersistentStore? = nil
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        if let store {
            request.affectedStores = [store]
        }
        return try context.fetch(request)
    }

    private let old = Date(timeIntervalSince1970: 1_000)
    private let new = Date(timeIntervalSince1970: 2_000)

    @Test("Duplicate homes merge into the newest row and keep every location and item")
    func mergesDuplicateHomes() throws {
        let controller = try makeController()
        let context = controller.persistentContainer.viewContext
        let privateStore = try #require(controller.privatePersistentStore())
        let homeID = UUID()
        let olderHome = insert("CDHome", id: homeID, name: "Old", modifiedAt: old, store: privateStore, context: context)
        let newerHome = insert("CDHome", id: homeID, name: "New", modifiedAt: new, store: privateStore, context: context)
        let garage = insert(
            "CDStorageLocation", id: UUID(), name: "Garage", modifiedAt: old,
            store: privateStore, context: context, relationships: ["home": olderHome]
        )
        insert(
            "CDInventoryItem", id: UUID(), name: "Drill", modifiedAt: old,
            store: privateStore, context: context, relationships: ["storageLocation": garage]
        )
        insert(
            "CDStorageLocation", id: UUID(), name: "Attic", modifiedAt: old,
            store: privateStore, context: context, relationships: ["home": newerHome]
        )
        try context.save()

        let report = try DuplicateRecordRepairService(persistenceController: controller).repair()

        #expect(report.mergedHomes == 1)
        #expect(report.movedLocations == 1)
        context.refreshAllObjects()
        let homes = try fetch("CDHome", in: context)
        #expect(homes.map { $0.value(forKey: "name") as? String } == ["New"])
        let locations = try fetch("CDStorageLocation", in: context)
        #expect(locations.count == 2)
        #expect(locations.allSatisfy { ($0.value(forKey: "home") as? NSManagedObject)?.objectID == newerHome.objectID })
        let items = try fetch("CDInventoryItem", in: context)
        #expect(items.count == 1)
        #expect((items.first?.value(forKey: "storageLocation") as? NSManagedObject)?.objectID == garage.objectID)
    }

    @Test("Duplicate locations merge children and items into the survivor")
    func mergesDuplicateLocations() throws {
        let controller = try makeController()
        let context = controller.persistentContainer.viewContext
        let privateStore = try #require(controller.privatePersistentStore())
        let home = insert("CDHome", id: UUID(), name: "Home", modifiedAt: old, store: privateStore, context: context)
        let locationID = UUID()
        let loser = insert(
            "CDStorageLocation", id: locationID, name: "Closet", modifiedAt: old,
            store: privateStore, context: context, relationships: ["home": home]
        )
        let keeper = insert(
            "CDStorageLocation", id: locationID, name: "Closet", modifiedAt: new,
            store: privateStore, context: context, relationships: ["home": home]
        )
        let shelf = insert(
            "CDStorageLocation", id: UUID(), name: "Top Shelf", modifiedAt: old,
            store: privateStore, context: context, relationships: ["home": home, "parentLocation": loser]
        )
        insert(
            "CDInventoryItem", id: UUID(), name: "Coat", modifiedAt: old,
            store: privateStore, context: context, relationships: ["storageLocation": loser]
        )
        insert(
            "CDInventoryItem", id: UUID(), name: "Scarf", modifiedAt: old,
            store: privateStore, context: context, relationships: ["storageLocation": keeper]
        )
        try context.save()

        let report = try DuplicateRecordRepairService(persistenceController: controller).repair()

        #expect(report.mergedLocations == 1)
        #expect(report.movedItems == 1)
        context.refreshAllObjects()
        let locations = try fetch("CDStorageLocation", in: context)
        #expect(locations.count == 2)
        #expect((shelf.value(forKey: "parentLocation") as? NSManagedObject)?.objectID == keeper.objectID)
        let items = try fetch("CDInventoryItem", in: context)
        #expect(items.count == 2)
        #expect(items.allSatisfy { ($0.value(forKey: "storageLocation") as? NSManagedObject)?.objectID == keeper.objectID })

        // A second pass has nothing left to do.
        #expect(try DuplicateRecordRepairService(persistenceController: controller).repair() == .init())
    }

    @Test("A survivor parented to its own duplicate does not end up parented to itself")
    func survivorParentedToDuplicate() throws {
        let controller = try makeController()
        let context = controller.persistentContainer.viewContext
        let privateStore = try #require(controller.privatePersistentStore())
        let home = insert("CDHome", id: UUID(), name: "Home", modifiedAt: old, store: privateStore, context: context)
        let root = insert(
            "CDStorageLocation", id: UUID(), name: "Root", modifiedAt: old,
            store: privateStore, context: context, relationships: ["home": home]
        )
        let locationID = UUID()
        let loser = insert(
            "CDStorageLocation", id: locationID, name: "Box", modifiedAt: old,
            store: privateStore, context: context, relationships: ["home": home, "parentLocation": root]
        )
        let keeper = insert(
            "CDStorageLocation", id: locationID, name: "Box", modifiedAt: new,
            store: privateStore, context: context, relationships: ["home": home, "parentLocation": loser]
        )
        try context.save()

        try DuplicateRecordRepairService(persistenceController: controller).repair()

        context.refreshAllObjects()
        #expect((keeper.value(forKey: "parentLocation") as? NSManagedObject)?.objectID == root.objectID)
        #expect(try fetch("CDStorageLocation", in: context).count == 2)
    }

    @Test("Rows with the same id in different stores are never merged")
    func doesNotMergeAcrossStores() throws {
        let controller = try makeController()
        let context = controller.persistentContainer.viewContext
        let privateStore = try #require(controller.privatePersistentStore())
        let sharedStore = try #require(controller.sharedPersistentStore())
        let homeID = UUID()
        insert("CDHome", id: homeID, name: "Private", modifiedAt: old, store: privateStore, context: context)
        insert("CDHome", id: homeID, name: "Shared", modifiedAt: new, store: sharedStore, context: context)
        try context.save()

        let report = try DuplicateRecordRepairService(
            persistenceController: controller,
            canModifySharedHome: { _ in true }
        ).repair()

        #expect(report.didMerge == false)
        #expect(try fetch("CDHome", in: context, store: privateStore).count == 1)
        #expect(try fetch("CDHome", in: context, store: sharedStore).count == 1)
    }

    @Test("Shared-store duplicates are merged only when the user can edit the share")
    func sharedStoreRespectsPermission() throws {
        let controller = try makeController()
        let context = controller.persistentContainer.viewContext
        let sharedStore = try #require(controller.sharedPersistentStore())
        let homeID = UUID()
        insert("CDHome", id: homeID, name: "A", modifiedAt: old, store: sharedStore, context: context)
        insert("CDHome", id: homeID, name: "B", modifiedAt: new, store: sharedStore, context: context)
        try context.save()

        let readOnly = try DuplicateRecordRepairService(
            persistenceController: controller,
            canModifySharedHome: { _ in false }
        ).repair()
        #expect(readOnly.didMerge == false)
        #expect(readOnly.skippedReadOnlyGroups == 1)
        #expect(try fetch("CDHome", in: context, store: sharedStore).count == 2)

        let writable = try DuplicateRecordRepairService(
            persistenceController: controller,
            canModifySharedHome: { _ in true }
        ).repair()
        #expect(writable.mergedHomes == 1)
        #expect(try fetch("CDHome", in: context, store: sharedStore).count == 1)
    }

    @Test("Without a readable share, shared-store duplicates are left alone")
    func defaultSharedPermissionFailsClosed() throws {
        let controller = try makeController()
        let context = controller.persistentContainer.viewContext
        let sharedStore = try #require(controller.sharedPersistentStore())
        let homeID = UUID()
        insert("CDHome", id: homeID, name: "A", modifiedAt: old, store: sharedStore, context: context)
        insert("CDHome", id: homeID, name: "B", modifiedAt: new, store: sharedStore, context: context)
        try context.save()

        let report = try DuplicateRecordRepairService(persistenceController: controller).repair()

        #expect(report.didMerge == false)
        #expect(try fetch("CDHome", in: context, store: sharedStore).count == 2)
    }
}
