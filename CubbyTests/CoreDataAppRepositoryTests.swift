import CloudKit
import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("Core Data App Repository Tests")
struct CoreDataAppRepositoryTests {
    @MainActor
    private func makeRepository(
        shareService: (any HomeSharingServiceProtocol)? = nil
    ) throws -> CoreDataAppRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreDataAppRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory)
        return CoreDataAppRepository(
            persistenceController: controller,
            shareService: shareService
        )
    }

    @MainActor
    private func insertHomeGraph(
        named homeName: String,
        itemCount: Int,
        into store: NSPersistentStore,
        using repository: CoreDataAppRepository
    ) throws -> UUID {
        let context = repository.persistenceController.persistentContainer.viewContext
        let now = Date()

        let home = NSEntityDescription.insertNewObject(forEntityName: "CDHome", into: context)
        context.assign(home, to: store)
        let homeID = UUID()
        home.setValue(homeID, forKey: "id")
        home.setValue(homeName, forKey: "name")
        home.setValue(now, forKey: "createdAt")
        home.setValue(now, forKey: "modifiedAt")

        let location = NSEntityDescription.insertNewObject(forEntityName: "CDStorageLocation", into: context)
        context.assign(location, to: store)
        location.setValue(UUID(), forKey: "id")
        location.setValue("Unsorted", forKey: "name")
        location.setValue(Int16(0), forKey: "depth")
        location.setValue(now, forKey: "createdAt")
        location.setValue(now, forKey: "modifiedAt")
        location.setValue(home, forKey: "home")
        location.setValue(nil, forKey: "parentLocation")

        for index in 0..<itemCount {
            let item = NSEntityDescription.insertNewObject(forEntityName: "CDInventoryItem", into: context)
            context.assign(item, to: store)
            item.setValue(UUID(), forKey: "id")
            item.setValue("Item \(index)", forKey: "title")
            item.setValue(nil, forKey: "itemDescription")
            item.setValue(nil, forKey: "photoFileName")
            item.setValue(nil, forKey: "emoji")
            item.setValue(false, forKey: "isPendingAiEmoji")
            item.setValue(now, forKey: "createdAt")
            item.setValue(now, forKey: "modifiedAt")
            item.setValue([], forKey: "tags")
            item.setValue(location, forKey: "storageLocation")
        }

        try context.save()
        return homeID
    }

    @MainActor
    private func fetchLocationObject(
        id: UUID,
        using repository: CoreDataAppRepository
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDStorageLocation")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try repository.persistenceController.persistentContainer.viewContext.fetch(request).first
    }

    @MainActor
    private func fetchItemObject(
        id: UUID,
        using repository: CoreDataAppRepository
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDInventoryItem")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try repository.persistenceController.persistentContainer.viewContext.fetch(request).first
    }

    @MainActor
    private func fetchCount(
        entityName: String,
        predicate: NSPredicate? = nil,
        using repository: CoreDataAppRepository
    ) throws -> Int {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        request.predicate = predicate
        return try repository.persistenceController.persistentContainer.viewContext.count(for: request)
    }

    @Test("Owner home count ignores shared-store homes")
    @MainActor
    func testOwnerHomeCountIgnoresSharedStoreHomes() throws {
        let repository = try makeRepository()
        let controller = repository.persistenceController
        let privateStore = try #require(controller.privatePersistentStore())
        let sharedStore = try #require(controller.sharedPersistentStore())

        _ = try insertHomeGraph(
            named: "My Home",
            itemCount: 1,
            into: privateStore,
            using: repository
        )
        _ = try insertHomeGraph(
            named: "Shared A",
            itemCount: 2,
            into: sharedStore,
            using: repository
        )
        _ = try insertHomeGraph(
            named: "Shared B",
            itemCount: 3,
            into: sharedStore,
            using: repository
        )

        let ownerHomeCount = try repository.ownerHomeCount()

        #expect(ownerHomeCount == 1)
    }

    @Test("Owner item count ignores shared-store items")
    @MainActor
    func testOwnerItemCountIgnoresSharedStoreItems() throws {
        let repository = try makeRepository()
        let controller = repository.persistenceController
        let privateStore = try #require(controller.privatePersistentStore())
        let sharedStore = try #require(controller.sharedPersistentStore())

        let personalHomeID = try insertHomeGraph(
            named: "My Home",
            itemCount: 4,
            into: privateStore,
            using: repository
        )
        let sharedHomeID = try insertHomeGraph(
            named: "Shared Home",
            itemCount: 9,
            into: sharedStore,
            using: repository
        )

        let personalItemCount = try repository.ownerItemCount(for: personalHomeID)
        let sharedItemCount = try repository.ownerItemCount(for: sharedHomeID)

        #expect(personalItemCount == 4)
        #expect(sharedItemCount == 0)
    }

    @Test("Feature gate uses owned counts only when private and shared data are mixed")
    @MainActor
    func testFeatureGateUsesOwnedCountsOnlyWithMixedStores() throws {
        let repository = try makeRepository()
        let controller = repository.persistenceController
        let privateStore = try #require(controller.privatePersistentStore())
        let sharedStore = try #require(controller.sharedPersistentStore())

        let personalHomeID = try insertHomeGraph(
            named: "Bob's Home",
            itemCount: 10,
            into: privateStore,
            using: repository
        )
        let sharedHomeID = try insertHomeGraph(
            named: "Alice's Shared Home",
            itemCount: 25,
            into: sharedStore,
            using: repository
        )

        let personalHomeGate = FeatureGate.canCreateHome(dataSource: repository, isPro: false)
        let personalItemGate = FeatureGate.canCreateItem(homeId: personalHomeID, dataSource: repository, isPro: false)
        let sharedItemGate = FeatureGate.canCreateItem(homeId: sharedHomeID, dataSource: repository, isPro: false)

        #expect(personalHomeGate.isAllowed == false)
        #expect(personalHomeGate.reason == .homeLimitReached)
        #expect(personalItemGate.isAllowed == false)
        #expect(personalItemGate.reason == .itemLimitReached)
        #expect(sharedItemGate.isAllowed)
    }

    @Test("Creating a home with sharing enabled does not recurse")
    @MainActor
    func testCreateHomeWithShareServiceDoesNotRecurse() throws {
        let repository = try makeRepository(
            shareService: DebugMockHomeSharingService(mode: .owner)
        )

        let createdHome = try repository.createHome(name: "Primary Home")

        #expect(createdHome.name == "Primary Home")
        #expect(createdHome.participantSummary == nil)
        #expect(createdHome.permission == SharePermission(role: .owner))
    }

    @Test("Listing homes with sharing enabled does not recurse")
    @MainActor
    func testListHomesWithShareServiceDoesNotRecurse() throws {
        let repository = try makeRepository(
            shareService: DebugMockHomeSharingService(mode: .owner)
        )

        _ = try repository.createHome(name: "Primary Home")
        let homes = try repository.listHomes()

        #expect(homes.count == 1)
        #expect(homes.first?.name == "Primary Home")
    }

    @Test("Creating a root location in a shared home uses the shared store")
    @MainActor
    func testCreateRootLocationUsesHomeStore() throws {
        let repository = try makeRepository(
            shareService: DebugMockHomeSharingService(mode: .readWriteParticipant)
        )
        let controller = repository.persistenceController
        let sharedStore = try #require(controller.sharedPersistentStore())

        let sharedHomeID = try insertHomeGraph(
            named: "Shared Home",
            itemCount: 0,
            into: sharedStore,
            using: repository
        )

        let created = try repository.createLocation(
            AppLocationCreationDraft(
                name: "Attic",
                homeID: sharedHomeID,
                parentLocationID: nil
            )
        )

        let locationObject = try fetchLocationObject(id: created.id, using: repository)
        let requiredLocationObject = try #require(locationObject)
        #expect(requiredLocationObject.objectID.persistentStore == sharedStore)
    }

    @Test("Creating a nested location in a shared home uses the parent store")
    @MainActor
    func testCreateNestedLocationUsesParentStore() throws {
        let repository = try makeRepository(
            shareService: DebugMockHomeSharingService(mode: .readWriteParticipant)
        )
        let controller = repository.persistenceController
        let sharedStore = try #require(controller.sharedPersistentStore())

        let sharedHomeID = try insertHomeGraph(
            named: "Shared Home",
            itemCount: 0,
            into: sharedStore,
            using: repository
        )

        let parent = try repository.createLocation(
            AppLocationCreationDraft(
                name: "Basement",
                homeID: sharedHomeID,
                parentLocationID: nil
            )
        )
        let child = try repository.createLocation(
            AppLocationCreationDraft(
                name: "Tool Wall",
                homeID: sharedHomeID,
                parentLocationID: parent.id
            )
        )

        let childObject = try fetchLocationObject(id: child.id, using: repository)
        let requiredChildObject = try #require(childObject)
        #expect(requiredChildObject.objectID.persistentStore == sharedStore)
    }

    @Test("Collaborator location creation stays in the shared store")
    @MainActor
    func testCollaboratorCreateLocationUsesSharedStore() throws {
        let repository = try makeRepository(
            shareService: DebugMockHomeSharingService(mode: .readWriteParticipant)
        )
        let controller = repository.persistenceController
        let sharedStore = try #require(controller.sharedPersistentStore())

        let sharedHomeID = try insertHomeGraph(
            named: "Shared Home",
            itemCount: 0,
            into: sharedStore,
            using: repository
        )

        let created = try repository.createLocation(
            AppLocationCreationDraft(
                name: "Guest Room",
                homeID: sharedHomeID,
                parentLocationID: nil
            )
        )

        let locationObject = try fetchLocationObject(id: created.id, using: repository)
        let requiredLocationObject = try #require(locationObject)
        #expect(requiredLocationObject.objectID.persistentStore == sharedStore)
    }

    @Test("Moving an item inside a shared home keeps the shared store")
    @MainActor
    func testMoveItemWithinSharedHomeKeepsSharedStore() throws {
        let repository = try makeRepository(
            shareService: DebugMockHomeSharingService(mode: .readWriteParticipant)
        )
        let controller = repository.persistenceController
        let sharedStore = try #require(controller.sharedPersistentStore())

        let sharedHomeID = try insertHomeGraph(
            named: "Shared Home",
            itemCount: 1,
            into: sharedStore,
            using: repository
        )

        let locations = try repository.listLocations().filter { $0.homeID == sharedHomeID }
        let currentLocation = try #require(locations.first)
        let newLocation = try repository.createLocation(
            AppLocationCreationDraft(
                name: "Closet",
                homeID: sharedHomeID,
                parentLocationID: nil
            )
        )
        let item = try #require(try repository.listItems().first { $0.homeID == sharedHomeID })

        let movedItem = try repository.moveItem(id: item.id, to: newLocation.id)

        #expect(movedItem.storageLocationID == newLocation.id)
        let itemObject = try fetchItemObject(id: item.id, using: repository)
        let requiredItemObject = try #require(itemObject)
        #expect(requiredItemObject.objectID.persistentStore == sharedStore)
        #expect(currentLocation.id != newLocation.id)
    }

    @Test("Moving an item across stores is rejected")
    @MainActor
    func testMoveItemAcrossStoresIsRejected() throws {
        let repository = try makeRepository(
            shareService: DebugMockHomeSharingService(mode: .readWriteParticipant)
        )
        let controller = repository.persistenceController
        let privateStore = try #require(controller.privatePersistentStore())
        let sharedStore = try #require(controller.sharedPersistentStore())

        let privateHomeID = try insertHomeGraph(
            named: "Private Home",
            itemCount: 0,
            into: privateStore,
            using: repository
        )
        let sharedHomeID = try insertHomeGraph(
            named: "Shared Home",
            itemCount: 1,
            into: sharedStore,
            using: repository
        )

        let privateLocation = try #require(
            try repository.listLocations().first { $0.homeID == privateHomeID }
        )
        let sharedItem = try #require(
            try repository.listItems().first { $0.homeID == sharedHomeID }
        )

        #expect(throws: AppRepositoryError.invalidMoveTarget) {
            try repository.moveItem(id: sharedItem.id, to: privateLocation.id)
        }
    }

    @Test("Deleting a home removes its whole graph and leaves other homes untouched")
    @MainActor
    func testDeleteHomeRemovesOnlyThatHomeGraph() throws {
        let repository = try makeRepository()
        let privateStore = try #require(repository.persistenceController.privatePersistentStore())
        let deletedHomeID = try insertHomeGraph(
            named: "Delete Me",
            itemCount: 2,
            into: privateStore,
            using: repository
        )
        let keptHomeID = try insertHomeGraph(
            named: "Keep Me",
            itemCount: 1,
            into: privateStore,
            using: repository
        )

        try repository.deleteHome(id: deletedHomeID)

        let homes = try repository.listHomes()
        #expect(homes.map(\.id) == [keptHomeID])
        #expect(try fetchCount(entityName: "CDHome", using: repository) == 1)
        #expect(try fetchCount(entityName: "CDStorageLocation", using: repository) == 1)
        #expect(try fetchCount(entityName: "CDInventoryItem", using: repository) == 1)
        #expect(try repository.ownerItemCount(for: keptHomeID) == 1)
    }

    @Test("Leaving a collaborator shared home delegates to sharing and keeps delete untouched")
    @MainActor
    func testLeaveSharedHomeDelegatesWithoutDeleting() async throws {
        let shareService = RecordingHomeSharingService(role: .readWriteParticipant)
        let repository = try makeRepository(shareService: shareService)
        let sharedStore = try #require(repository.persistenceController.sharedPersistentStore())
        let sharedHomeID = try insertHomeGraph(
            named: "Shared With Me",
            itemCount: 1,
            into: sharedStore,
            using: repository
        )

        try await repository.leaveSharedHome(id: sharedHomeID)

        #expect(shareService.leftHomeIDs == [sharedHomeID])
        #expect(try fetchCount(entityName: "CDHome", using: repository) == 1)
        #expect(try fetchCount(entityName: "CDInventoryItem", using: repository) == 1)
    }
}

