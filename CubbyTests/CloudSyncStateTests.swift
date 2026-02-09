import Foundation
import Testing
@testable import Cubby

struct CloudSyncStateTests {
    @Test func testInitialStateWhenCloudKitEnabled() {
        let state = CloudSyncState.initial(isCloudKitEnabled: true)
        #expect(state.isCloudKitEnabled == true)
        #expect(state.mode == .checking)
        #expect(state.accountAvailability == .unavailable(reason: .couldNotDetermine))
    }

    @Test func testInitialStateWhenCloudKitDisabled() {
        let state = CloudSyncState.initial(isCloudKitEnabled: false)
        #expect(state.isCloudKitEnabled == false)
        #expect(state.mode == .disabled)
    }

    @Test func testApplyingAvailableAvailabilityTransitionsToSynced() {
        var state = CloudSyncState.initial(isCloudKitEnabled: true)
        state.applyAvailability(.available)

        #expect(state.mode == .synced)
        #expect(state.accountAvailability == .available)
    }

    @Test func testApplyingNoAccountTransitionsToICloudUnavailable() {
        var state = CloudSyncState.initial(isCloudKitEnabled: true)
        state.applyAvailability(.unavailable(reason: .noAccount))

        #expect(state.mode == .iCloudUnavailable(reason: .noAccount))
    }

    @Test func testApplyingTemporarilyUnavailableTransitionsToOffline() {
        var state = CloudSyncState.initial(isCloudKitEnabled: true)
        state.applyAvailability(.unavailable(reason: .temporarilyUnavailable))

        #expect(state.mode == .offline)
    }

    @Test func testSyncStartedAndCompletedUpdatesState() {
        var state = CloudSyncState.initial(isCloudKitEnabled: true)
        state.applyAvailability(.available)
        state.markSyncStarted()

        #expect(state.mode == .syncing)

        let completionDate = Date(timeIntervalSince1970: 1_000)
        state.markSyncCompleted(at: completionDate)

        #expect(state.mode == .synced)
        #expect(state.lastSyncEventAt == completionDate)
        #expect(state.lastError == nil)
    }

    @Test func testSyncFailureSetsOfflineAndError() {
        var state = CloudSyncState.initial(isCloudKitEnabled: true)
        state.markSyncFailed("Network timed out")

        #expect(state.mode == .offline)
        #expect(state.lastError == "Network timed out")
    }
}
