import Testing
@testable import Cubby

struct SyncedPhotoPresenceStateTests {
    @Test func testResolvesNoPhotoWhenMetadataAndImageAreMissing() {
        let state = SyncedPhotoPresenceState.resolve(
            hasPhotoMetadata: false,
            hasDisplayImage: false,
            isLoading: false
        )

        #expect(state == .noPhoto)
        #expect(state.missingOnDeviceMessage == nil)
    }

    @Test func testResolvesLoadingWhenMetadataExistsAndPhotoIsLoading() {
        let state = SyncedPhotoPresenceState.resolve(
            hasPhotoMetadata: true,
            hasDisplayImage: false,
            isLoading: true
        )

        #expect(state == .loading)
        #expect(state.missingOnDeviceMessage == nil)
    }

    @Test func testResolvesAvailableWhenDisplayImageExists() {
        let state = SyncedPhotoPresenceState.resolve(
            hasPhotoMetadata: true,
            hasDisplayImage: true,
            isLoading: false
        )

        #expect(state == .available)
        #expect(state.missingOnDeviceMessage == nil)
    }

    @Test func testResolvesMissingOnDeviceWhenMetadataExistsWithoutImage() {
        let state = SyncedPhotoPresenceState.resolve(
            hasPhotoMetadata: true,
            hasDisplayImage: false,
            isLoading: false
        )

        #expect(state == .missingOnDevice)
        #expect(state.missingOnDeviceMessage == "Photo not on this device yet")
    }
}
