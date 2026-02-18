import CloudKit
import Foundation
import Testing
@testable import Cubby

@Suite("Sharing Error Handler Tests")
struct SharingErrorHandlerTests {
    @Test
    func test_shareAcceptanceFailure_showsUserFacingError() {
        let handler = SharingErrorHandler()
        let error = CKError(.participantMayNeedVerification)

        let presentation = handler.handleShareAcceptanceFailure(error)

        #expect(presentation.message.isEmpty == false)
        #expect(presentation.message.lowercased().contains("verify"))
        #expect(handler.currentUserFacingMessage == presentation.message)
    }

    @Test
    func test_networkUnavailable_showsOfflineState() {
        let handler = SharingErrorHandler()
        let error = CKError(.networkUnavailable)

        let presentation = handler.handle(error: error)

        #expect(presentation.isOffline == true)
        #expect(handler.isOffline == true)
    }

    @Test
    func test_shareRevoked_removesHomeFromList() {
        let handler = SharingErrorHandler()
        let homeA = UUID()
        let homeB = UUID()
        let revokedHome = UUID()
        var homeIDs = [homeA, revokedHome, homeB]

        handler.handleShareRevoked(homeID: revokedHome, homeIDs: &homeIDs)

        #expect(homeIDs.contains(revokedHome) == false)
        #expect(homeIDs == [homeA, homeB])
    }
}
