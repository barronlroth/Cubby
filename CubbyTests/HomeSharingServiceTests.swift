import CloudKit
import Foundation
import Testing
@testable import Cubby

struct HomeSharingServiceTests {
    @Test
    func test_shareHome_createsShareForPrivateHome() async throws {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Primary Home")

        let share = try await service.shareHome(home)
        let fetchedShare = service.fetchShare(for: home)

        #expect(share.recordID.recordName == fetchedShare?.recordID.recordName)
        #expect(service.isShared(home))
    }

    @Test
    func test_shareHome_failsForAlreadySharedHome() async throws {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Already Shared")
        _ = try await service.shareHome(home)

        do {
            _ = try await service.shareHome(home)
            Issue.record("Expected already-shared error")
        } catch let error as HomeSharingServiceError {
            #expect(error == .homeAlreadyShared)
        }
    }

    @Test
    func test_fetchShare_returnsNilForUnsharedHome() {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Private Home")

        #expect(service.fetchShare(for: home) == nil)
    }

    @Test
    func test_fetchShare_returnsShareForSharedHome() async throws {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Shared Home")
        let shared = try await service.shareHome(home)

        let fetched = service.fetchShare(for: home)

        #expect(fetched?.recordID.recordName == shared.recordID.recordName)
    }

    @Test
    func test_canEdit_returnsTrueForOwnedHome() {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Owned Home")

        #expect(service.canEdit(home))
    }

    @Test
    func test_canEdit_returnsTrueForReadWriteParticipant() {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Read Write")
        service.setRole(.readWriteParticipant, for: home)

        #expect(service.canEdit(home))
    }

    @Test
    func test_canEdit_returnsFalseForReadOnlyParticipant() {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Read Only")
        service.setRole(.readOnlyParticipant, for: home)

        #expect(service.canEdit(home) == false)
    }

    @Test
    func test_isShared_returnsFalseForPrivateHome() {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Private Home")

        #expect(service.isShared(home) == false)
    }

    @Test
    func test_isShared_returnsTrueForSharedHome() async throws {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Shared Home")
        _ = try await service.shareHome(home)

        #expect(service.isShared(home))
    }

    @Test
    func test_acceptShareInvitation_addsHomeToSharedStore() async throws {
        let service = MockHomeSharingService()
        let incomingHome = makeHome(name: "Incoming Shared Home")
        service.homeToAddOnAccept = incomingHome

        try await service.acceptShareInvitation(
            from: makeShareMetadataPlaceholder()
        )

        #expect(service.sharedHomeIDs.contains(incomingHome.id))
        #expect(service.isShared(incomingHome))
    }

    @Test
    func test_shareForController_createsShareForUnsharedHome() async {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Link Home")

        var createdShare: CKShare?
        var createdContainer: CKContainer?
        service.shareForController(home) { share, container, error in
            #expect(error == nil)
            createdShare = share
            createdContainer = container
        }

        #expect(createdShare != nil)
        #expect(createdContainer != nil)
        #expect(service.isShared(home))
    }

    @Test
    func test_shareForController_reusesExistingShare() async throws {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Existing Link Home")
        let shared = try await service.shareHome(home)

        var reusedShare: CKShare?
        service.shareForController(home) { share, _, error in
            #expect(error == nil)
            reusedShare = share
        }

        #expect(reusedShare?.recordID.recordName == shared.recordID.recordName)
    }

    @Test
    func test_shareURL_returnsStableURLForSharedHome() async throws {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Native Share Home")

        _ = try await service.shareHome(home)
        let firstURL = try await service.shareURL(for: home)
        let secondURL = try await service.shareURL(for: home)

        #expect(firstURL == secondURL)
    }

    @Test
    func test_leaveSharedHome_removesCollaboratorShare() async throws {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Collaborator Home")
        _ = try await service.shareHome(home)
        service.setRole(.readWriteParticipant, for: home)

        try await service.leaveSharedHome(home)

        #expect(service.leftHomeIDs == [home.id])
        #expect(service.isShared(home) == false)
    }

