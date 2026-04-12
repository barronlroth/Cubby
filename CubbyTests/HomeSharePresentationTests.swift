import Testing
@testable import Cubby

struct HomeSharePresentationTests {
    @Test
    func test_ownerSharedHomeWithPersistedShare_showsManageAffordance() {
        let presentation = HomeView.sharedStatusPresentation(
            isOwnedByCurrentUser: true,
            hasExistingShare: true,
            isDebugMockSharingEnabled: false
        )

        #expect(presentation == .manage)
    }

    @Test
    func test_ownerSharedHomeWithoutPersistedShare_staysPassive() {
        let presentation = HomeView.sharedStatusPresentation(
            isOwnedByCurrentUser: true,
            hasExistingShare: false,
            isDebugMockSharingEnabled: false
        )

        #expect(presentation == .shared)
    }

    @Test
    func test_collaboratorSharedHome_showsSharedWithYou() {
        let presentation = HomeView.sharedStatusPresentation(
            isOwnedByCurrentUser: false,
            hasExistingShare: true,
            isDebugMockSharingEnabled: false
        )

        #expect(presentation == .sharedWithYou)
    }

    @Test
    func test_debugMockOwnerSharedHome_staysPassive() {
        let presentation = HomeView.sharedStatusPresentation(
            isOwnedByCurrentUser: true,
            hasExistingShare: true,
            isDebugMockSharingEnabled: true
        )

        #expect(presentation == .shared)
    }
}
