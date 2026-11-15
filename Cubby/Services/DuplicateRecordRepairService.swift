import CloudKit
import CoreData
import Foundation

/// Merges `CDHome` and `CDStorageLocation` rows that share an `id` inside one
/// persistent store. Older builds could create such duplicates (a CloudKit-backed
/// legacy SwiftData store re-imported and re-migrated records). The repository
/// already tolerates them; this pass removes them so they stop syncing.
///
/// Rows are only merged with rows in the same store. Children (locations and
/// items) are re-pointed to the survivor before the loser is deleted, so the
/// home's cascade delete never removes inventory.
final class DuplicateRecordRepairService: @unchecked Sendable {
    struct Report: Equatable, CustomStringConvertible {
        var mergedHomes = 0
        var mergedLocations = 0
        var movedLocations = 0
        var movedItems = 0
        var skippedReadOnlyGroups = 0

        var didMerge: Bool { mergedHomes + mergedLocations > 0 }

        var description: String {
            "merged homes \(mergedHomes), locations \(mergedLocations); "
                + "moved locations \(movedLocations), items \(movedItems); "
                + "skipped read-only groups \(skippedReadOnlyGroups)"
        }
    }

    private let persistenceController: PersistenceController
    private let canModifySharedHome: (NSManagedObjectID) -> Bool

    /// - Parameter canModifySharedHome: whether the current user may edit the
    ///   shared-store home with this object ID. Defaults to a share lookup; a
    ///   failed lookup counts as read-only.
    init(
        persistenceController: PersistenceController,
        canModifySharedHome: ((NSManagedObjectID) -> Bool)? = nil
    ) {
        self.persistenceController = persistenceController
        self.canModifySharedHome = canModifySharedHome ?? { objectID in
            do {
                guard let share = try persistenceController.fetchShares(matching: [objectID])[objectID],
                      let participant = share.currentUserParticipant else {
                    return false
                }
                return participant.role == .owner || participant.permission == .readWrite
            } catch {
                DebugLogger.warning("Duplicate repair could not read share for \(objectID): \(error)")
                return false
            }
        }
    }

    /// Runs synchronously on a private background context.
    @discardableResult
    func repair() throws -> Report {
        let context = persistenceController.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil

        var report = Report()
        var thrownError: Error?
        context.performAndWait {
            do {
                for store in [
                    persistenceController.privatePersistentStore(),
                    persistenceController.sharedPersistentStore()
                ].compactMap({ $0 }) {
                    let isShared = store == persistenceController.sharedPersistentStore()
                    try mergeHomes(in: store, isShared: isShared, context: context, report: &report)
                    try mergeLocations(in: store, isShared: isShared, context: context, report: &report)
                }
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                context.rollback()
                thrownError = error
            }
        }
        if let thrownError {
            throw thrownError
        }
        if report.didMerge || report.skippedReadOnlyGroups > 0 {
            DebugLogger.warning("Duplicate record repair: \(report)")
        }
        return report
    }
}

