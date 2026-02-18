import CloudKit
import CoreData
import Foundation

protocol HomeSharingServiceProtocol {
    func shareHome(_ home: Home) throws -> CKShare
    func fetchShare(for home: Home) -> CKShare?
    func canEdit(_ home: Home) -> Bool
    func isShared(_ home: Home) -> Bool
    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws
    func participants(for home: Home) -> [CKShare.Participant]
}

// Phase 1 should make PersistenceController conform to this.
protocol CloudKitSharingPersistenceControlling: AnyObject {
    var persistentContainer: NSPersistentCloudKitContainer { get }
    func privatePersistentStore() -> NSPersistentStore?
    func sharedPersistentStore() -> NSPersistentStore?
}

enum HomeSharingServiceError: Error, Equatable {
    case homeAlreadyShared
    case unsupportedHomeModel
    case shareCreationFailed
    case missingSharedPersistentStore
}

struct SharePermission: Equatable {
    enum Role: Equatable {
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

extension HomeSharingServiceProtocol {
    func permission(for home: Home) -> SharePermission {
        guard let share = fetchShare(for: home),
              let participant = share.currentUserParticipant else {
            return SharePermission(role: .owner)
        }

        if participant.role == .owner {
            return SharePermission(role: .owner)
        }

        if participant.permission == .readWrite {
            return SharePermission(role: .readWriteParticipant)
        }

        return SharePermission(role: .readOnlyParticipant)
    }

    func canCreateLocations(in home: Home) -> Bool {
        permission(for: home).canCreateLocations
    }

    func canDeleteLocations(in home: Home) -> Bool {
        permission(for: home).canDeleteLocations
    }

    func canAddItems(in home: Home) -> Bool {
        permission(for: home).canAddItems
    }

    func canEditItems(in home: Home) -> Bool {
        permission(for: home).canEditItems
    }

    func canDeleteItems(in home: Home) -> Bool {
        permission(for: home).canDeleteItems
    }

    func isOwnedByCurrentUser(_ home: Home) -> Bool {
        permission(for: home).role == .owner
    }

    func isSharedWithCurrentUser(_ home: Home) -> Bool {
        isShared(home) && !isOwnedByCurrentUser(home)
    }
}

final class HomeSharingService: HomeSharingServiceProtocol {
    private let persistenceController: any CloudKitSharingPersistenceControlling
    let ckContainer: CKContainer

    init(
        persistenceController: any CloudKitSharingPersistenceControlling,
        ckContainer: CKContainer = CKContainer(identifier: CloudKitSyncSettings.containerIdentifier)
    ) {
        self.persistenceController = persistenceController
        self.ckContainer = ckContainer
    }

    func shareHome(_ home: Home) throws -> CKShare {
        guard fetchShare(for: home) == nil else {
            throw HomeSharingServiceError.homeAlreadyShared
        }

        guard let managedObject = managedObject(for: home) else {
            throw HomeSharingServiceError.unsupportedHomeModel
        }

        let share = try createShare(for: managedObject)
        if home.name.isEmpty == false {
            share[CKShare.SystemFieldKey.title] = home.name as CKRecordValue
        }

        if let privatePersistentStore = persistenceController.privatePersistentStore() {
            try persistUpdatedShare(share, in: privatePersistentStore)
        }

        return share
    }

    func fetchShare(for home: Home) -> CKShare? {
        guard let objectID = managedObjectID(for: home) else {
            return nil
        }

        do {
            let shares = try persistenceController.persistentContainer.fetchShares(
                matching: [objectID]
            )
            return shares[objectID]
        } catch {
            DebugLogger.warning("Failed to fetch share for home \(home.id): \(error)")
            return nil
        }
    }

    func canEdit(_ home: Home) -> Bool {
        guard let share = fetchShare(for: home) else {
            return true
        }

        guard let currentParticipant = share.currentUserParticipant else {
            return true
        }

        if currentParticipant.role == .owner {
            return true
        }

        return currentParticipant.permission == .readWrite
    }

    func isShared(_ home: Home) -> Bool {
        fetchShare(for: home) != nil
    }

    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws {
        guard let sharedPersistentStore = persistenceController.sharedPersistentStore() else {
            throw HomeSharingServiceError.missingSharedPersistentStore
        }

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            persistenceController.persistentContainer.acceptShareInvitations(
                from: [metadata],
                into: sharedPersistentStore
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func participants(for home: Home) -> [CKShare.Participant] {
        fetchShare(for: home)?.participants ?? []
    }

    private func managedObject(for home: Home) -> NSManagedObject? {
        (home as AnyObject) as? NSManagedObject
    }

    private func managedObjectID(for home: Home) -> NSManagedObjectID? {
        managedObject(for: home)?.objectID
    }

    private func createShare(for managedObject: NSManagedObject) throws -> CKShare {
        var createdShare: CKShare?
        var shareError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        persistenceController.persistentContainer.share(
            [managedObject],
            to: nil
        ) { _, share, _, error in
            createdShare = share
            shareError = error
            semaphore.signal()
        }

        semaphore.wait()

        if let shareError {
            throw shareError
        }

        guard let createdShare else {
            throw HomeSharingServiceError.shareCreationFailed
        }

        return createdShare
    }

    private func persistUpdatedShare(
        _ share: CKShare,
        in persistentStore: NSPersistentStore
    ) throws {
        var persistenceError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        persistenceController.persistentContainer.persistUpdatedShare(
            share,
            in: persistentStore
        ) { _, error in
            persistenceError = error
            semaphore.signal()
        }

        semaphore.wait()

        if let persistenceError {
            throw persistenceError
        }
    }
}

extension PersistenceController: CloudKitSharingPersistenceControlling {}