    @Test
    func test_leaveSharedHome_rejectsOwnerShare() async throws {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Owner Home")
        _ = try await service.shareHome(home)

        await #expect(throws: HomeSharingServiceError.cannotLeaveOwnedShare) {
            try await service.leaveSharedHome(home)
        }
    }

    @Test
    func test_leaveSharedHome_rejectsMissingShare() async {
        let service = MockHomeSharingService()
        let home = makeHome(name: "Private Home")

        await #expect(throws: HomeSharingServiceError.shareNotFound) {
            try await service.leaveSharedHome(home)
        }
    }

    private func makeShareMetadataPlaceholder() -> CKShare.Metadata {
        unsafeBitCast(NSObject(), to: CKShare.Metadata.self)
    }

    private func makeHome(name: String) -> AppHome {
        AppHome(
            id: UUID(),
            name: name,
            createdAt: Date(),
            modifiedAt: Date(),
            isShared: false,
            isOwnedByCurrentUser: true,
            permission: SharePermission(role: .owner),
            participantSummary: nil
        )
    }
}

private final class MockHomeSharingService: HomeSharingServiceProtocol {
    var homeToAddOnAccept: AppHome?
    private(set) var leftHomeIDs: [UUID] = []
    private(set) var sharedHomeIDs = Set<UUID>()
    private var sharesByHomeID: [UUID: CKShare] = [:]
    private var rolesByHomeID: [UUID: SharePermission.Role] = [:]

    func shareHome(_ home: AppHome) async throws -> CKShare {
        if sharesByHomeID[home.id] != nil {
            throw HomeSharingServiceError.homeAlreadyShared
        }

        let share = CKShare(rootRecord: CKRecord(recordType: "Home"))
        share[CKShare.SystemFieldKey.title] = home.name as CKRecordValue
        sharesByHomeID[home.id] = share
        rolesByHomeID[home.id] = .owner
        sharedHomeIDs.insert(home.id)
        return share
    }

    func fetchShare(for home: AppHome) -> CKShare? {
        sharesByHomeID[home.id]
    }

    func shareURL(for home: AppHome) async throws -> URL {
        if sharesByHomeID[home.id] == nil {
            _ = try await shareHome(home)
        }
        return URL(string: "https://icloud.com/share/\(home.id.uuidString)")!
    }

    func canEdit(_ home: AppHome) -> Bool {
        guard let role = rolesByHomeID[home.id] else {
            return true
        }
        return SharePermission(role: role).canMutate
    }

    func isShared(_ home: AppHome) -> Bool {
        sharesByHomeID[home.id] != nil || sharedHomeIDs.contains(home.id)
    }

    func leaveSharedHome(_ home: AppHome) async throws {
        guard sharesByHomeID[home.id] != nil || sharedHomeIDs.contains(home.id) else {
            throw HomeSharingServiceError.shareNotFound
        }
        guard rolesByHomeID[home.id] != .owner else {
            throw HomeSharingServiceError.cannotLeaveOwnedShare
        }

        sharesByHomeID[home.id] = nil
        rolesByHomeID[home.id] = nil
        sharedHomeIDs.remove(home.id)
        leftHomeIDs.append(home.id)
    }

    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws {
        _ = metadata

        guard let homeToAddOnAccept else { return }
        sharedHomeIDs.insert(homeToAddOnAccept.id)
        let share = CKShare(rootRecord: CKRecord(recordType: "Home"))
        share[CKShare.SystemFieldKey.title] = homeToAddOnAccept.name as CKRecordValue
        sharesByHomeID[homeToAddOnAccept.id] = share
        rolesByHomeID[homeToAddOnAccept.id] = .readWriteParticipant
    }

    func participants(for home: AppHome) -> [CKShare.Participant] {
        _ = home
        return []
    }

    func shareForController(
        _ home: AppHome,
        completion: @escaping (CKShare?, CKContainer?, Error?) -> Void
    ) {
        let share: CKShare
        if let existingShare = sharesByHomeID[home.id] {
            share = existingShare
        } else {
            share = CKShare(rootRecord: CKRecord(recordType: "Home"))
            share[CKShare.SystemFieldKey.title] = home.name as CKRecordValue
            sharesByHomeID[home.id] = share
            rolesByHomeID[home.id] = .owner
            sharedHomeIDs.insert(home.id)
        }

        completion(share, CKContainer(identifier: CloudKitSyncSettings.containerIdentifier), nil)
    }

    func setRole(_ role: SharePermission.Role, for home: AppHome) {
        rolesByHomeID[home.id] = role
    }
}
