import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("Core Data App Repository Tests")
struct CoreDataAppRepositoryTests {
    @MainActor
    private func makeRepository() throws -> CoreDataAppRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreDataAppRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory)
        return CoreDataAppRepository(
            persistenceController: controller,
            shareService: nil
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
}
