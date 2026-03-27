#if canImport(UIKit)
import CloudKit
import SwiftUI
import UIKit

struct CloudSharingControllerRepresentable: UIViewControllerRepresentable {
    enum Mode {
        case manageExisting(CKShare)
    }

    let mode: Mode
    let container: CKContainer
    let homeID: UUID
    let containerIdentifier: String
    let accountStatusProvider: @Sendable () async -> CKAccountStatus
    let title: String
    var onSave: (() -> Void)?
    var onStopSharing: (() -> Void)?
    var onError: ((Error) -> Void)?

    init(
        mode: Mode,
        container: CKContainer,
        homeID: UUID,
        containerIdentifier: String,
        accountStatusProvider: @escaping @Sendable () async -> CKAccountStatus,
        title: String,
        onSave: (() -> Void)? = nil,
        onStopSharing: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.mode = mode
        self.container = container
        self.homeID = homeID
        self.containerIdentifier = containerIdentifier
        self.accountStatusProvider = accountStatusProvider
        self.title = title
        self.onSave = onSave
        self.onStopSharing = onStopSharing
        self.onError = onError
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            title: title,
            homeID: homeID,
            containerIdentifier: containerIdentifier,
            presentationModeLabel: presentationModeLabel,
            accountStatusProvider: accountStatusProvider,
            onSave: onSave,
            onStopSharing: onStopSharing,
            onError: onError
        )
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        DebugLogger.info(
            "Creating UICloudSharingController mode=\(presentationModeLabel) homeID=\(homeID.uuidString)"
        )
        let controller: UICloudSharingController
        switch mode {
        case .manageExisting(let share):
            controller = UICloudSharingController(
                share: share,
                container: container
            )
        }
        controller.delegate = context.coordinator
        controller.availablePermissions = [
            .allowPublic,
            .allowReadWrite
        ]
        DebugLogger.info(
            "Configured UICloudSharingController mode=\(presentationModeLabel) permissions=allowPublic+allowReadWrite"
        )
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UICloudSharingController,
        context: Context
    ) {
        context.coordinator.title = title
        context.coordinator.homeID = homeID
        context.coordinator.containerIdentifier = containerIdentifier
        context.coordinator.presentationModeLabel = presentationModeLabel
        context.coordinator.accountStatusProvider = accountStatusProvider
        context.coordinator.onSave = onSave
        context.coordinator.onStopSharing = onStopSharing
        context.coordinator.onError = onError
    }

    private var presentationModeLabel: String { "manage-existing" }
}

extension CloudSharingControllerRepresentable {
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var title: String
        var homeID: UUID
        var containerIdentifier: String
        var presentationModeLabel: String
        var accountStatusProvider: @Sendable () async -> CKAccountStatus
        var onSave: (() -> Void)?
        var onStopSharing: (() -> Void)?
        var onError: ((Error) -> Void)?

        init(
            title: String,
            homeID: UUID,
            containerIdentifier: String,
            presentationModeLabel: String,
            accountStatusProvider: @escaping @Sendable () async -> CKAccountStatus,
            onSave: (() -> Void)?,
            onStopSharing: (() -> Void)?,
            onError: ((Error) -> Void)?
        ) {
            self.title = title
            self.homeID = homeID
            self.containerIdentifier = containerIdentifier
            self.presentationModeLabel = presentationModeLabel
            self.accountStatusProvider = accountStatusProvider
            self.onSave = onSave
            self.onStopSharing = onStopSharing
            self.onError = onError
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            logFailure(for: csc, error: error)
            onError?(error)
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            title
        }

        func cloudSharingControllerDidSaveShare(
            _ csc: UICloudSharingController
        ) {
            onSave?()
        }

        func cloudSharingControllerDidStopSharing(
            _ csc: UICloudSharingController
        ) {
            onStopSharing?()
        }

        private func logFailure(
            for controller: UICloudSharingController,
            error: Error
        ) {
            let share = controller.share
            let nsError = error as NSError

            Task {
                let accountStatus = await accountStatusProvider()
                let ckErrorCode = (error as? CKError)?.code.rawValue.description ?? "n/a"
                let shareRecordName = share?.recordID.recordName ?? "nil"
                let participantCount = share?.participants.count ?? 0
                let publicPermission = String(describing: share?.publicPermission ?? .none)

                DebugLogger.error(
                    """
                    Cloud share save failed mode=\(presentationModeLabel) homeID=\(homeID.uuidString) \
                    container=\(containerIdentifier) accountStatus=\(String(describing: accountStatus)) \
                    shareRecordID=\(shareRecordName) participantCount=\(participantCount) \
                    publicPermission=\(publicPermission) nsErrorDomain=\(nsError.domain) \
                    nsErrorCode=\(nsError.code) ckErrorCode=\(ckErrorCode) \
                    userInfo=\(String(describing: nsError.userInfo))
                    """
                )
            }
        }
    }
}
#endif
