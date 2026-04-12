#if canImport(UIKit)
import Testing
import UIKit
@testable import Cubby

struct CloudSharingControllerRepresentableTests {
    @Test
    func test_supportedPermissions_arePublicEditableOnly() {
        let permissions = CloudSharingControllerRepresentable.supportedPermissions

        #expect(permissions.contains(.allowPublic))
        #expect(permissions.contains(.allowReadWrite))
        #expect(permissions.contains(.allowPrivate) == false)
    }
}
#endif
