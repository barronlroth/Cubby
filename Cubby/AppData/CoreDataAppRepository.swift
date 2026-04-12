import CloudKit
import CoreData
import Foundation

enum AppRepositoryError: LocalizedError, Equatable {
    case homeNotFound
    case locationNotFound
    case itemNotFound
    case invalidLocationHome
    case duplicateLocationName
    case maximumNestingDepthReached
    case invalidMoveTarget

    var errorDescription: String? {
        switch self {
        case .homeNotFound:
            "The selected home could not be found."
        case .locationNotFound:
            "The selected location could not be found."
        case .itemNotFound:
            "The selected item could not be found."
        case .invalidLocationHome:
            "The selected location does not belong to this home."
        case .duplicateLocationName:
            "A location with this name already exists at this level."
        case .maximumNestingDepthReached:
            "Maximum nesting depth reached. Cannot create location here."
        case .invalidMoveTarget:
            "The item can’t be moved to that location."
        }
    }
}

@MainActor
final class CoreDataAppRepository: HomeRepository, LocationRepository, ItemRepository, ShareRepository, FeatureGateDataSource {
    let persistenceController: PersistenceController
    private let shareService: (any HomeSharingServiceProtocol)?

    init(
        persistenceController: PersistenceController,
        shareService: (any HomeSharingServiceProtocol)?
    ) {
        self.persistenceController = persistenceController
        self.shareService = shareService
    }

    var ckContainer: CKContainer {
        if let service = shareService as? HomeSharingService {
            return service.ckContainer
        }
        return CKContainer(identifier: CloudKitSyncSettings.containerIdentifier)
    }

