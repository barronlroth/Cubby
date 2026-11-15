import CloudKit
import CoreData
import Foundation

// MARK: - Share lookup

/// The result of looking up a home's share. A failed lookup is not proof that a
/// home is unshared, so it is kept distinct from `.notShared`.
enum HomeShareLookup {
    case notShared
    case shared(CKShare)
    case lookupFailed(Error)

    var share: CKShare? {
        if case .shared(let share) = self { return share }
        return nil
    }

    var isLookupFailure: Bool {
        if case .lookupFailed = self { return true }
        return false
    }
}

protocol HomeSharingServiceProtocol {
    /// The CloudKit container that owns Cubby's shares, for ShareLink and
    /// UICloudSharingController.
    var cloudKitContainer: CKContainer { get }

    func shareLookup(for home: AppHome) -> HomeShareLookup
    /// Returns the home's existing share, or validates the home graph and
    /// creates one. Fails without creating anything when the lookup fails.
    func prepareShare(for home: AppHome) async throws -> CKShare
    func permission(for home: AppHome) -> SharePermission
    func canEdit(_ home: AppHome) -> Bool
    func isShared(_ home: AppHome) -> Bool
    /// Participant leave: purges the share's zone from the shared store, which
    /// removes the participant and the local copy.
    func leaveSharedHome(_ home: AppHome) async throws
    /// Owner delete of a shared home: purges the share zone from the private
    /// store, which removes the share for every participant.
    func deleteSharedHome(_ home: AppHome) async throws
    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws
    func participants(for home: AppHome) -> [CKShare.Participant]
    /// Resolves sharing state for many homes at once so a refresh does not
    /// issue several share lookups per home.
    func sharingSnapshots(for requests: [HomeShareLookupRequest]) -> [UUID: HomeSharingSnapshot]
}

/// A home plus the managed object that backs it, used for batched share lookup.
struct HomeShareLookupRequest {
    let home: AppHome
    let objectID: NSManagedObjectID
}

/// Sharing state derived from one share lookup.
struct HomeSharingSnapshot {
    let isShared: Bool
    let permission: SharePermission
    let participants: [CKShare.Participant]
    let lookupFailed: Bool

    static let unshared = HomeSharingSnapshot(lookup: .notShared)

    init(
        isShared: Bool,
        permission: SharePermission,
        participants: [CKShare.Participant],
        lookupFailed: Bool = false
    ) {
        self.isShared = isShared
        self.permission = permission
        self.participants = participants
        self.lookupFailed = lookupFailed
    }

    init(lookup: HomeShareLookup) {
        self.init(
            isShared: lookup.share != nil,
            permission: SharePermission(lookup: lookup),
            participants: lookup.share?.participants ?? [],
            lookupFailed: lookup.isLookupFailure
        )
    }
}

enum HomeSharingServiceError: Error, Equatable {
    case homeAlreadyShared
    case shareNotFound
    case cannotLeaveOwnedShare
    case unsupportedHomeModel
    case shareCreationFailed
    case shareLookupFailed
    case missingSharedPersistentStore
}

extension HomeSharingServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .homeAlreadyShared:
            return "This home is already shared."
        case .shareNotFound:
            return "Cubby could not find the shared home."
        case .cannotLeaveOwnedShare:
            return "Owners can delete a shared home, but they cannot leave it."
        case .unsupportedHomeModel:
            return "This home could not be prepared for sharing."
        case .shareCreationFailed:
            return "Cubby could not create the share invite."
        case .shareLookupFailed:
            return "Cubby couldn't check this home's sharing status."
        case .missingSharedPersistentStore:
            return "Cubby could not access the shared iCloud store."
        }
    }
}

/// A problem found in a home's object graph before it is shared (#86). Sharing
/// such a graph can fail in CloudKit or pull other homes' records into the zone.
enum HomeSharePreflightError: Error, Equatable {
    case missingID(entity: String)
    case duplicateID(entity: String, id: UUID)
    case objectNotInPrivateStore(entity: String, id: UUID)
    case belongsToAnotherHome(entity: String, id: UUID)
    case parentCycle(locationID: UUID)
}