@MainActor
private final class RecordingHomeSharingService: HomeSharingServiceProtocol {
    var leftHomeIDs: [UUID] = []
    private let role: SharePermission.Role

    init(role: SharePermission.Role) {
        self.role = role
    }

    func shareHome(_ home: AppHome) async throws -> CKShare {
        makeShare(for: home)
    }

    func shareURL(for home: AppHome) async throws -> URL {
        URL(string: "https://icloud.com/share/\(home.id.uuidString)")!
    }

    func fetchShare(for home: AppHome) -> CKShare? {
        makeShare(for: home)
    }

    func permission(for home: AppHome) -> SharePermission {
        SharePermission(role: role)
    }

    func canEdit(_ home: AppHome) -> Bool {
        SharePermission(role: role).canMutate
    }

    func isShared(_ home: AppHome) -> Bool {
        true
    }

    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws {
        _ = metadata
    }

    func participants(for home: AppHome) -> [CKShare.Participant] {
        _ = home
        return []
    }

    func leaveSharedHome(_ home: AppHome) async throws {
        leftHomeIDs.append(home.id)
    }

    func shareForController(
        _ home: AppHome,
        completion: @escaping (CKShare?, CKContainer?, Error?) -> Void
    ) {
        completion(makeShare(for: home), CKContainer(identifier: CloudKitSyncSettings.containerIdentifier), nil)
    }

    private func makeShare(for home: AppHome) -> CKShare {
        let share = CKShare(rootRecord: CKRecord(recordType: "Home"))
        share[CKShare.SystemFieldKey.title] = home.name as CKRecordValue
        return share
    }
}
