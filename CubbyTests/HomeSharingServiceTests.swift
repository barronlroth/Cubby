import CloudKit
import CoreData
import Foundation
import Testing
@testable import Cubby

/// Exercises the real `HomeSharingService` against isolated stores, with the
/// `NSPersistentCloudKitContainer` sharing calls replaced by a fake.
@Suite("Home Sharing Service Tests")
@MainActor
struct HomeSharingServiceTests {
    private struct Fixture {
        let controller: PersistenceController
        let container: FakeSharingContainer
        let service: HomeSharingService
        var context: NSManagedObjectContext { controller.persistentContainer.viewContext }
        var privateStore: NSPersistentStore { controller.privatePersistentStore()! }
        var sharedStore: NSPersistentStore { controller.sharedPersistentStore()! }
    }

    private enum FakeError: Error { case lookup, accept }

    private func makeFixture() throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeSharingServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory)
        let container = FakeSharingContainer()
        let service = HomeSharingService(persistenceController: controller, container: container)
        return Fixture(controller: controller, container: container, service: service)
    }

    @discardableResult
    private func insert(
        _ entityName: String,
        id: UUID? = UUID(),
        name: String,
        store: NSPersistentStore,
        in fixture: Fixture,
        relationships: [String: NSManagedObject?] = [:]
    ) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: fixture.context)
        fixture.context.assign(object, to: store)
        object.setValue(id, forKey: "id")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "modifiedAt")
        if entityName == "CDInventoryItem" {
            object.setValue(name, forKey: "title")
            object.setValue(false, forKey: "isPendingAiEmoji")
            object.setValue([String](), forKey: "tags")
        } else {
            object.setValue(name, forKey: "name")
        }
        if entityName == "CDStorageLocation" {
            object.setValue(Int16(0), forKey: "depth")
        }
        for (key, value) in relationships {
            object.setValue(value, forKey: key)
        }
        return object
    }

    private func appHome(_ object: NSManagedObject) -> AppHome {
        AppHome(
            id: object.value(forKey: "id") as! UUID,
            name: object.value(forKey: "name") as? String ?? "",
            createdAt: Date(),
            modifiedAt: Date(),
            isShared: false,
            isOwnedByCurrentUser: true,
            permission: SharePermission(role: .owner),
            participantSummary: nil
        )
    }

    /// A private home with one location and one item.
    private func makeValidHome(in fixture: Fixture, name: String = "Home") throws -> NSManagedObject {
        let home = insert("CDHome", name: name, store: fixture.privateStore, in: fixture)
        let shelf = insert(
            "CDStorageLocation", name: "Shelf", store: fixture.privateStore, in: fixture,
            relationships: ["home": home]
        )
        insert(
            "CDInventoryItem", name: "Tape", store: fixture.privateStore, in: fixture,
            relationships: ["storageLocation": shelf]
        )
        try fixture.context.save()
        return home
    }

    // MARK: Lookup

    @Test("An unshared home reports not shared and owner permission")
    func unsharedLookup() throws {
        let fixture = try makeFixture()
        let home = appHome(try makeValidHome(in: fixture))

        #expect(fixture.service.shareLookup(for: home).share == nil)
        #expect(fixture.service.isShared(home) == false)
        #expect(fixture.service.permission(for: home).role == .owner)
        #expect(fixture.service.canEdit(home))
    }

    @Test("A failed lookup is read-only, never owner, and not reported as unshared")
    func failedLookupIsReadOnly() throws {
        let fixture = try makeFixture()
        let home = appHome(try makeValidHome(in: fixture))
        fixture.container.fetchError = FakeError.lookup

        #expect(fixture.service.shareLookup(for: home).isLookupFailure)
        #expect(fixture.service.permission(for: home).role == .readOnlyParticipant)
        #expect(fixture.service.canEdit(home) == false)
        #expect(fixture.service.isOwnedByCurrentUser(home) == false)
    }

    @Test("Batched snapshots use one lookup and mark every home read-only when it fails")
    func batchedSnapshots() throws {
        let fixture = try makeFixture()
        let first = try makeValidHome(in: fixture, name: "A")
        let second = try makeValidHome(in: fixture, name: "B")
        let requests = [first, second].map {
            HomeShareLookupRequest(home: appHome($0), objectID: $0.objectID)
        }

        let healthy = fixture.service.sharingSnapshots(for: requests)
        #expect(fixture.container.fetchCalls == 1)
        #expect(healthy.values.allSatisfy { $0.permission.role == .owner && !$0.lookupFailed })

        fixture.container.fetchError = FakeError.lookup
        let failed = fixture.service.sharingSnapshots(for: requests)
        #expect(failed.count == 2)
        #expect(failed.values.allSatisfy { $0.lookupFailed && $0.permission.role == .readOnlyParticipant })
    }

    // MARK: Share creation

    @Test("Preparing a share creates it once, titles it, and then reuses it")
    func prepareShareCreatesThenReuses() async throws {
        let fixture = try makeFixture()
        let home = appHome(try makeValidHome(in: fixture, name: "Beach House"))

        let created = try await fixture.service.prepareShare(for: home)
        let reused = try await fixture.service.prepareShare(for: home)

        #expect(fixture.container.shareCalls == 1)
        #expect(created[CKShare.SystemFieldKey.title] as? String == "Beach House")
        #expect(reused.recordID == created.recordID)
        #expect(fixture.service.isShared(home))
        #expect(created.publicPermission == .none)
    }

    @Test("A failed lookup blocks share creation")
    func lookupFailureBlocksCreation() async throws {
        let fixture = try makeFixture()
        let home = appHome(try makeValidHome(in: fixture))
        fixture.container.fetchError = FakeError.lookup

        await #expect(throws: HomeSharingServiceError.shareLookupFailed) {
            try await fixture.service.prepareShare(for: home)
        }
        #expect(fixture.container.shareCalls == 0)
    }

    @Test("Container share errors propagate")
    func shareErrorPropagates() async throws {
        let fixture = try makeFixture()
        let home = appHome(try makeValidHome(in: fixture))
        fixture.container.shareError = CKError(.networkUnavailable)

        await #expect(throws: CKError.self) {
            try await fixture.service.prepareShare(for: home)
        }
    }

    // MARK: Preflight (#86)

    @Test("Preflight rejects a home in the shared store")
    func preflightRejectsSharedStoreHome() async throws {
        let fixture = try makeFixture()
        let homeObject = insert("CDHome", name: "Theirs", store: fixture.sharedStore, in: fixture)
        try fixture.context.save()
        let home = appHome(homeObject)

        await #expect(throws: HomeSharePreflightError.objectNotInPrivateStore(entity: "CDHome", id: home.id)) {
            try await fixture.service.prepareShare(for: home)
        }
        #expect(fixture.container.shareCalls == 0)
    }

    @Test("Preflight rejects duplicate location ids in the home graph")
    func preflightRejectsDuplicateLocationIDs() async throws {
        let fixture = try makeFixture()
        let homeObject = insert("CDHome", name: "Home", store: fixture.privateStore, in: fixture)
        let duplicateID = UUID()
        for name in ["A", "B"] {
            insert(
                "CDStorageLocation", id: duplicateID, name: name, store: fixture.privateStore, in: fixture,
                relationships: ["home": homeObject]
            )
        }
        try fixture.context.save()

        await #expect(throws: HomeSharePreflightError.duplicateID(entity: "CDStorageLocation", id: duplicateID)) {
            try await fixture.service.prepareShare(for: appHome(homeObject))
        }
        #expect(fixture.container.shareCalls == 0)
    }

    @Test("Preflight rejects a location parent cycle")
    func preflightRejectsCycle() async throws {
        let fixture = try makeFixture()
        let homeObject = insert("CDHome", name: "Home", store: fixture.privateStore, in: fixture)
        let first = insert(
            "CDStorageLocation", name: "A", store: fixture.privateStore, in: fixture,
            relationships: ["home": homeObject]
        )
        let second = insert(
            "CDStorageLocation", name: "B", store: fixture.privateStore, in: fixture,
            relationships: ["home": homeObject, "parentLocation": first]
        )
        first.setValue(second, forKey: "parentLocation")
        try fixture.context.save()

        do {
            _ = try await fixture.service.prepareShare(for: appHome(homeObject))
            Issue.record("Expected a parent-cycle preflight error")
        } catch let error as HomeSharePreflightError {
            guard case .parentCycle = error else {
                Issue.record("Unexpected preflight error \(error)")
                return
            }
        }
        #expect(fixture.container.shareCalls == 0)
    }

    @Test("Preflight rejects items without an id")
    func preflightRejectsMissingItemID() async throws {
        let fixture = try makeFixture()
        let homeObject = insert("CDHome", name: "Home", store: fixture.privateStore, in: fixture)
        let shelf = insert(
            "CDStorageLocation", name: "Shelf", store: fixture.privateStore, in: fixture,
            relationships: ["home": homeObject]
        )
        insert(
            "CDInventoryItem", id: nil, name: "Ghost", store: fixture.privateStore, in: fixture,
            relationships: ["storageLocation": shelf]
        )
        try fixture.context.save()

        await #expect(throws: HomeSharePreflightError.missingID(entity: "CDInventoryItem")) {
            try await fixture.service.prepareShare(for: appHome(homeObject))
        }
    }

    @Test("Preflight rejects child locations that belong to another home")
    func preflightRejectsForeignChild() async throws {
        let fixture = try makeFixture()
        let homeObject = insert("CDHome", name: "Home", store: fixture.privateStore, in: fixture)
        let otherHome = insert("CDHome", name: "Other", store: fixture.privateStore, in: fixture)
        let parent = insert(
            "CDStorageLocation", name: "Parent", store: fixture.privateStore, in: fixture,
            relationships: ["home": homeObject]
        )
        let foreignID = UUID()
        insert(
            "CDStorageLocation", id: foreignID, name: "Foreign", store: fixture.privateStore, in: fixture,
            relationships: ["home": otherHome, "parentLocation": parent]
        )
        try fixture.context.save()

        await #expect(throws: HomeSharePreflightError.belongsToAnotherHome(entity: "CDStorageLocation", id: foreignID)) {
            try await fixture.service.prepareShare(for: appHome(homeObject))
        }
        #expect(fixture.container.shareCalls == 0)
    }

    // MARK: Accept and leave

    @Test("Accepting an invitation targets the shared store and propagates errors")
    func acceptInvitation() async throws {
        let fixture = try makeFixture()
        let metadata = unsafeBitCast(NSObject(), to: CKShare.Metadata.self)

        try await fixture.service.acceptShareInvitation(from: metadata)
        #expect(fixture.container.acceptedStores == [fixture.sharedStore.identifier])

        fixture.container.acceptError = FakeError.accept
        await #expect(throws: FakeError.self) {
            try await fixture.service.acceptShareInvitation(from: metadata)
        }
    }

    @Test("Leaving an unshared home fails with shareNotFound")
    func leaveUnshared() async throws {
        let fixture = try makeFixture()
        let home = appHome(try makeValidHome(in: fixture))

        await #expect(throws: HomeSharingServiceError.shareNotFound) {
            try await fixture.service.leaveSharedHome(home)
        }
    }

    @Test("Leaving after a failed lookup reports the lookup failure")
    func leaveAfterLookupFailure() async throws {
        let fixture = try makeFixture()
        let home = appHome(try makeValidHome(in: fixture))
        fixture.container.fetchError = FakeError.lookup

        await #expect(throws: HomeSharingServiceError.shareLookupFailed) {
            try await fixture.service.leaveSharedHome(home)
        }
    }

    // MARK: Repository integration

    @Test("Repository maps a failed lookup to a read-only, non-owner home")
    func repositoryMapsLookupFailure() throws {
        let fixture = try makeFixture()
        let homeObject = try makeValidHome(in: fixture)
        fixture.container.fetchError = FakeError.lookup
        let repository = CoreDataAppRepository(
            persistenceController: fixture.controller,
            shareService: fixture.service
        )

        let home = try #require(try repository.listHomes().first)
        #expect(home.id == homeObject.value(forKey: "id") as? UUID)
        #expect(home.isOwnedByCurrentUser == false)
        #expect(home.permission.canMutate == false)
        #expect(repository.permission(for: home.id).role == .readOnlyParticipant)
    }
}