extension HomeSharePreflightError: LocalizedError {
    var errorDescription: String? {
        "This home has data that iCloud can't share yet. Try again after Cubby finishes syncing."
    }
}

// MARK: - Container seam

/// The `NSPersistentCloudKitContainer` calls the sharing service makes, behind a
/// protocol so tests can drive the real service with a fake.
protocol CloudKitSharingContaining: AnyObject {
    func share(_ objects: [NSManagedObject], to share: CKShare?) async throws -> CKShare
    func fetchShares(matching objectIDs: [NSManagedObjectID]) throws -> [NSManagedObjectID: CKShare]
    func acceptShareInvitations(from metadata: [CKShare.Metadata], into store: NSPersistentStore) async throws
    func purgeObjectsAndRecordsInZone(with zoneID: CKRecordZone.ID, in store: NSPersistentStore?) async throws
    func persistUpdatedShare(_ share: CKShare, in store: NSPersistentStore) async throws -> CKShare
    func recordID(for objectID: NSManagedObjectID) -> CKRecord.ID?
}

final class PersistentCloudKitSharingContainer: CloudKitSharingContaining {
    private let container: NSPersistentCloudKitContainer

    init(container: NSPersistentCloudKitContainer) {
        self.container = container
    }

    func share(_ objects: [NSManagedObject], to share: CKShare?) async throws -> CKShare {
        try await withCheckedThrowingContinuation { continuation in
            container.share(objects, to: share) { _, share, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let share {
                    continuation.resume(returning: share)
                } else {
                    continuation.resume(throwing: HomeSharingServiceError.shareCreationFailed)
                }
            }
        }
    }

    func fetchShares(matching objectIDs: [NSManagedObjectID]) throws -> [NSManagedObjectID: CKShare] {
        guard objectIDs.isEmpty == false else { return [:] }
        return try container.fetchShares(matching: objectIDs)
    }

    func acceptShareInvitations(from metadata: [CKShare.Metadata], into store: NSPersistentStore) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.acceptShareInvitations(from: metadata, into: store) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func purgeObjectsAndRecordsInZone(with zoneID: CKRecordZone.ID, in store: NSPersistentStore?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.purgeObjectsAndRecordsInZone(with: zoneID, in: store) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func recordID(for objectID: NSManagedObjectID) -> CKRecord.ID? {
        container.recordID(for: objectID)
    }

    func persistUpdatedShare(_ share: CKShare, in store: NSPersistentStore) async throws -> CKShare {
        try await withCheckedThrowingContinuation { continuation in
            container.persistUpdatedShare(share, in: store) { share, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let share {
                    continuation.resume(returning: share)
                } else {
                    continuation.resume(throwing: HomeSharingServiceError.shareCreationFailed)
                }
            }
        }
    }
}

enum DebugMockSharingMode: Equatable, CustomStringConvertible {
    case disabled
    case owner
    case readWriteParticipant
    case readOnlyParticipant
    case mixed

    static let launchArgument = "MOCK_SHARED_HOMES"
    static let ownerLaunchArgument = "MOCK_SHARED_HOMES_OWNER"
    static let readWriteLaunchArgument = "MOCK_SHARED_HOMES_READ_WRITE"
    static let readOnlyLaunchArgument = "MOCK_SHARED_HOMES_READ_ONLY"
    static let mixedLaunchArgument = "MOCK_SHARED_HOMES_MIXED"
    static let environmentKey = "MOCK_SHARED_HOMES"

    var isEnabled: Bool {
        self != .disabled
    }

    var description: String {
        switch self {
        case .disabled: "disabled"
        case .owner: "owner"
        case .readWriteParticipant: "readWriteParticipant"
        case .readOnlyParticipant: "readOnlyParticipant"
        case .mixed: "mixed"
        }
    }

