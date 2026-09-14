import CloudKit
import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("Siri Inventory Repository")
@MainActor
struct SiriInventoryRepositoryTests {
    @MainActor
    private struct Fixture {
        let directory: URL
        let controller: PersistenceController
        let repository: CoreDataAppRepository

        init(access: ((NSManagedObjectID) throws -> SiriSharedHomeAccess?)? = nil) throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("SiriInventoryRepositoryTests-\(UUID().uuidString)", isDirectory: true)
            controller = try PersistenceController(storeDirectory: directory, cloudKitEnabled: false)
            repository = CoreDataAppRepository(
                persistenceController: controller,
                shareService: nil,
                siriSharedHomeAccess: access
            )
        }

        var context: NSManagedObjectContext { controller.persistentContainer.viewContext }

        func close() {
            context.reset()
            let coordinator = controller.persistentContainer.persistentStoreCoordinator
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
            try? FileManager.default.removeItem(at: directory)
        }

        func home(_ name: String, shared: Bool = false) throws -> NSManagedObject {
            let store = try #require(shared ? controller.sharedPersistentStore() : controller.privatePersistentStore())
            let home = NSEntityDescription.insertNewObject(forEntityName: "CDHome", into: context)
            context.assign(home, to: store)
            home.setValue(UUID(), forKey: "id")
            home.setValue(name, forKey: "name")
            try context.obtainPermanentIDs(for: [home])
            return home
        }

        func location(_ name: String, home: NSManagedObject, parent: NSManagedObject? = nil) throws -> NSManagedObject {
            let store = try #require(home.objectID.persistentStore)
            let location = NSEntityDescription.insertNewObject(forEntityName: "CDStorageLocation", into: context)
            context.assign(location, to: store)
            location.setValue(UUID(), forKey: "id")
            location.setValue(name, forKey: "name")
            location.setValue(home, forKey: "home")
            location.setValue(parent, forKey: "parentLocation")
            try context.obtainPermanentIDs(for: [location])
            return location
        }

