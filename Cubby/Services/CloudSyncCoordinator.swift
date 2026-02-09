import Foundation
import SwiftUI

protocol CloudKitAvailabilityChecking {
    func check(
        forcedAvailability: CloudKitSyncSettings.ForcedAvailability?
    ) async -> CloudKitAvailability
}

struct LiveCloudKitAvailabilityChecker: CloudKitAvailabilityChecking {
    private let provider: CloudKitAccountStatusProviding

    init(provider: CloudKitAccountStatusProviding = CloudKitAccountStatusProvider()) {
        self.provider = provider
    }

    func check(
        forcedAvailability: CloudKitSyncSettings.ForcedAvailability?
    ) async -> CloudKitAvailability {
        await CloudKitAvailabilityChecker.check(
            forcedAvailability: forcedAvailability,
            using: provider
        )
    }
}

@MainActor
final class CloudSyncCoordinator: ObservableObject {
    @Published private(set) var state: CloudSyncState

    private let forcedAvailability: CloudKitSyncSettings.ForcedAvailability?
    private let availabilityChecker: any CloudKitAvailabilityChecking
    private let pollIntervalNanoseconds: UInt64
    private var pollingTask: Task<Void, Never>?

    var isRunning: Bool {
        pollingTask != nil
    }

    init(
        isCloudKitEnabled: Bool,
        forcedAvailability: CloudKitSyncSettings.ForcedAvailability? = nil,
        availabilityChecker: any CloudKitAvailabilityChecking = LiveCloudKitAvailabilityChecker(),
        pollIntervalNanoseconds: UInt64 = 30_000_000_000
    ) {
        self.state = CloudSyncState.initial(isCloudKitEnabled: isCloudKitEnabled)
        self.forcedAvailability = forcedAvailability
        self.availabilityChecker = availabilityChecker
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
    }

    func start() {
        guard state.isCloudKitEnabled else { return }
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }

            await self.refreshNow()
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: self.pollIntervalNanoseconds)
                guard Task.isCancelled == false else { break }
                await self.refreshNow()
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            start()
        case .inactive, .background:
            stop()
        @unknown default:
            stop()
        }
    }

    func refreshNow() async {
        guard state.isCloudKitEnabled else { return }

        if state.lastSyncEventAt == nil {
            state.mode = .checking
        } else {
            state.markSyncStarted()
        }

        let availability = await availabilityChecker.check(
            forcedAvailability: forcedAvailability
        )

        state.applyAvailability(availability)
        if availability == .available {
            state.markSyncCompleted()
        }
    }
}
