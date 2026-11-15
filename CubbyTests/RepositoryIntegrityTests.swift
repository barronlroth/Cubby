import CloudKit
import CoreData
import Foundation
import Testing
@testable import Cubby

/// Damaged or duplicated stores (as CloudKit imports can produce) must never trap
/// a refresh. See issue #83.
@Suite("Repository Integrity Tests")
struct RepositoryIntegrityTests {
    @MainActor
    private func makeRepository(
        shareService: (any HomeSharingServiceProtocol)? = nil
    ) throws -> CoreDataAppRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RepositoryIntegrityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory)
        return CoreDataAppRepository(persistenceController: controller, shareService: shareService)
    }

    @MainActor
    private func context(_ repository: CoreDataAppRepository) -> NSManagedObjectContext {
        repository.persistenceController.persistentContainer.viewContext
    }

    @MainActor
    @discardableResult
    private func insertHome(
        id: UUID?,
        name: String,
        modifiedAt: Date = Date(),
        into store: NSPersistentStore,
        repository: CoreDataAppRepository
    ) -> NSManagedObject {
        let context = context(repository)
        let home = NSEntityDescription.insertNewObject(forEntityName: "CDHome", into: context)
        context.assign(home, to: store)
        home.setValue(id, forKey: "id")
        home.setValue(name, forKey: "name")
        home.setValue(modifiedAt, forKey: "createdAt")
        home.setValue(modifiedAt, forKey: "modifiedAt")
        return home
    }

    @MainActor
    @discardableResult
    private func insertLocation(
        id: UUID?,
        name: String,
        home: NSManagedObject,
        parent: NSManagedObject? = nil,
        modifiedAt: Date = Date(),
        into store: NSPersistentStore,
        repository: CoreDataAppRepository
    ) -> NSManagedObject {
        let context = context(repository)
        let location = NSEntityDescription.insertNewObject(forEntityName: "CDStorageLocation", into: context)
        context.assign(location, to: store)
        location.setValue(id, forKey: "id")
        location.setValue(name, forKey: "name")
        location.setValue(Int16(0), forKey: "depth")
        location.setValue(modifiedAt, forKey: "createdAt")
        location.setValue(modifiedAt, forKey: "modifiedAt")
        location.setValue(home, forKey: "home")
        location.setValue(parent, forKey: "parentLocation")
        return location
    }

    @MainActor
    @discardableResult
    private func insertItem(
        title: String,
        location: NSManagedObject,
        into store: NSPersistentStore,
        repository: CoreDataAppRepository
    ) -> NSManagedObject {
        let context = context(repository)
        let item = NSEntityDescription.insertNewObject(forEntityName: "CDInventoryItem", into: context)
        context.assign(item, to: store)
        item.setValue(UUID(), forKey: "id")
        item.setValue(title, forKey: "title")
        item.setValue(false, forKey: "isPendingAiEmoji")
        item.setValue(Date(), forKey: "createdAt")
        item.setValue(Date(), forKey: "modifiedAt")
        item.setValue([String](), forKey: "tags")
        item.setValue(location, forKey: "storageLocation")
        return item
    }

    @Test("Duplicate home ids in one store do not trap and keep the newest row")
    @MainActor
    func duplicateHomesInPrivateStore() throws {
        let repository = try makeRepository()
        let privateStore = try #require(repository.persistenceController.privatePersistentStore())
        let homeID = UUID()
        let older = insertHome(
            id: homeID, name: "Older", modifiedAt: Date(timeIntervalSince1970: 100),
            into: privateStore, repository: repository
        )
        let newer = insertHome(
            id: homeID, name: "Newer", modifiedAt: Date(timeIntervalSince1970: 200),
            into: privateStore, repository: repository
        )
        let olderLocation = insertLocation(
            id: UUID(), name: "Shelf", home: older, into: privateStore, repository: repository
        )
        insertLocation(id: UUID(), name: "Drawer", home: newer, into: privateStore, repository: repository)
        insertItem(title: "Hammer", location: olderLocation, into: privateStore, repository: repository)
        try context(repository).save()

        let homes = try repository.listHomes()
        #expect(homes.map(\.id) == [homeID])
        #expect(homes.first?.name == "Newer")
        #expect(try repository.home(id: homeID)?.name == "Newer")

        let locations = try repository.listLocations()
        #expect(Set(locations.map(\.name)) == ["Shelf", "Drawer"])
        #expect(locations.allSatisfy { $0.homeID == homeID })

        let items = try repository.listItems()
        #expect(items.map(\.title) == ["Hammer"])
        #expect(items.first?.homeID == homeID)
    }

    @Test("A home id present in both stores prefers the private-store row")
    @MainActor
    func duplicateHomeAcrossStoresPrefersPrivate() throws {
        let repository = try makeRepository()
        let privateStore = try #require(repository.persistenceController.privatePersistentStore())
        let sharedStore = try #require(repository.persistenceController.sharedPersistentStore())
        let homeID = UUID()
        let privateHome = insertHome(
            id: homeID, name: "Private", modifiedAt: Date(timeIntervalSince1970: 100),
            into: privateStore, repository: repository
        )
        let sharedHome = insertHome(
            id: homeID, name: "Shared", modifiedAt: Date(timeIntervalSince1970: 999),
            into: sharedStore, repository: repository
        )
        insertLocation(id: UUID(), name: "Private Shelf", home: privateHome, into: privateStore, repository: repository)
        insertLocation(id: UUID(), name: "Shared Shelf", home: sharedHome, into: sharedStore, repository: repository)
        try context(repository).save()

        let homes = try repository.listHomes()
        #expect(homes.count == 1)
        #expect(homes.first?.name == "Private")
        #expect(try repository.home(id: homeID)?.name == "Private")
        #expect(try repository.listLocations().count == 2)
        #expect(try repository.listLocations().allSatisfy { $0.homeName == "Private" })
    }

    @Test("Duplicate location ids, including one in each store, do not trap")
    @MainActor
    func duplicateLocations() throws {
        let repository = try makeRepository()
        let privateStore = try #require(repository.persistenceController.privatePersistentStore())
        let sharedStore = try #require(repository.persistenceController.sharedPersistentStore())

        let privateHome = insertHome(id: UUID(), name: "Home", into: privateStore, repository: repository)
        let sameStoreID = UUID()
        let firstCopy = insertLocation(
            id: sameStoreID, name: "Closet", home: privateHome,
            modifiedAt: Date(timeIntervalSince1970: 100), into: privateStore, repository: repository
        )
        insertLocation(
            id: sameStoreID, name: "Closet (newer)", home: privateHome,
            modifiedAt: Date(timeIntervalSince1970: 200), into: privateStore, repository: repository
        )
        insertItem(title: "Coat", location: firstCopy, into: privateStore, repository: repository)

        let sharedHome = insertHome(id: UUID(), name: "Cabin", into: sharedStore, repository: repository)
        let crossStoreID = UUID()
        insertLocation(
            id: crossStoreID, name: "Private Copy", home: privateHome,
            modifiedAt: Date(timeIntervalSince1970: 100), into: privateStore, repository: repository
        )
        let sharedCopy = insertLocation(
            id: crossStoreID, name: "Shared Copy", home: sharedHome,
            modifiedAt: Date(timeIntervalSince1970: 999), into: sharedStore, repository: repository
        )
        insertItem(title: "Boots", location: sharedCopy, into: sharedStore, repository: repository)
        try context(repository).save()

        let locations = try repository.listLocations()
        #expect(locations.filter { $0.id == sameStoreID }.map(\.name) == ["Closet (newer)"])
        #expect(locations.filter { $0.id == crossStoreID }.map(\.name) == ["Private Copy"])
        #expect(try repository.location(id: crossStoreID)?.name == "Private Copy")

        let items = try repository.listItems()
        #expect(Set(items.map(\.title)) == ["Coat", "Boots"])
        #expect(items.first { $0.title == "Coat" }?.storageLocationName == "Closet (newer)")
    }

    @Test("A location parent cycle does not hang path building")
    @MainActor
    func locationParentCycle() throws {
        let repository = try makeRepository()
        let privateStore = try #require(repository.persistenceController.privatePersistentStore())
        let home = insertHome(id: UUID(), name: "Home", into: privateStore, repository: repository)
        let first = insertLocation(id: UUID(), name: "A", home: home, into: privateStore, repository: repository)
        let second = insertLocation(
            id: UUID(), name: "B", home: home, parent: first, into: privateStore, repository: repository
        )
        first.setValue(second, forKey: "parentLocation")
        insertItem(title: "Lamp", location: second, into: privateStore, repository: repository)
        try context(repository).save()

        let locations = try repository.listLocations()
        #expect(locations.count == 2)
        #expect(locations.first { $0.name == "B" }?.fullPath == "A > B")
        #expect(locations.first { $0.name == "A" }?.childLocationIDs == [second.value(forKey: "id") as? UUID].compactMap { $0 })

        let items = try repository.listItems()
        #expect(items.first?.storageLocationPath == "A > B")
    }

    @Test("Homes without an id are skipped instead of receiving a random id")
    @MainActor
    func nilHomeIDIsSkipped() throws {
        let repository = try makeRepository()
        let privateStore = try #require(repository.persistenceController.privatePersistentStore())
        let broken = insertHome(id: nil, name: "Broken", into: privateStore, repository: repository)
        insertLocation(id: nil, name: "Orphan", home: broken, into: privateStore, repository: repository)
        let good = insertHome(id: UUID(), name: "Good", into: privateStore, repository: repository)
        insertLocation(id: UUID(), name: "Shelf", home: good, into: privateStore, repository: repository)
        try context(repository).save()

        let first = try repository.listHomes()
        let second = try repository.listHomes()
        #expect(first.map(\.name) == ["Good"])
        #expect(first.map(\.id) == second.map(\.id))
        #expect(try repository.listLocations().map(\.name) == ["Shelf"])
        #expect(try repository.listItems().isEmpty)
    }

    @Test("Child locations are listed in name order")
    @MainActor
    func childLocationOrdering() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        let parent = try repository.createLocation(
            AppLocationCreationDraft(name: "Garage", homeID: home.id, parentLocationID: nil)
        )
        let zebra = try repository.createLocation(
            AppLocationCreationDraft(name: "zebra bin", homeID: home.id, parentLocationID: parent.id)
        )
        let apple = try repository.createLocation(
            AppLocationCreationDraft(name: "Apple crate", homeID: home.id, parentLocationID: parent.id)
        )

        let listed = try repository.listLocations().first { $0.id == parent.id }
        #expect(listed?.childLocationIDs == [apple.id, zebra.id])
        #expect(try repository.location(id: parent.id)?.childLocationIDs == [apple.id, zebra.id])
    }

    @Test("AppStore.refresh survives duplicated, cyclic and id-less rows")
    @MainActor
    func appStoreRefreshSurvivesDamagedStores() throws {
        let repository = try makeRepository()
        let privateStore = try #require(repository.persistenceController.privatePersistentStore())
        let sharedStore = try #require(repository.persistenceController.sharedPersistentStore())
        let homeID = UUID()
        let privateHome = insertHome(id: homeID, name: "Home", into: privateStore, repository: repository)
        let sharedHome = insertHome(id: homeID, name: "Home", into: sharedStore, repository: repository)
        insertHome(id: nil, name: "Broken", into: privateStore, repository: repository)
        let locationID = UUID()
        let location = insertLocation(id: locationID, name: "Shelf", home: privateHome, into: privateStore, repository: repository)
        insertLocation(id: locationID, name: "Shelf", home: sharedHome, into: sharedStore, repository: repository)
        let child = insertLocation(
            id: UUID(), name: "Box", home: privateHome, parent: location, into: privateStore, repository: repository
        )
        location.setValue(child, forKey: "parentLocation")
        insertItem(title: "Tape", location: child, into: privateStore, repository: repository)
        try context(repository).save()

        let appStore = AppStore(repository: repository)
        appStore.refresh()

        #expect(appStore.homes.map(\.id) == [homeID])
        #expect(Set(appStore.locations.map(\.id)).count == appStore.locations.count)
        #expect(appStore.items.map(\.title) == ["Tape"])
    }

    @Test("Listing homes resolves sharing state with one batched lookup")
    @MainActor
    func listHomesBatchesShareLookup() throws {
        let shareService = CountingSharingService()
        let repository = try makeRepository(shareService: shareService)
        _ = try repository.createHome(name: "A")
        _ = try repository.createHome(name: "B")
        _ = try repository.createHome(name: "C")
        shareService.reset()

        let homes = try repository.listHomes()

        #expect(homes.count == 3)
        #expect(shareService.snapshotCalls == 1)
        #expect(shareService.lastRequestCount == 3)
        #expect(shareService.perHomeCalls == 0)
    }
}