    static func resolve(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DebugMockSharingMode {
        if arguments.contains(ownerLaunchArgument) { return .owner }
        if arguments.contains(readWriteLaunchArgument) { return .readWriteParticipant }
        if arguments.contains(readOnlyLaunchArgument) { return .readOnlyParticipant }
        if arguments.contains(mixedLaunchArgument) { return .mixed }
        if arguments.contains(launchArgument) { return .mixed }

        if let rawValue = environment[environmentKey] {
            return parse(rawValue) ?? .disabled
        }

        return .disabled
    }

    private static func parse(_ rawValue: String) -> DebugMockSharingMode? {
        switch rawValue.lowercased() {
        case "0", "false", "off", "no", "n", "disabled", "none":
            .disabled
        case "owner":
            .owner
        case "readwrite", "read_write", "rw", "participant", "participant_rw":
            .readWriteParticipant
        case "readonly", "read_only", "ro", "participant_ro":
            .readOnlyParticipant
        case "1", "true", "on", "yes", "y", "enabled", "mixed":
            .mixed
        default:
            nil
        }
    }
}

struct SharePermission: Equatable, Hashable {
    enum Role: Equatable, Hashable {
        case owner
        case readWriteParticipant
        case readOnlyParticipant
    }

    let role: Role

    var canMutate: Bool {
        role != .readOnlyParticipant
    }

    var canCreateLocations: Bool {
        canMutate
    }

    var canDeleteLocations: Bool {
        canMutate
    }

    var canAddItems: Bool {
        canMutate
    }

    var canEditItems: Bool {
        canMutate
    }

    var canDeleteItems: Bool {
        canMutate
    }

    var canViewItems: Bool {
        true
    }
}

extension SharePermission {
    init(share: CKShare) {
        guard let participant = share.currentUserParticipant,
              participant.role != .owner else {
            self.init(role: .owner)
            return
        }

        if participant.permission == .readWrite {
            self.init(role: .readWriteParticipant)
        } else {
            self.init(role: .readOnlyParticipant)
        }
    }

    /// A failed lookup never grants owner or edit rights.
    init(lookup: HomeShareLookup) {
        switch lookup {
        case .notShared:
            self.init(role: .owner)
        case .shared(let share):
            self.init(share: share)
        case .lookupFailed:
            self.init(role: .readOnlyParticipant)
        }
    }
}

extension HomeSharingServiceProtocol {
    func deleteSharedHome(_ home: AppHome) async throws {
        _ = home
    }

    func fetchShare(for home: AppHome) -> CKShare? {
        shareLookup(for: home).share
    }

    func permission(for home: AppHome) -> SharePermission {
        SharePermission(lookup: shareLookup(for: home))
    }

    func canEdit(_ home: AppHome) -> Bool {
        permission(for: home).canMutate
    }

    func isShared(_ home: AppHome) -> Bool {
        shareLookup(for: home).share != nil
    }

    func participants(for home: AppHome) -> [CKShare.Participant] {
        shareLookup(for: home).share?.participants ?? []
    }

    func sharingSnapshots(for requests: [HomeShareLookupRequest]) -> [UUID: HomeSharingSnapshot] {
        var snapshots: [UUID: HomeSharingSnapshot] = [:]
        for request in requests {
            snapshots[request.home.id] = HomeSharingSnapshot(
                isShared: isShared(request.home),
                permission: permission(for: request.home),
                participants: participants(for: request.home)
            )
        }
        return snapshots
    }

    func canCreateLocations(in home: AppHome) -> Bool {
        permission(for: home).canCreateLocations
    }

    func canDeleteLocations(in home: AppHome) -> Bool {
        permission(for: home).canDeleteLocations
    }

    func canAddItems(in home: AppHome) -> Bool {
        permission(for: home).canAddItems
    }

    func canEditItems(in home: AppHome) -> Bool {
        permission(for: home).canEditItems
    }

    func canDeleteItems(in home: AppHome) -> Bool {
        permission(for: home).canDeleteItems
    }

    func isOwnedByCurrentUser(_ home: AppHome) -> Bool {
        permission(for: home).role == .owner
    }

    func isSharedWithCurrentUser(_ home: AppHome) -> Bool {
        isShared(home) && !isOwnedByCurrentUser(home)
    }
}

final class DebugMockHomeSharingService: HomeSharingServiceProtocol {
    private let mode: DebugMockSharingMode

    init(mode: DebugMockSharingMode) {
        self.mode = mode
    }