    func listHomes() throws -> [AppHome] {
        let homes = try fetchHomes()
        return homes
            .map(makeHome)
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func home(id: UUID) throws -> AppHome? {
        try fetchHomeObject(id: id).map(makeHome)
    }

    func createHome(name: String) throws -> AppHome {
        guard let privateStore = persistenceController.privatePersistentStore() else {
            throw AppRepositoryError.homeNotFound
        }

        let context = viewContext
        let home = NSEntityDescription.insertNewObject(forEntityName: "CDHome", into: context)
        context.assign(home, to: privateStore)
        let homeID = UUID()
        let now = Date()
        home.setValue(homeID, forKey: "id")
        home.setValue(name, forKey: "name")
        home.setValue(now, forKey: "createdAt")
        home.setValue(now, forKey: "modifiedAt")

        let unsorted = NSEntityDescription.insertNewObject(forEntityName: "CDStorageLocation", into: context)
        context.assign(unsorted, to: privateStore)
        unsorted.setValue(UUID(), forKey: "id")
        unsorted.setValue("Unsorted", forKey: "name")
        unsorted.setValue(Int16(0), forKey: "depth")
        unsorted.setValue(now, forKey: "createdAt")
        unsorted.setValue(now, forKey: "modifiedAt")
        unsorted.setValue(home, forKey: "home")
        unsorted.setValue(nil, forKey: "parentLocation")

        try saveContext()
        guard let created = try self.home(id: homeID) else {
            throw AppRepositoryError.homeNotFound
        }
        return created
    }

    func listLocations() throws -> [AppStorageLocation] {
        let homesByID = try fetchHomesByID()
        let locations = try fetchLocations()
        return locations
            .compactMap { makeLocation($0, homesByID: homesByID, allLocations: locations) }
            .sorted { lhs, rhs in
                if lhs.homeName == rhs.homeName {
                    return lhs.fullPath.localizedCaseInsensitiveCompare(rhs.fullPath) == .orderedAscending
                }
                return lhs.homeName.localizedCaseInsensitiveCompare(rhs.homeName) == .orderedAscending
            }
    }

    func location(id: UUID) throws -> AppStorageLocation? {
        guard let location = try fetchLocationObject(id: id) else {
            return nil
        }
        let homesByID = try fetchHomesByID()
        let locations = try fetchLocations()
        return makeLocation(location, homesByID: homesByID, allLocations: locations)
    }

    func createLocation(_ draft: AppLocationCreationDraft) throws -> AppStorageLocation {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let home = try fetchHomeObject(id: draft.homeID) else {
            throw AppRepositoryError.homeNotFound
        }

        let parentLocation = try draft.parentLocationID.map(fetchRequiredLocationObject)
        if let parentLocation,
           parentLocation.uuidValue(forKey: "home.id") != draft.homeID {
            throw AppRepositoryError.invalidLocationHome
        }

        let parentDepth = parentLocation?.intValue(forKey: "depth") ?? -1
        if parentDepth >= StorageLocation.maxNestingDepth - 1 {
            throw AppRepositoryError.maximumNestingDepthReached
        }

        if try locationNameExists(trimmedName, homeID: draft.homeID, parentLocationID: draft.parentLocationID) {
            throw AppRepositoryError.duplicateLocationName
        }

        guard let store = persistentStoreForLocationGraph(
            home: home,
            parentLocation: parentLocation
        ) else {
            throw AppRepositoryError.locationNotFound
        }

        let now = Date()
        let location = NSEntityDescription.insertNewObject(forEntityName: "CDStorageLocation", into: viewContext)
        viewContext.assign(location, to: store)
        let locationID = UUID()
        location.setValue(locationID, forKey: "id")
        location.setValue(trimmedName, forKey: "name")
        location.setValue(Int16(parentDepth + 1), forKey: "depth")
        location.setValue(now, forKey: "createdAt")
        location.setValue(now, forKey: "modifiedAt")
        location.setValue(home, forKey: "home")
        location.setValue(parentLocation, forKey: "parentLocation")

        try saveContext()
        guard let created = try self.location(id: locationID) else {
            throw AppRepositoryError.locationNotFound
        }
        return created
    }

    func deleteLocation(id: UUID) throws {
        let childCount = try fetchCount(
            entityName: "CDStorageLocation",
            predicate: NSPredicate(format: "parentLocation.id == %@", id as CVarArg)
        )
        guard childCount == 0 else {
            throw StorageLocationDeletionError.hasChildren(childCount)
        }

        let itemCount = try fetchCount(
            entityName: "CDInventoryItem",
            predicate: NSPredicate(format: "storageLocation.id == %@", id as CVarArg)
        )
        guard itemCount == 0 else {
            throw StorageLocationDeletionError.hasItems(itemCount)
        }

        guard let location = try fetchLocationObject(id: id) else {
            throw StorageLocationDeletionError.locationNotFound
        }

        viewContext.delete(location)
        do {
            try saveContext()
        } catch {
            throw StorageLocationDeletionError.saveFailed
        }
    }

    func listItems() throws -> [AppInventoryItem] {
        let homesByID = try fetchHomesByID()
        let locationsByID = try fetchLocationsByID()
        let items = try fetchItems()
        return items
            .compactMap { makeItem($0, homesByID: homesByID, locationsByID: locationsByID) }
            .sorted { lhs, rhs in
                lhs.modifiedAt > rhs.modifiedAt
            }
    }

    func item(id: UUID) throws -> AppInventoryItem? {
        guard let item = try fetchItemObject(id: id) else {
            return nil
        }
        return makeItem(
            item,
            homesByID: try fetchHomesByID(),
            locationsByID: try fetchLocationsByID()
        )
    }

    func createItem(_ draft: AppItemDraft) throws -> AppInventoryItem {
        guard let location = try fetchLocationObject(id: draft.storageLocationID) else {
            throw AppRepositoryError.locationNotFound
        }
        guard let store = location.objectID.persistentStore else {
            throw AppRepositoryError.locationNotFound
        }

        let item = NSEntityDescription.insertNewObject(forEntityName: "CDInventoryItem", into: viewContext)
        viewContext.assign(item, to: store)
        let now = Date()
        item.setValue(draft.id, forKey: "id")
        item.setValue(draft.title, forKey: "title")
        item.setValue(draft.itemDescription, forKey: "itemDescription")
        item.setValue(draft.photoFileName, forKey: "photoFileName")
        item.setValue(draft.emoji, forKey: "emoji")
        item.setValue(draft.isPendingAiEmoji, forKey: "isPendingAiEmoji")
        item.setValue(now, forKey: "createdAt")
        item.setValue(now, forKey: "modifiedAt")
        item.setValue(Array(draft.tags).sorted(), forKey: "tags")
        item.setValue(location, forKey: "storageLocation")

        try saveContext()
        guard let created = try self.item(id: draft.id) else {
            throw AppRepositoryError.itemNotFound
        }
        return created
    }

    func updateItem(id: UUID, draft: AppItemUpdateDraft) throws -> AppInventoryItem {
        guard let item = try fetchItemObject(id: id) else {
            throw AppRepositoryError.itemNotFound
        }
        item.setValue(draft.title, forKey: "title")
        item.setValue(draft.itemDescription, forKey: "itemDescription")
        item.setValue(Array(draft.tags).sorted(), forKey: "tags")
        if draft.removePhoto {
            item.setValue(nil, forKey: "photoFileName")
        } else {
            item.setValue(draft.photoFileName, forKey: "photoFileName")
        }
        item.setValue(Date(), forKey: "modifiedAt")

        try saveContext()
        guard let updated = try self.item(id: id) else {
            throw AppRepositoryError.itemNotFound
        }
        return updated
    }

    func moveItem(id: UUID, to locationID: UUID) throws -> AppInventoryItem {
        guard let item = try fetchItemObject(id: id) else {
            throw AppRepositoryError.itemNotFound
        }
        guard let location = try fetchLocationObject(id: locationID) else {
            throw AppRepositoryError.locationNotFound
        }
        guard canMoveItem(item, to: location) else {
            throw AppRepositoryError.invalidMoveTarget
        }

        item.setValue(location, forKey: "storageLocation")
        item.setValue(Date(), forKey: "modifiedAt")

        try saveContext()
        guard let moved = try self.item(id: id) else {
            throw AppRepositoryError.itemNotFound
        }
        return moved
    }

    func deleteItem(id: UUID) throws {
        guard let item = try fetchItemObject(id: id) else {
            throw AppRepositoryError.itemNotFound
        }
        viewContext.delete(item)
        try saveContext()
    }

    func restoreDeletedItem(_ snapshot: AppDeletedItemSnapshot) throws -> AppInventoryItem {
        guard let location = try fetchLocationObject(id: snapshot.storageLocationID) else {
            throw AppRepositoryError.locationNotFound
        }
        guard let store = location.objectID.persistentStore else {
            throw AppRepositoryError.locationNotFound
        }

        let item = NSEntityDescription.insertNewObject(forEntityName: "CDInventoryItem", into: viewContext)
        viewContext.assign(item, to: store)
        item.setValue(snapshot.itemID, forKey: "id")
        item.setValue(snapshot.title, forKey: "title")
        item.setValue(snapshot.itemDescription, forKey: "itemDescription")
        item.setValue(snapshot.photoFileName, forKey: "photoFileName")
        item.setValue(snapshot.emoji, forKey: "emoji")
        item.setValue(snapshot.isPendingAiEmoji, forKey: "isPendingAiEmoji")
        item.setValue(snapshot.createdAt, forKey: "createdAt")
        item.setValue(Date(), forKey: "modifiedAt")
        item.setValue(Array(snapshot.tags).sorted(), forKey: "tags")
        item.setValue(location, forKey: "storageLocation")

        try saveContext()
        guard let restored = try self.item(id: snapshot.itemID) else {
            throw AppRepositoryError.itemNotFound
        }
        return restored
    }

    func shareForController(
        homeID: UUID,
        completion: @escaping (CKShare?, CKContainer?, Error?) -> Void
    ) {
        guard let shareService else {
            completion(nil, nil, HomeSharingServiceError.shareCreationFailed)
            return
        }
        guard let home = makeHomeReference(id: homeID) else {
            completion(nil, nil, AppRepositoryError.homeNotFound)
            return
        }
        shareService.shareForController(home, completion: completion)
    }

    func share(for homeID: UUID) async throws -> CKShare {
        guard let shareService else {
            throw HomeSharingServiceError.shareCreationFailed
        }
        guard let home = makeHomeReference(id: homeID) else {
            throw AppRepositoryError.homeNotFound
        }
        return try await shareService.shareHome(home)
    }

    func existingShare(for homeID: UUID) -> CKShare? {
        guard let shareService,
              let home = makeHomeReference(id: homeID) else {
            return nil
        }
        return shareService.fetchShare(for: home)
    }

    func permission(for homeID: UUID) -> SharePermission {
        guard let shareService,
              let home = makeHomeReference(id: homeID) else {
            return SharePermission(role: .owner)
        }
        return shareService.permission(for: home)
    }

    func participants(for homeID: UUID) -> [CKShare.Participant] {
        guard let shareService,
              let home = makeHomeReference(id: homeID) else {
            return []
        }
        return shareService.participants(for: home)
    }

    func isShared(homeID: UUID) -> Bool {
        guard let shareService,
              let home = makeHomeReference(id: homeID) else {
            return false
        }
        return shareService.isShared(home)
    }

    func ownerHomeCount() throws -> Int {
        try fetchCount(
            entityName: "CDHome",
            predicate: nil,
            store: persistenceController.privatePersistentStore()
        )
    }

    func ownerItemCount(for homeID: UUID) throws -> Int {
        try fetchCount(
            entityName: "CDInventoryItem",
            predicate: NSPredicate(format: "storageLocation.home.id == %@", homeID as CVarArg),
            store: persistenceController.privatePersistentStore()
        )
    }
}

private extension CoreDataAppRepository {
    var viewContext: NSManagedObjectContext {
        persistenceController.persistentContainer.viewContext
    }

