import Testing
@testable import Cubby

struct SharePermissionTests {
    @Test
    func test_owner_canCreateLocations() {
        let permission = SharePermission(role: .owner)
        #expect(permission.canCreateLocations)
    }

    @Test
    func test_owner_canDeleteLocations() {
        let permission = SharePermission(role: .owner)
        #expect(permission.canDeleteLocations)
    }

    @Test
    func test_owner_canAddItems() {
        let permission = SharePermission(role: .owner)
        #expect(permission.canAddItems)
    }

    @Test
    func test_readWriteParticipant_canAddItems() {
        let permission = SharePermission(role: .readWriteParticipant)
        #expect(permission.canAddItems)
    }

    @Test
    func test_readWriteParticipant_canEditItems() {
        let permission = SharePermission(role: .readWriteParticipant)
        #expect(permission.canEditItems)
    }

    @Test
    func test_readOnlyParticipant_cannotAddItems() {
        let permission = SharePermission(role: .readOnlyParticipant)
        #expect(permission.canAddItems == false)
    }

    @Test
    func test_readOnlyParticipant_cannotEditItems() {
        let permission = SharePermission(role: .readOnlyParticipant)
        #expect(permission.canEditItems == false)
    }

    @Test
    func test_readOnlyParticipant_cannotDeleteItems() {
        let permission = SharePermission(role: .readOnlyParticipant)
        #expect(permission.canDeleteItems == false)
    }

    @Test
    func test_readOnlyParticipant_canViewItems() {
        let permission = SharePermission(role: .readOnlyParticipant)
        #expect(permission.canViewItems)
    }
}