    var cloudKitContainer: CKContainer {
        CKContainer(identifier: CloudKitSyncSettings.containerIdentifier)
    }

    func shareLookup(for home: AppHome) -> HomeShareLookup {
        mode.isEnabled ? .shared(makeShare(for: home)) : .notShared
    }

    func prepareShare(for home: AppHome) async throws -> CKShare {
        makeShare(for: home)
    }

    func permission(for home: AppHome) -> SharePermission {
        SharePermission(role: role(for: home))
    }

    func isShared(_ home: AppHome) -> Bool {
        _ = home
        return mode.isEnabled
    }

    func leaveSharedHome(_ home: AppHome) async throws {
        guard mode.isEnabled else {
            throw HomeSharingServiceError.shareNotFound
        }
        guard role(for: home) != .owner else {
            throw HomeSharingServiceError.cannotLeaveOwnedShare
        }
    }

    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws {
        _ = metadata
    }

    func participants(for home: AppHome) -> [CKShare.Participant] {
        _ = home
        return []
    }
}

private extension DebugMockHomeSharingService {
    func role(for home: AppHome) -> SharePermission.Role {
        switch mode {
        case .disabled, .owner:
            return .owner
        case .readWriteParticipant:
            return .readWriteParticipant
        case .readOnlyParticipant:
            return .readOnlyParticipant
        case .mixed:
            // Makes seeded "Main Home" behave as owner and the rest as collaborators.
            if home.name.localizedCaseInsensitiveContains("main") {
                return .owner
            }
            return .readWriteParticipant
        }
    }

    func makeShare(for home: AppHome) -> CKShare {
        let rootRecord = CKRecord(recordType: "CDHome")
        rootRecord["id"] = home.id.uuidString as CKRecordValue
        let share = CKShare(rootRecord: rootRecord)
        if home.name.isEmpty == false {
            share[CKShare.SystemFieldKey.title] = home.name as CKRecordValue
        }
        return share
    }
}

// Phase 1 should make PersistenceController conform to this.
protocol CloudKitSharingPersistenceControlling: AnyObject {
    var persistentContainer: NSPersistentCloudKitContainer { get }
    func privatePersistentStore() -> NSPersistentStore?
    func sharedPersistentStore() -> NSPersistentStore?
}

final class HomeSharingService: HomeSharingServiceProtocol {
    private let persistenceController: any CloudKitSharingPersistenceControlling
    private let container: any CloudKitSharingContaining
    let ckContainer: CKContainer

    init(
        persistenceController: any CloudKitSharingPersistenceControlling,
        container: (any CloudKitSharingContaining)? = nil,
        ckContainer: CKContainer = CKContainer(identifier: CloudKitSyncSettings.containerIdentifier)
    ) {
        self.persistenceController = persistenceController
        self.container = container
            ?? PersistentCloudKitSharingContainer(container: persistenceController.persistentContainer)
        self.ckContainer = ckContainer
    }

    var cloudKitContainer: CKContainer { ckContainer }

    func shareLookup(for home: AppHome) -> HomeShareLookup {
        guard let objectID = managedObject(for: home)?.objectID else {
            return .notShared
        }
        return lookup(objectID: objectID, homeID: home.id)
    }

    func sharingSnapshots(for requests: [HomeShareLookupRequest]) -> [UUID: HomeSharingSnapshot] {
        guard requests.isEmpty == false else { return [:] }

        let lookups: (NSManagedObjectID) -> HomeShareLookup
        do {
            let shares = try container.fetchShares(matching: requests.map(\.objectID))
            lookups = { shares[$0].map(HomeShareLookup.shared) ?? .notShared }
        } catch {
            DebugLogger.warning("Failed to fetch shares for \(requests.count) homes: \(error)")
            lookups = { _ in .lookupFailed(error) }
        }

        var snapshots: [UUID: HomeSharingSnapshot] = [:]
        for request in requests {
            snapshots[request.home.id] = HomeSharingSnapshot(lookup: lookups(request.objectID))
        }
        return snapshots
    }