    func saveContext() throws {
        if viewContext.hasChanges {
            try viewContext.save()
        }
    }

    func fetchHomes() throws -> [NSManagedObject] {
        try fetchObjects(entityName: "CDHome", predicate: nil)
    }

    func fetchHomesByID() throws -> [UUID: NSManagedObject] {
        Dictionary(uniqueKeysWithValues: try fetchHomes().compactMap { home in
            guard let id = home.value(forKey: "id") as? UUID else { return nil }
            return (id, home)
        })
    }

    func fetchLocations() throws -> [NSManagedObject] {
        try fetchObjects(entityName: "CDStorageLocation", predicate: nil)
    }

    func fetchLocationsByID() throws -> [UUID: NSManagedObject] {
        Dictionary(uniqueKeysWithValues: try fetchLocations().compactMap { location in
            guard let id = location.value(forKey: "id") as? UUID else { return nil }
            return (id, location)
        })
    }

    func fetchItems() throws -> [NSManagedObject] {
        try fetchObjects(entityName: "CDInventoryItem", predicate: nil)
    }

    func fetchHomeObject(id: UUID) throws -> NSManagedObject? {
        try fetchObjects(
            entityName: "CDHome",
            predicate: NSPredicate(format: "id == %@", id as CVarArg),
            fetchLimit: 1
        ).first
    }