private final class FakeSharingContainer: CloudKitSharingContaining {
    var fetchError: Error?
    var shareError: Error?
    var acceptError: Error?
    private(set) var fetchCalls = 0
    private(set) var shareCalls = 0
    private(set) var acceptedStores: [String?] = []
    private var sharesByObjectID: [NSManagedObjectID: CKShare] = [:]

    func share(_ objects: [NSManagedObject], to share: CKShare?) async throws -> CKShare {
        shareCalls += 1
        if let shareError { throw shareError }
        let created = share ?? CKShare(rootRecord: CKRecord(recordType: "CD_CDHome"))
        for object in objects {
            sharesByObjectID[object.objectID] = created
        }
        return created
    }

    func fetchShares(matching objectIDs: [NSManagedObjectID]) throws -> [NSManagedObjectID: CKShare] {
        fetchCalls += 1
        if let fetchError { throw fetchError }
        return sharesByObjectID.filter { objectIDs.contains($0.key) }
    }

    func acceptShareInvitations(from metadata: [CKShare.Metadata], into store: NSPersistentStore) async throws {
        if let acceptError { throw acceptError }
        acceptedStores.append(store.identifier)
    }

    func purgeObjectsAndRecordsInZone(with zoneID: CKRecordZone.ID, in store: NSPersistentStore?) async throws {}

    func persistUpdatedShare(_ share: CKShare, in store: NSPersistentStore) async throws -> CKShare {
        share
    }
}
