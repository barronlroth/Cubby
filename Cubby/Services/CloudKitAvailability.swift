import CloudKit
import Foundation

enum CloudKitAvailability: Equatable {
    case available
    case unavailable(reason: UnavailableReason)

    enum UnavailableReason: Equatable {
        case noAccount
        case restricted
        case couldNotDetermine
        case temporarilyUnavailable
        case error

        var logDescription: String {
            switch self {
            case .noAccount:
                "No iCloud account"
            case .restricted:
                "iCloud restricted"
            case .couldNotDetermine:
                "iCloud status unknown"
            case .temporarilyUnavailable:
                "iCloud temporarily unavailable"
            case .error:
                "iCloud status error"
            }
        }
    }

    var isAvailable: Bool {
        switch self {
        case .available:
            true
        case .unavailable:
            false
        }
    }
}

protocol CloudKitAccountStatusProviding {
    func accountStatus() async throws -> CKAccountStatus
}

struct CloudKitAccountStatusProvider: CloudKitAccountStatusProviding {
    let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: status)
            }
        }
    }
}

struct CloudKitAvailabilityChecker {
    static func check(
        using provider: CloudKitAccountStatusProviding = CloudKitAccountStatusProvider()
    ) async -> CloudKitAvailability {
        do {
            let status = try await provider.accountStatus()
            switch status {
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
            @unknown default:
                return .unavailable(reason: .error)
            }
        } catch {
            return .unavailable(reason: .error)
        }
    }

    static func logIfUnavailable(
        using provider: CloudKitAccountStatusProviding = CloudKitAccountStatusProvider()
    ) async {
        let availability = await check(using: provider)
        guard case let .unavailable(reason) = availability else { return }
        DebugLogger.warning("CloudKit unavailable: \(reason.logDescription)")
    }
}
