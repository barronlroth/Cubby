import CloudKit
import Foundation

protocol SharingErrorHandlerProtocol: AnyObject {
    var currentUserFacingMessage: String? { get }
    var isOffline: Bool { get }

    func handle(error: Error) -> SharingErrorPresentation
    func handleShareAcceptanceFailure(_ error: Error) -> SharingErrorPresentation
    func shouldRetry(error: Error, attempt: Int) -> Bool
    func retryDelay(forAttempt attempt: Int) -> TimeInterval
    func isShareRevokedError(_ error: Error) -> Bool
    func handleShareRevoked(homeID: UUID, homeIDs: inout [UUID])
}

struct SharingErrorPresentation: Equatable {
    let message: String
    let isOffline: Bool
    let shouldRetry: Bool
}

final class SharingErrorHandler: SharingErrorHandlerProtocol {
    static let didUpdateNotification = Notification.Name("SharingErrorHandler.didUpdate")
    static let messageUserInfoKey = "message"

    private let notificationCenter: NotificationCenter
    private let maxRetryAttempts: Int

    private(set) var currentUserFacingMessage: String?
    private(set) var isOffline = false

    init(
        notificationCenter: NotificationCenter = .default,
        maxRetryAttempts: Int = 3
    ) {
        self.notificationCenter = notificationCenter
        self.maxRetryAttempts = maxRetryAttempts
    }

    func handle(error: Error) -> SharingErrorPresentation {
        let presentation = presentation(for: error)
        currentUserFacingMessage = presentation.message
        isOffline = presentation.isOffline

        notificationCenter.post(
            name: Self.didUpdateNotification,
            object: self,
            userInfo: [Self.messageUserInfoKey: presentation.message]
        )

        return presentation
    }

    func handleShareAcceptanceFailure(_ error: Error) -> SharingErrorPresentation {
        handle(error: error)
    }

    func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxRetryAttempts else { return false }
        guard let ckError = error as? CKError else { return false }

        switch ckError.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited,
             .zoneBusy, .serverRecordChanged:
            return true
        default:
            return false
        }
    }

    func retryDelay(forAttempt attempt: Int) -> TimeInterval {
        min(pow(2.0, Double(max(0, attempt))), 8.0)
    }

    func isShareRevokedError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        switch ckError.code {
        case .unknownItem, .permissionFailure:
            return true
        default:
            return false
        }
    }

    func handleShareRevoked(homeID: UUID, homeIDs: inout [UUID]) {
        homeIDs.removeAll { $0 == homeID }
        currentUserFacingMessage = "A shared home is no longer available."
        isOffline = false
    }
}

private extension SharingErrorHandler {
    func presentation(for error: Error) -> SharingErrorPresentation {
        guard let ckError = error as? CKError else {
            return SharingErrorPresentation(
                message: "Something went wrong while sharing this home.",
                isOffline: false,
                shouldRetry: false
            )
        }

        switch ckError.code {
        case .networkUnavailable:
            return SharingErrorPresentation(
                message: "You're offline. Check your internet connection and try again.",
                isOffline: true,
                shouldRetry: true
            )
        case .participantMayNeedVerification:
            return SharingErrorPresentation(
                message: "The participant may need to verify their iCloud account before joining.",
                isOffline: false,
                shouldRetry: false
            )
        case .serverRecordChanged:
            return SharingErrorPresentation(
                message: "This home changed on another device. Please try again.",
                isOffline: false,
                shouldRetry: true
            )
        case .quotaExceeded:
            return SharingErrorPresentation(
                message: "Your iCloud storage is full. Free up space to continue sharing.",
                isOffline: false,
                shouldRetry: false
            )
        case .unknownItem, .permissionFailure:
            return SharingErrorPresentation(
                message: "This shared home is no longer available.",
                isOffline: false,
                shouldRetry: false
            )
        default:
            return SharingErrorPresentation(
                message: "Unable to complete sharing right now. Please try again.",
                isOffline: false,
                shouldRetry: shouldRetry(error: ckError, attempt: 0)
            )
        }
    }
}