    func prepareShare(for home: AppHome) async throws -> CKShare {
        guard let homeObject = managedObject(for: home) else {
            throw HomeSharingServiceError.unsupportedHomeModel
        }

        switch lookup(objectID: homeObject.objectID, homeID: home.id) {
        case .shared(let share):
            return share
        case .lookupFailed(let error):
            DebugLogger.error("Blocking share creation for \(home.id): share lookup failed: \(error)")
            throw HomeSharingServiceError.shareLookupFailed
        case .notShared:
            break
        }

        try validateShareableGraph(homeObject)

        DebugLogger.info("Creating share for home \(home.id)")
        let share = try await container.share([homeObject], to: nil)
        if home.name.isEmpty == false {
            share[CKShare.SystemFieldKey.title] = home.name as CKRecordValue
        }
        DebugLogger.info("Created share \(share.recordID.recordName) for home \(home.id)")
        return share
    }

    func leaveSharedHome(_ home: AppHome) async throws {
        let share: CKShare
        switch shareLookup(for: home) {
        case .shared(let found):
            share = found
        case .notShared:
            throw HomeSharingServiceError.shareNotFound
        case .lookupFailed:
            throw HomeSharingServiceError.shareLookupFailed
        }

        guard let currentParticipant = share.currentUserParticipant else {
            throw HomeSharingServiceError.shareNotFound
        }
        guard currentParticipant.role != .owner else {
            throw HomeSharingServiceError.cannotLeaveOwnedShare
        }
        guard let sharedStore = persistenceController.sharedPersistentStore() else {
            throw HomeSharingServiceError.missingSharedPersistentStore
        }

        let zoneID = share.recordID.zoneID
        DebugLogger.info("Leaving shared home \(home.id): purging zone \(zoneID.zoneName) from shared store")
        try await container.purgeObjectsAndRecordsInZone(with: zoneID, in: sharedStore)
    }

    func deleteSharedHome(_ home: AppHome) async throws {
        let share: CKShare
        switch shareLookup(for: home) {
        case .shared(let found):
            share = found
        case .notShared:
            throw HomeSharingServiceError.shareNotFound
        case .lookupFailed:
            throw HomeSharingServiceError.shareLookupFailed
        }
        guard SharePermission(share: share).role == .owner else {
            throw HomeSharingServiceError.cannotLeaveOwnedShare
        }
        guard let privateStore = persistenceController.privatePersistentStore() else {
            throw HomeSharingServiceError.shareCreationFailed
        }

        let zoneID = share.recordID.zoneID
        DebugLogger.info("Deleting shared home \(home.id): purging zone \(zoneID.zoneName) from private store")
        try await container.purgeObjectsAndRecordsInZone(with: zoneID, in: privateStore)
    }

    /// Finishes a leave recorded by older builds, which only hid the home: purges
    /// the zone holding a shared-store home. No-op for private-store homes.
    func purgeSharedStoreZone(forHomeID homeID: UUID) async throws {
        guard let sharedStore = persistenceController.sharedPersistentStore(),
              let object = managedObject(homeID: homeID),
              object.objectID.persistentStore == sharedStore else {
            return
        }
        let zoneID = lookup(objectID: object.objectID, homeID: homeID).share?.recordID.zoneID
            ?? container.recordID(for: object.objectID)?.zoneID
        guard let zoneID else {
            DebugLogger.warning("No CloudKit zone found for previously left home \(homeID)")
            return
        }
        DebugLogger.info("Completing earlier leave of \(homeID): purging zone \(zoneID.zoneName)")
        try await container.purgeObjectsAndRecordsInZone(with: zoneID, in: sharedStore)
    }

    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws {
        guard let sharedPersistentStore = persistenceController.sharedPersistentStore() else {
            throw HomeSharingServiceError.missingSharedPersistentStore
        }
        try await container.acceptShareInvitations(from: [metadata], into: sharedPersistentStore)
    }

