import Foundation

struct CloudSyncState: Equatable {
    enum Mode: Equatable {
        case disabled
        case checking
        case syncing
        case synced
        case offline
        case iCloudUnavailable(reason: CloudKitAvailability.UnavailableReason)
    }

    let isCloudKitEnabled: Bool
    var accountAvailability: CloudKitAvailability
    var lastSyncEventAt: Date?
    var lastError: String?
    var mode: Mode

    static func initial(isCloudKitEnabled: Bool) -> CloudSyncState {
        if isCloudKitEnabled {
            return CloudSyncState(
                isCloudKitEnabled: true,
                accountAvailability: .unavailable(reason: .couldNotDetermine),
                lastSyncEventAt: nil,
                lastError: nil,
                mode: .checking
            )
        }

        return CloudSyncState(
            isCloudKitEnabled: false,
            accountAvailability: .unavailable(reason: .couldNotDetermine),
            lastSyncEventAt: nil,
            lastError: nil,
            mode: .disabled
        )
    }

    mutating func applyAvailability(_ availability: CloudKitAvailability) {
        accountAvailability = availability

        guard isCloudKitEnabled else {
            mode = .disabled
            return
        }

        switch availability {
        case .available:
            mode = .synced
            lastError = nil
        case let .unavailable(reason):
            switch reason {
            case .temporarilyUnavailable, .error:
                mode = .offline
            case .noAccount, .restricted, .couldNotDetermine:
                mode = .iCloudUnavailable(reason: reason)
            }
        }
    }

    mutating func markSyncStarted() {
        guard isCloudKitEnabled else {
            mode = .disabled
            return
        }
        mode = .syncing
    }

    mutating func markSyncCompleted(at date: Date = Date()) {
        guard isCloudKitEnabled else {
            mode = .disabled
            return
        }

        lastSyncEventAt = date
        lastError = nil
        mode = .synced
    }

    mutating func markSyncFailed(_ message: String) {
        guard isCloudKitEnabled else {
            mode = .disabled
            return
        }

        lastError = message
        mode = .offline
    }
}