        func item(_ title: String, location: NSManagedObject) throws -> NSManagedObject {
            let store = try #require(location.objectID.persistentStore)
            let item = NSEntityDescription.insertNewObject(forEntityName: "CDInventoryItem", into: context)
            context.assign(item, to: store)
            item.setValue(UUID(), forKey: "id")
            item.setValue(title, forKey: "title")
            item.setValue(location, forKey: "storageLocation")
            item.setValue(["travel", "identity"], forKey: "tags")
            item.setValue("Blue cover", forKey: "itemDescription")
            item.setValue("📘", forKey: "emoji")
            return item
        }
    }

    @Test("Snapshot uses exact saved names and refreshes after saves and deletion")
    func savedSnapshot() throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        #expect(fixture.controller.persistentContainer.persistentStoreDescriptions.allSatisfy {
            $0.cloudKitContainerOptions == nil
        })

        let home = try fixture.home("Juniper House")
        let closet = try fixture.location("Entry Closet", home: home)
        let shelf = try fixture.location("Top Shelf", home: home, parent: closet)
        let item = try fixture.item("Passport", location: shelf)
        try fixture.context.save()

        // The foreground editor can have unsaved changes; Siri only describes stored data.
        shelf.setValue("Unsaved location", forKey: "name")
        let records = try fixture.repository.siriInventoryRecords(excludingHomeIDs: [])
        let record = try #require(records.first)
        #expect(records.count == 1)
        #expect(record.id == item.value(forKey: "id") as? UUID)
        #expect(record.homeName == "Juniper House")
        #expect(record.title == "Passport")
        #expect(record.locationPath == "Entry Closet > Top Shelf")
        #expect(record.itemDescription == "Blue cover")
        #expect(record.tags == ["travel", "identity"])
        #expect(record.emoji == "📘")

        try fixture.context.save()
        #expect(try fixture.repository.siriInventoryRecords(excludingHomeIDs: []).first?.locationPath
            == "Entry Closet > Unsaved location")
        fixture.context.delete(item)
        try fixture.context.save()
        #expect(try fixture.repository.siriInventoryRecords(excludingHomeIDs: []).isEmpty)
    }

    @Test("Hidden homes are excluded even if access was previously verified")
    func hiddenHomes() throws {
        var lookupCount = 0
        let fixture = try Fixture { _ in
            lookupCount += 1
            return SiriSharedHomeAccess(acceptanceStatus: .accepted, permission: .readOnly)
        }
        defer { fixture.close() }
        let privateHome = try fixture.home("Private Home")
        let sharedHome = try fixture.home("Shared Home", shared: true)
        _ = try fixture.item("Private keys", location: fixture.location("Drawer", home: privateHome))
        _ = try fixture.item("Shared keys", location: fixture.location("Drawer", home: sharedHome))
        try fixture.context.save()
        let hiddenIDs = try Set([
            #require(privateHome.value(forKey: "id") as? UUID),
            #require(sharedHome.value(forKey: "id") as? UUID)
        ])
        #expect(try fixture.repository.siriInventoryRecords(excludingHomeIDs: hiddenIDs).isEmpty)
        #expect(lookupCount == 0)
    }

    @Test("Only accepted participants with explicit read access can expose shared inventory")
    func sharedParticipantStates() throws {
        var access: SiriSharedHomeAccess? = .init(acceptanceStatus: .accepted, permission: .readOnly)
        let fixture = try Fixture { _ in access }
        defer { fixture.close() }
        let home = try fixture.home("Shared Home", shared: true)
        _ = try fixture.item("Shared keys", location: fixture.location("Drawer", home: home))
        try fixture.context.save()

        let cases: [(CKShare.ParticipantAcceptanceStatus, CKShare.ParticipantPermission, Bool)] = [
            (.accepted, .readOnly, true),
            (.accepted, .readWrite, true),
            (.accepted, .none, false),
            (.accepted, .unknown, false),
            (.pending, .readOnly, false),
            (.removed, .readWrite, false),
            (.unknown, .readWrite, false)
        ]
        for (status, permission, expectedAccess) in cases {
            access = .init(acceptanceStatus: status, permission: permission)
            let records = try fixture.repository.siriInventoryRecords(excludingHomeIDs: [])
            #expect(records.isEmpty == !expectedAccess)
        }
        access = nil
        #expect(try fixture.repository.siriInventoryRecords(excludingHomeIDs: []).isEmpty)
    }

    @Test("Shared lookup failures exclude that home while preserving private results")
    func failedShareLookup() throws {
        enum LookupFailure: Error { case unavailable }
        let fixture = try Fixture { _ in throw LookupFailure.unavailable }
        defer { fixture.close() }
        let privateHome = try fixture.home("Private Home")
        let sharedHome = try fixture.home("Shared Home", shared: true)
        _ = try fixture.item("Private keys", location: fixture.location("Drawer", home: privateHome))
        _ = try fixture.item("Shared keys", location: fixture.location("Drawer", home: sharedHome))
        try fixture.context.save()

        let records = try fixture.repository.siriInventoryRecords(excludingHomeIDs: [])
        #expect(records.map(\.title) == ["Private keys"])
    }

    @Test("Orphaned, cross-home, and cyclic location paths never become Siri answers")
    func invalidRelationships() throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let firstHome = try fixture.home("First Home")
        let secondHome = try fixture.home("Second Home")
        let valid = try fixture.location("Valid", home: firstHome)
        _ = try fixture.item("Valid keys", location: valid)

        let orphan = try fixture.item("Orphan", location: valid)
        orphan.setValue(nil, forKey: "storageLocation")
        let missingHome = try fixture.location("No home", home: firstHome)
        missingHome.setValue(nil, forKey: "home")
        _ = try fixture.item("No home", location: missingHome)
        let wrongParent = try fixture.location("Other home's room", home: secondHome)
        let crossHome = try fixture.location("Cross-home shelf", home: firstHome, parent: wrongParent)
        _ = try fixture.item("Cross-home item", location: crossHome)
        let cycleA = try fixture.location("A", home: firstHome)
        let cycleB = try fixture.location("B", home: firstHome, parent: cycleA)
        cycleA.setValue(cycleB, forKey: "parentLocation")
        _ = try fixture.item("Cycle item", location: cycleB)
        let unnamed = try fixture.location("  ", home: firstHome)
        _ = try fixture.item("Unnamed location", location: unnamed)
        try fixture.context.save()

        #expect(try fixture.repository.siriInventoryRecords(excludingHomeIDs: []).map(\.title) == ["Valid keys"])
    }
}
