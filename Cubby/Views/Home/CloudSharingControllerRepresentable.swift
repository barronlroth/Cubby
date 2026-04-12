#if canImport(UIKit)
import CloudKit
import SwiftUI
import UIKit

struct CloudSharingControllerRepresentable: UIViewControllerRepresentable {
    static let supportedPermissions: UICloudSharingController.PermissionOptions = [
        .allowPublic,
        .allowReadWrite
    ]

    let share: CKShare
    let container: CKContainer
    let title: String
    var onSave: (() -> Void)?
    var onStopSharing: (() -> Void)?
    var onError: ((Error) -> Void)?

    init(
        share: CKShare,
        container: CKContainer,
        title: String,
        onSave: (() -> Void)? = nil,
        onStopSharing: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.share = share
        self.container = container
        self.title = title
        self.onSave = onSave
        self.onStopSharing = onStopSharing
        self.onError = onError
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            title: title,
            onSave: onSave,
            onStopSharing: onStopSharing,
            onError: onError
        )
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(
            share: share,
            container: container
        )
        controller.delegate = context.coordinator
        // Shared homes currently ship as editable link sharing only.
        controller.availablePermissions = Self.supportedPermissions
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UICloudSharingController,
        context: Context
    ) {
        context.coordinator.title = title
        context.coordinator.onSave = onSave
        context.coordinator.onStopSharing = onStopSharing
        context.coordinator.onError = onError
    }
}

extension CloudSharingControllerRepresentable {
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var title: String
        var onSave: (() -> Void)?
        var onStopSharing: (() -> Void)?
        var onError: ((Error) -> Void)?

        init(
            title: String,
            onSave: (() -> Void)?,
            onStopSharing: (() -> Void)?,
            onError: ((Error) -> Void)?
        ) {
            self.title = title
            self.onSave = onSave
            self.onStopSharing = onStopSharing
            self.onError = onError
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
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
    }
}
#endif
