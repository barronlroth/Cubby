#if canImport(UIKit)
import Testing
import UIKit
@testable import Cubby

struct CloudSharingControllerRepresentableTests {
    @Test
    func test_supportedPermissions_letOwnersChooseAccessAndEditing() {
        let permissions = CloudSharingControllerRepresentable.supportedPermissions

        #expect(permissions.contains(.allowPublic))
        #expect(permissions.contains(.allowPrivate))
        #expect(permissions.contains(.allowReadWrite))
        #expect(permissions.contains(.allowReadOnly))
    }

    @Test
    func test_shareLinkOptions_allowAnyAccessAndPermission() {
        let options = ShareableHome.allowedSharingOptions

        #expect(options.allowedParticipantAccessOptions == .any)
        #expect(options.allowedParticipantPermissionOptions == .any)
    }

    @Test
    func test_shareTitle_usesBrandedHomePrefix() {
        #expect(
            SharedHomeShareBranding.shareTitle(for: "Beach House")
                == "Cubby Home: Beach House"
        )
    }
}
#endif
