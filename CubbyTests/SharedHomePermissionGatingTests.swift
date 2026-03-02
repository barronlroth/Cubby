import CloudKit
import Foundation
import Testing
@testable import Cubby

struct SharedHomePermissionGatingTests {
    @Test
    func test_addItem_blockedForReadOnlyParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = Home(name: "Shared Home")
        service.setRole(.readOnlyParticipant, for: home)

        #expect(service.canAddItems(in: home) == false)
    }

    @Test
    func test_editItem_blockedForReadOnlyParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = Home(name: "Shared Home")
        service.setRole(.readOnlyParticipant, for: home)

        #expect(service.canEditItems(in: home) == false)
    }

    @Test
    func test_deleteItem_blockedForReadOnlyParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = Home(name: "Shared Home")
        service.setRole(.readOnlyParticipant, for: home)

        #expect(service.canDeleteItems(in: home) == false)
    }

    @Test
    func test_addLocation_blockedForReadOnlyParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = Home(name: "Shared Home")
        service.setRole(.readOnlyParticipant, for: home)

        #expect(service.canCreateLocations(in: home) == false)
    }

    @Test
    func test_deleteLocation_blockedForReadOnlyParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = Home(name: "Shared Home")
        service.setRole(.readOnlyParticipant, for: home)

        #expect(service.canDeleteLocations(in: home) == false)
    }

    @Test
    func test_addItem_allowedForReadWriteParticipant() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = Home(name: "Shared Home")
        service.setRole(.readWriteParticipant, for: home)

        #expect(service.canAddItems(in: home))
    }

    @Test
    func test_addItem_allowedForOwner() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = Home(name: "Owned Home")
        service.setRole(.owner, for: home)

        #expect(service.canAddItems(in: home))
    }

    @Test
    func test_editItem_allowedForOwner() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = Home(name: "Owned Home")
        service.setRole(.owner, for: home)

        #expect(service.canEditItems(in: home))
    }

    @Test
    func test_deleteItem_allowedForOwner() {
        let service = PermissionGatingHomeSharingServiceMock()
        let home = Home(name: "Owned Home")
        service.setRole(.owner, for: home)

        #expect(service.canDeleteItems(in: home))
    }
}

private final class PermissionGatingHomeSharingServiceMock: HomeSharingServiceProtocol {
    private var rolesByHomeID: [UUID: SharePermission.Role] = [:]

    func shareHome(_ home: Home) throws -> CKShare {
        let share = CKShare(rootRecord: CKRecord(recordType: "Home"))
        share[CKShare.SystemFieldKey.title] = home.name as CKRecordValue
        return share
    }

    func fetchShare(for home: Home) -> CKShare? {
        _ = home
        return nil
    }

    func canEdit(_ home: Home) -> Bool {
        let role = rolesByHomeID[home.id] ?? .owner
        return SharePermission(role: role).canMutate
    }

    func isShared(_ home: Home) -> Bool {
        rolesByHomeID[home.id] != nil
    }

    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws {
        _ = metadata
    }

    func participants(for home: Home) -> [CKShare.Participant] {
        _ = home
        return []
    }

    func canCreateLocations(in home: Home) -> Bool {
        canEdit(home)
    }

    func canDeleteLocations(in home: Home) -> Bool {
        canEdit(home)
    }

    func canAddItems(in home: Home) -> Bool {
        canEdit(home)
    }

    func canEditItems(in home: Home) -> Bool {
        canEdit(home)
    }

    func canDeleteItems(in home: Home) -> Bool {
        canEdit(home)
    }

    func setRole(_ role: SharePermission.Role, for home: Home) {
        rolesByHomeID[home.id] = role
    }
}
