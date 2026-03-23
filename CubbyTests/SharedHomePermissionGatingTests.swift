import CloudKit
import Foundation
import Testing
@testable import Cubby

struct SharedHomePermissionGatingTests {
    @Test
    func test_addItem_blockedForReadOnlyParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = makeHome(name: "Shared Home")
        service.setRole(.readOnlyParticipant, for: home)

        #expect(service.canAddItems(in: home) == false)
    }

    @Test
    func test_editItem_blockedForReadOnlyParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = makeHome(name: "Shared Home")
        service.setRole(.readOnlyParticipant, for: home)

        #expect(service.canEditItems(in: home) == false)
    }

    @Test
    func test_deleteItem_blockedForReadOnlyParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = makeHome(name: "Shared Home")
        service.setRole(.readOnlyParticipant, for: home)

        #expect(service.canDeleteItems(in: home) == false)
    }

    @Test
    func test_addLocation_blockedForReadOnlyParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = makeHome(name: "Shared Home")
        service.setRole(.readOnlyParticipant, for: home)

        #expect(service.canCreateLocations(in: home) == false)
    }

    @Test
    func test_deleteLocation_blockedForReadOnlyParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = makeHome(name: "Shared Home")
        service.setRole(.readOnlyParticipant, for: home)

        #expect(service.canDeleteLocations(in: home) == false)
    }

    @Test
    func test_addItem_allowedForReadWriteParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = makeHome(name: "Shared Home")
        service.setRole(.readWriteParticipant, for: home)

        #expect(service.canAddItems(in: home))
    }

    @Test
    func test_addItem_allowedForOwner() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = makeHome(name: "Owned Home")
        service.setRole(.owner, for: home)

        #expect(service.canAddItems(in: home))
    }

    @Test
    func test_editItem_allowedForOwner() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = makeHome(name: "Owned Home")
        service.setRole(.owner, for: home)

        #expect(service.canEditItems(in: home))
    }

    @Test
    func test_deleteItem_allowedForOwner() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = makeHome(name: "Owned Home")
        service.setRole(.owner, for: home)

        #expect(service.canDeleteItems(in: home))
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

private final class PermissionGatingHomeSharingServiceMock: HomeSharingServiceProtocol {
    private var rolesByHomeID: [UUID: SharePermission.Role] = [:]

    func shareHome(_ home: AppHome) async throws -> CKShare {
        let share = CKShare(rootRecord: CKRecord(recordType: "Home"))
        share[CKShare.SystemFieldKey.title] = home.name as CKRecordValue
        return share
    }

    func fetchShare(for home: AppHome) -> CKShare? {
        _ = home
        return nil
    }

    func canEdit(_ home: AppHome) -> Bool {
        let role = rolesByHomeID[home.id] ?? .owner
        return SharePermission(role: role).canMutate
    }

    func isShared(_ home: AppHome) -> Bool {
        rolesByHomeID[home.id] != nil
    }

    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws {
        _ = metadata
    }

    func participants(for home: AppHome) -> [CKShare.Participant] {
        _ = home
        return []
    }

    func canCreateLocations(in home: AppHome) -> Bool {
        canEdit(home)
    }

    func canDeleteLocations(in home: AppHome) -> Bool {
        canEdit(home)
    }

    func canAddItems(in home: AppHome) -> Bool {
        canEdit(home)
    }

    func canEditItems(in home: AppHome) -> Bool {
        canEdit(home)
    }

    func canDeleteItems(in home: AppHome) -> Bool {
        canEdit(home)
    }

    func setRole(_ role: SharePermission.Role, for home: AppHome) {
        rolesByHomeID[home.id] = role
    }
}