private final class CountingSharingService: HomeSharingServiceProtocol {
    private(set) var snapshotCalls = 0
    private(set) var lastRequestCount = 0
    private(set) var perHomeCalls = 0

    func reset() {
        snapshotCalls = 0
        lastRequestCount = 0
        perHomeCalls = 0
    }

    func sharingSnapshots(for requests: [HomeShareLookupRequest]) -> [UUID: HomeSharingSnapshot] {
        snapshotCalls += 1
        lastRequestCount = requests.count
        return [:]
    }

    func shareHome(_ home: AppHome) async throws -> CKShare { throw HomeSharingServiceError.shareCreationFailed }
    func shareURL(for home: AppHome) async throws -> URL { throw HomeSharingServiceError.shareLinkUnavailable }
    func fetchShare(for home: AppHome) -> CKShare? { perHomeCalls += 1; return nil }
    func permission(for home: AppHome) -> SharePermission { perHomeCalls += 1; return SharePermission(role: .owner) }
    func canEdit(_ home: AppHome) -> Bool { true }
    func isShared(_ home: AppHome) -> Bool { perHomeCalls += 1; return false }
    func leaveSharedHome(_ home: AppHome) async throws {}
    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws {}
    func participants(for home: AppHome) -> [CKShare.Participant] { perHomeCalls += 1; return [] }
    func shareForController(
        _ home: AppHome,
        completion: @escaping (CKShare?, CKContainer?, Error?) -> Void
    ) {
        completion(nil, nil, HomeSharingServiceError.shareCreationFailed)
    }
}