    func fetchLocationObject(id: UUID) throws -> NSManagedObject? {
        try fetchObjects(
            entityName: "CDStorageLocation",
            predicate: NSPredicate(format: "id == %@", id as CVarArg),
            fetchLimit: 1
        ).first
    }

    func fetchRequiredLocationObject(id: UUID) throws -> NSManagedObject {
        guard let location = try fetchLocationObject(id: id) else {
            throw AppRepositoryError.locationNotFound
        }
        return location
    }

    func fetchItemObject(id: UUID) throws -> NSManagedObject? {
        try fetchObjects(
            entityName: "CDInventoryItem",
            predicate: NSPredicate(format: "id == %@", id as CVarArg),
            fetchLimit: 1
        ).first
    }

    func fetchObjects(
        entityName: String,
        predicate: NSPredicate?,
        fetchLimit: Int = 0
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = predicate
        request.fetchLimit = fetchLimit
        return try viewContext.fetch(request)
    }

    func fetchCount(
        entityName: String,
        predicate: NSPredicate?,
        store: NSPersistentStore? = nil
    ) throws -> Int {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        request.predicate = predicate
        request.resultType = .countResultType
        if let store {
            request.affectedStores = [store]
        }
        return try viewContext.count(for: request)
    }

    func locationNameExists(_ name: String, homeID: UUID, parentLocationID: UUID?) throws -> Bool {
        let predicate: NSPredicate
        if let parentLocationID {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "home.id == %@", homeID as CVarArg),
                NSPredicate(format: "parentLocation.id == %@", parentLocationID as CVarArg),
                NSPredicate(format: "name =[c] %@", name)
            ])
        } else {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "home.id == %@", homeID as CVarArg),
                NSPredicate(format: "parentLocation == nil"),
                NSPredicate(format: "name =[c] %@", name)
            ])
        }

        return try fetchCount(entityName: "CDStorageLocation", predicate: predicate) > 0
    }

    func persistentStoreForLocationGraph(
        home: NSManagedObject,
        parentLocation: NSManagedObject?
    ) -> NSPersistentStore? {
        if let parentStore = parentLocation?.objectID.persistentStore {
            return parentStore
        }
        if let homeStore = home.objectID.persistentStore {
            return homeStore
        }
        return persistenceController.privatePersistentStore()
    }

    func canMoveItem(_ item: NSManagedObject, to location: NSManagedObject) -> Bool {
        guard let currentLocation = item.value(forKey: "storageLocation") as? NSManagedObject,
              let currentStore = currentLocation.objectID.persistentStore,
              let targetStore = location.objectID.persistentStore,
              currentStore == targetStore else {
            return false
        }

        let currentHomeID = currentLocation.uuidValue(forKey: "home.id")
        let targetHomeID = location.uuidValue(forKey: "home.id")
        return currentHomeID == targetHomeID
    }

    func makeHome(_ homeObject: NSManagedObject) -> AppHome {
        let baseHome = makeHomeReference(homeObject)
        let permission = shareService?.permission(for: baseHome) ?? SharePermission(role: .owner)
        let isShared = shareService?.isShared(baseHome) ?? false
        let isOwnedByCurrentUser = permission.role == .owner
        return AppHome(
            id: baseHome.id,
            name: baseHome.name,
            createdAt: baseHome.createdAt,
            modifiedAt: baseHome.modifiedAt,
            isShared: isShared,
            isOwnedByCurrentUser: isOwnedByCurrentUser,
            permission: permission,
            participantSummary: participantSummary(for: baseHome.id)
        )
    }

    func makeLocation(
        _ locationObject: NSManagedObject,
        homesByID: [UUID: NSManagedObject],
        allLocations: [NSManagedObject]
    ) -> AppStorageLocation? {
        guard let id = locationObject.value(forKey: "id") as? UUID,
              let homeObject = locationObject.value(forKey: "home") as? NSManagedObject,
              let homeID = homeObject.value(forKey: "id") as? UUID,
              let persistedHome = homesByID[homeID] else {
            return nil
        }

        let childIDs = allLocations.compactMap { location -> UUID? in
            guard let parent = location.value(forKey: "parentLocation") as? NSManagedObject,
                  let parentID = parent.value(forKey: "id") as? UUID,
                  parentID == id else {
                return nil
            }
            return location.value(forKey: "id") as? UUID
        }

        let itemCount = (locationObject.value(forKey: "items") as? Set<NSManagedObject>)?.count ?? 0
        let parentLocationID = (locationObject.value(forKey: "parentLocation") as? NSManagedObject)?
            .value(forKey: "id") as? UUID

        return AppStorageLocation(
            id: id,
            name: locationObject.stringValue(forKey: "name"),
            createdAt: locationObject.dateValue(forKey: "createdAt"),
            modifiedAt: locationObject.dateValue(forKey: "modifiedAt"),
            depth: locationObject.intValue(forKey: "depth"),
            homeID: homeID,
            homeName: persistedHome.stringValue(forKey: "name"),
            parentLocationID: parentLocationID,
            fullPath: fullPath(for: locationObject),
            childLocationIDs: childIDs.sorted { lhs, rhs in
                let lhsName = allLocations.first(where: { ($0.value(forKey: "id") as? UUID) == lhs })?.stringValue(forKey: "name") ?? ""
                let rhsName = allLocations.first(where: { ($0.value(forKey: "id") as? UUID) == rhs })?.stringValue(forKey: "name") ?? ""
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            },
            itemCount: itemCount
        )
    }

    func makeItem(
        _ itemObject: NSManagedObject,
        homesByID: [UUID: NSManagedObject],
        locationsByID: [UUID: NSManagedObject]
    ) -> AppInventoryItem? {
        guard let id = itemObject.value(forKey: "id") as? UUID else {
            return nil
        }

        let locationObject = itemObject.value(forKey: "storageLocation") as? NSManagedObject
        let locationID = locationObject?.value(forKey: "id") as? UUID
        let homeObject = locationObject?.value(forKey: "home") as? NSManagedObject
        let homeID = homeObject?.value(forKey: "id") as? UUID

        let resolvedLocation = locationID.flatMap { locationsByID[$0] }
        let resolvedHome = homeID.flatMap { homesByID[$0] }

        let tags = (itemObject.value(forKey: "tags") as? [String] ?? []).sorted()
        return AppInventoryItem(
            id: id,
            title: itemObject.stringValue(forKey: "title"),
            itemDescription: itemObject.value(forKey: "itemDescription") as? String,
            photoFileName: itemObject.value(forKey: "photoFileName") as? String,
            emoji: itemObject.value(forKey: "emoji") as? String,
            isPendingAiEmoji: itemObject.boolValue(forKey: "isPendingAiEmoji"),
            createdAt: itemObject.dateValue(forKey: "createdAt"),
            modifiedAt: itemObject.dateValue(forKey: "modifiedAt"),
            tags: tags,
            homeID: homeID,
            homeName: resolvedHome?.stringValue(forKey: "name"),
            storageLocationID: locationID,
            storageLocationName: resolvedLocation?.stringValue(forKey: "name"),
            storageLocationPath: resolvedLocation.map(fullPath(for:))
        )
    }

    func fullPath(for locationObject: NSManagedObject) -> String {
        var names: [String] = []
        var current: NSManagedObject? = locationObject
        while let currentObject = current {
            names.insert(currentObject.stringValue(forKey: "name"), at: 0)
            current = currentObject.value(forKey: "parentLocation") as? NSManagedObject
        }
        return names.joined(separator: " > ")
    }

    func participantSummary(for homeID: UUID) -> String? {
        let participants = participants(for: homeID)
        guard participants.isEmpty == false else { return nil }

        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let names = participants
            .compactMap { $0.userIdentity.nameComponents }
            .map(formatter.string(from:))
            .filter { $0.isEmpty == false }

        if names.isEmpty {
            return "Shared with \(participants.count) people"
        }

        if names.count <= 2 {
            return "Shared with " + names.joined(separator: ", ")
        }

        return "Shared with \(names.prefix(2).joined(separator: ", ")) +\(names.count - 2)"
    }

    func makeHomeReference(id: UUID) -> AppHome? {
        guard let homeObject = try? fetchHomeObject(id: id) else {
            return nil
        }
        return makeHomeReference(homeObject)
    }

    func makeHomeReference(_ homeObject: NSManagedObject) -> AppHome {
        AppHome(
            id: homeObject.value(forKey: "id") as? UUID ?? UUID(),
            name: homeObject.stringValue(forKey: "name"),
            createdAt: homeObject.dateValue(forKey: "createdAt"),
            modifiedAt: homeObject.dateValue(forKey: "modifiedAt"),
            isShared: false,
            isOwnedByCurrentUser: true,
            permission: SharePermission(role: .owner),
            participantSummary: nil
        )
    }
}

private extension NSManagedObject {
    func stringValue(forKey key: String) -> String {
        value(forKey: key) as? String ?? ""
    }

    func dateValue(forKey key: String) -> Date {
        value(forKey: key) as? Date ?? .distantPast
    }

    func intValue(forKey key: String) -> Int {
        if let number = value(forKey: key) as? NSNumber {
            return number.intValue
        }
        return 0
    }

    func boolValue(forKey key: String) -> Bool {
        if let value = value(forKey: key) as? Bool {
            return value
        }
        if let number = value(forKey: key) as? NSNumber {
            return number.boolValue
        }
        return false
    }

    func uuidValue(forKey key: String) -> UUID? {
        value(forKeyPath: key) as? UUID
    }
}
