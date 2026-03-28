import CloudKit
import Testing
@testable import Cubby

struct HomeSharePresentationTests {
    @Test
    func test_unsharedHome_opensCreateFlow() {
        let kind = HomeView.sharePresentationKind(
            isShared: false,
            existingShare: nil
        )

        #expect(kind == .createNew)
    }

    @Test
    func test_existingShare_opensManageFlow() {
        let kind = HomeView.sharePresentationKind(
            isShared: true,
            existingShare: makeShare()
        )

        #expect(kind == .manageExisting)
    }

    @Test
    func test_sharedHome_withoutFetchedShare_surfacesLookupFailure() {
        let kind = HomeView.sharePresentationKind(
            isShared: true,
            existingShare: nil
        )

        #expect(kind == .unavailableExistingShare)
    }

    private func makeShare() -> CKShare {
        let rootRecord = CKRecord(recordType: "CDHome")
        return CKShare(rootRecord: rootRecord)
    }
}