    /// Checks the graph `container.share` would copy into the share zone (#86):
    /// ids present and unique, every location and item belongs to this home, no
    /// parent cycles, and every object lives in the private store.
    func validateShareableGraph(_ homeObject: NSManagedObject) throws {
        let privateStore = persistenceController.privatePersistentStore()
        func inPrivateStore(_ object: NSManagedObject) -> Bool {
            privateStore != nil && object.objectID.persistentStore == privateStore
        }
        func fail(_ error: HomeSharePreflightError, _ object: NSManagedObject) throws -> Never {
            DebugLogger.error(
                "Share preflight failed: \(error) at \(object.objectID.uriRepresentation())"
            )
            throw error
        }

        guard let homeID = homeObject.value(forKey: "id") as? UUID else {
            try fail(.missingID(entity: "CDHome"), homeObject)
        }
        guard inPrivateStore(homeObject) else {
            try fail(.objectNotInPrivateStore(entity: "CDHome", id: homeID), homeObject)
        }

        let locations = homeObject.value(forKey: "storageLocations") as? Set<NSManagedObject> ?? []
        var locationIDs = Set<UUID>()
        var itemIDs = Set<UUID>()

        for location in locations.sorted(by: { $0.objectID.uriRepresentation().absoluteString < $1.objectID.uriRepresentation().absoluteString }) {
            guard let locationID = location.value(forKey: "id") as? UUID else {
                try fail(.missingID(entity: "CDStorageLocation"), location)
            }
            guard locationIDs.insert(locationID).inserted else {
                try fail(.duplicateID(entity: "CDStorageLocation", id: locationID), location)
            }
            guard inPrivateStore(location) else {
                try fail(.objectNotInPrivateStore(entity: "CDStorageLocation", id: locationID), location)
            }

            var visited: Set<NSManagedObjectID> = [location.objectID]
            var parent = location.value(forKey: "parentLocation") as? NSManagedObject
            while let current = parent {
                guard (current.value(forKey: "home") as? NSManagedObject)?.objectID == homeObject.objectID else {
                    try fail(.belongsToAnotherHome(entity: "CDStorageLocation", id: locationID), location)
                }
                guard visited.insert(current.objectID).inserted else {
                    try fail(.parentCycle(locationID: locationID), location)
                }
                parent = current.value(forKey: "parentLocation") as? NSManagedObject
            }

            let children = location.value(forKey: "childLocations") as? Set<NSManagedObject> ?? []
            for child in children where (child.value(forKey: "home") as? NSManagedObject)?.objectID != homeObject.objectID {
                let childID = child.value(forKey: "id") as? UUID ?? locationID
                try fail(.belongsToAnotherHome(entity: "CDStorageLocation", id: childID), child)
            }

            let items = location.value(forKey: "items") as? Set<NSManagedObject> ?? []
            for item in items {
                guard let itemID = item.value(forKey: "id") as? UUID else {
                    try fail(.missingID(entity: "CDInventoryItem"), item)
                }
                guard itemIDs.insert(itemID).inserted else {
                    try fail(.duplicateID(entity: "CDInventoryItem", id: itemID), item)
                }
                guard inPrivateStore(item) else {
                    try fail(.objectNotInPrivateStore(entity: "CDInventoryItem", id: itemID), item)
                }
            }
        }
    }

    private func lookup(objectID: NSManagedObjectID, homeID: UUID) -> HomeShareLookup {
        do {
            let shares = try container.fetchShares(matching: [objectID])
            return shares[objectID].map(HomeShareLookup.shared) ?? .notShared
        } catch {
            DebugLogger.warning("Failed to fetch share for home \(homeID): \(error)")
            return .lookupFailed(error)
        }
    }

    /// Fetches the home, preferring the private-store row when duplicates exist.
    private func managedObject(for home: AppHome) -> NSManagedObject? {
        managedObject(homeID: home.id)
    }

    private func managedObject(homeID: UUID) -> NSManagedObject? {
        let context = persistenceController.persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDHome")
        request.predicate = NSPredicate(format: "id == %@", homeID as CVarArg)
        guard let objects = try? context.fetch(request), objects.isEmpty == false else {
            return nil
        }
        let privateStore = persistenceController.privatePersistentStore()
        return objects.first { $0.objectID.persistentStore == privateStore } ?? objects.first
    }
}

extension PersistenceController: CloudKitSharingPersistenceControlling {}