private extension DuplicateRecordRepairService {
    func duplicateGroups(
        entityName: String,
        in store: NSPersistentStore,
        context: NSManagedObjectContext
    ) throws -> [(id: UUID, objects: [NSManagedObject])] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.affectedStores = [store]
        var groups: [UUID: [NSManagedObject]] = [:]
        for object in try context.fetch(request) {
            guard let id = object.value(forKey: "id") as? UUID else { continue }
            groups[id, default: []].append(object)
        }
        return groups
            .filter { $0.value.count > 1 }
            .map { (id: $0.key, objects: $0.value) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    /// Newest `modifiedAt` wins; object-ID order breaks ties deterministically.
    func survivor(of objects: [NSManagedObject]) -> NSManagedObject {
        objects.max { lhs, rhs in
            let lhsDate = lhs.value(forKey: "modifiedAt") as? Date ?? .distantPast
            let rhsDate = rhs.value(forKey: "modifiedAt") as? Date ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.objectID.uriRepresentation().absoluteString
                > rhs.objectID.uriRepresentation().absoluteString
        }!
    }

    func mergeHomes(
        in store: NSPersistentStore,
        isShared: Bool,
        context: NSManagedObjectContext,
        report: inout Report
    ) throws {
        for group in try duplicateGroups(entityName: "CDHome", in: store, context: context) {
            let keeper = survivor(of: group.objects)
            if isShared, canModifySharedHome(keeper.objectID) == false {
                report.skippedReadOnlyGroups += 1
                continue
            }
            for loser in group.objects where loser !== keeper {
                let locations = loser.value(forKey: "storageLocations") as? Set<NSManagedObject> ?? []
                for location in locations {
                    location.setValue(keeper, forKey: "home")
                    report.movedLocations += 1
                }
                DebugLogger.warning(
                    "Merging duplicate CDHome \(group.id): keeping \(keeper.objectID.uriRepresentation()), "
                        + "deleting \(loser.objectID.uriRepresentation()) (\(isShared ? "shared" : "private"))"
                )
                context.delete(loser)
                report.mergedHomes += 1
            }
        }
    }

    func mergeLocations(
        in store: NSPersistentStore,
        isShared: Bool,
        context: NSManagedObjectContext,
        report: inout Report
    ) throws {
        for group in try duplicateGroups(entityName: "CDStorageLocation", in: store, context: context) {
            let keeper = survivor(of: group.objects)
            if isShared {
                let homeObjectID = (keeper.value(forKey: "home") as? NSManagedObject)?.objectID
                guard let homeObjectID, canModifySharedHome(homeObjectID) else {
                    report.skippedReadOnlyGroups += 1
                    continue
                }
            }
            let losers = group.objects.filter { $0 !== keeper }
            let loserIDs = Set(losers.map(\.objectID))

            // A survivor whose parent is one of its own duplicates would point at
            // itself after the merge; lift it to that duplicate's parent instead.
            var parent = keeper.value(forKey: "parentLocation") as? NSManagedObject
            var visited = Set<NSManagedObjectID>()
            while let candidate = parent, loserIDs.contains(candidate.objectID) || candidate === keeper {
                guard visited.insert(candidate.objectID).inserted else {
                    parent = nil
                    break
                }
                parent = candidate.value(forKey: "parentLocation") as? NSManagedObject
            }
            keeper.setValue(parent, forKey: "parentLocation")

            for loser in losers {
                if keeper.value(forKey: "home") == nil, let home = loser.value(forKey: "home") {
                    keeper.setValue(home, forKey: "home")
                }
                let children = loser.value(forKey: "childLocations") as? Set<NSManagedObject> ?? []
                for child in children where child !== keeper && !loserIDs.contains(child.objectID) {
                    child.setValue(keeper, forKey: "parentLocation")
                    report.movedLocations += 1
                }
                let items = loser.value(forKey: "items") as? Set<NSManagedObject> ?? []
                for item in items {
                    item.setValue(keeper, forKey: "storageLocation")
                    report.movedItems += 1
                }
                DebugLogger.warning(
                    "Merging duplicate CDStorageLocation \(group.id): keeping \(keeper.objectID.uriRepresentation()), "
                        + "deleting \(loser.objectID.uriRepresentation()) (\(isShared ? "shared" : "private"))"
                )
                context.delete(loser)
                report.mergedLocations += 1
            }
        }
    }
}

/// Runs `DuplicateRecordRepairService` once per launch, after the first
/// successful CloudKit import, on a background queue so launch is never blocked.
final class DuplicateRecordRepairCoordinator: @unchecked Sendable {
    nonisolated(unsafe) private static var current: DuplicateRecordRepairCoordinator?

    private let service: DuplicateRecordRepairService
    private let container: NSPersistentCloudKitContainer
    private let notificationCenter: NotificationCenter
    private let queue = DispatchQueue(label: "com.barronroth.Cubby.duplicate-repair", qos: .utility)
    private let lock = NSLock()
    private var observer: NSObjectProtocol?
    private var hasRun = false

    init(
        persistenceController: PersistenceController,
        service: DuplicateRecordRepairService? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.service = service ?? DuplicateRecordRepairService(persistenceController: persistenceController)
        self.container = persistenceController.persistentContainer
        self.notificationCenter = notificationCenter
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }

    /// Starts the app-wide coordinator; later calls are ignored.
    static func startIfNeeded(persistenceController: PersistenceController) {
        guard current == nil else { return }
        let coordinator = DuplicateRecordRepairCoordinator(persistenceController: persistenceController)
        coordinator.start()
        current = coordinator
    }

    func start() {
        guard observer == nil else { return }
        observer = notificationCenter.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: nil
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event,
                event.type == .import,
                event.endDate != nil,
                event.succeeded else {
                return
            }
            self?.scheduleRepair()
        }
    }

    func scheduleRepair() {
        lock.lock()
        guard hasRun == false else {
            lock.unlock()
            return
        }
        hasRun = true
        lock.unlock()

        queue.async { [service, notificationCenter] in
            do {
                let report = try service.repair()
                if report.didMerge {
                    DispatchQueue.main.async {
                        notificationCenter.post(
                            name: RemoteChangeHandler.didMergeRemoteChangesNotification,
                            object: nil
                        )
                    }
                }
            } catch {
                DebugLogger.error("Duplicate record repair failed: \(error)")
            }
        }
    }
}
