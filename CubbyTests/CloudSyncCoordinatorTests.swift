import SwiftUI
import Testing
@testable import Cubby

struct CloudSyncCoordinatorTests {
    actor StubChecker: CloudKitAvailabilityChecking {
        private(set) var callCount = 0
        private let response: CloudKitAvailability
        private let delayNanoseconds: UInt64

        init(response: CloudKitAvailability, delayNanoseconds: UInt64 = 0) {
            self.response = response
            self.delayNanoseconds = delayNanoseconds
        }

        func check(
            forcedAvailability: CloudKitSyncSettings.ForcedAvailability?
        ) async -> CloudKitAvailability {
            callCount += 1
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }

            if let forcedAvailability {
                switch forcedAvailability {
                case .available:
                    return .available
                case .noAccount:
                    return .unavailable(reason: .noAccount)
                case .restricted:
                    return .unavailable(reason: .restricted)
                case .couldNotDetermine:
                    return .unavailable(reason: .couldNotDetermine)
                case .temporarilyUnavailable:
                    return .unavailable(reason: .temporarilyUnavailable)
                case .error:
                    return .unavailable(reason: .error)
                }
            }

            return response
        }

        func readCallCount() -> Int {
            callCount
        }
    }

    @MainActor
    @Test func testStartRefreshesAvailability() async {
        let checker = StubChecker(response: .available)
        let coordinator = CloudSyncCoordinator(
            isCloudKitEnabled: true,
            availabilityChecker: checker,
            pollIntervalNanoseconds: 5_000_000_000
        )

        coordinator.start()
        let didSync = await waitUntil {
            let callCount = await checker.readCallCount()
            return coordinator.state.mode == .synced && callCount >= 1
        }

        #expect(didSync)
        #expect(await checker.readCallCount() >= 1)

        coordinator.stop()
    }

    @MainActor
    @Test func testStopCancelsPolling() async {
        let checker = StubChecker(response: .available)
        let coordinator = CloudSyncCoordinator(
            isCloudKitEnabled: true,
            availabilityChecker: checker,
            pollIntervalNanoseconds: 5_000_000_000
        )

        coordinator.start()
        let didStart = await waitUntil {
            await checker.readCallCount() >= 1
        }
        #expect(didStart)

        let beforeStopCount = await checker.readCallCount()
        coordinator.stop()

        try? await Task.sleep(nanoseconds: 100_000_000)
        let afterStopCount = await checker.readCallCount()

        #expect(coordinator.isRunning == false)
        #expect(afterStopCount == beforeStopCount)
    }

    @MainActor
    @Test func testImmediateStopCancelsPendingInitialRefresh() async {
        let checker = StubChecker(response: .available)
        let coordinator = CloudSyncCoordinator(
            isCloudKitEnabled: true,
            availabilityChecker: checker,
            pollIntervalNanoseconds: 5_000_000_000
        )

        coordinator.start()
        coordinator.stop()

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(coordinator.isRunning == false)
        #expect(await checker.readCallCount() == 0)
    }

    @MainActor
    @Test func testStartIsNonBlockingWithSlowChecker() async {
        let checker = StubChecker(
            response: .available,
            delayNanoseconds: 500_000_000
        )
        let coordinator = CloudSyncCoordinator(
            isCloudKitEnabled: true,
            availabilityChecker: checker,
            pollIntervalNanoseconds: 5_000_000_000
        )

        let start = Date()
        coordinator.start()
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 0.05)
        coordinator.stop()
    }

    @MainActor
    @Test func testScenePhaseTransitionsStartAndStopPolling() async {
        let checker = StubChecker(response: .available)
        let coordinator = CloudSyncCoordinator(
            isCloudKitEnabled: true,
            availabilityChecker: checker,
            pollIntervalNanoseconds: 5_000_000_000
        )

        coordinator.handleScenePhase(.active)
        #expect(coordinator.isRunning == true)

        coordinator.handleScenePhase(.background)
        #expect(coordinator.isRunning == false)
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        condition: () async -> Bool
    ) async -> Bool {
        let start = ContinuousClock.now
        let timeout = Duration.nanoseconds(Int64(timeoutNanoseconds))

        while ContinuousClock.now - start < timeout {
            if await condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        return await condition()
    }
}
