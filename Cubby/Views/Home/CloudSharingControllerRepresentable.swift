#if canImport(UIKit)
import CloudKit
import SwiftUI
import UIKit

struct CloudSharingControllerRepresentable: UIViewControllerRepresentable {
    enum Mode {
        case existing(share: CKShare, container: CKContainer)
        case preparation((@escaping (CKShare?, CKContainer?, Error?) -> Void) -> Void)
    }

    let mode: Mode
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
        self.mode = .existing(share: share, container: container)
        self.title = title
        self.onSave = onSave
        self.onStopSharing = onStopSharing
        self.onError = onError
    }

    init(
        title: String,
        preparationHandler: @escaping (@escaping (CKShare?, CKContainer?, Error?) -> Void) -> Void,
        onSave: (() -> Void)? = nil,
        onStopSharing: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.mode = .preparation(preparationHandler)
        self.title = title
        self.onSave = onSave
        self.onStopSharing = onStopSharing
        self.onError = onError
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            title: title,
            mode: mode,
            onSave: onSave,
            onStopSharing: onStopSharing,
            onError: onError
        )
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller: UICloudSharingController
        switch mode {
        case let .existing(share, container):
            controller = UICloudSharingController(
                share: share,
                container: container
            )
        case .preparation:
            controller = UICloudSharingController { _, completion in
                context.coordinator.prepareShare(completion: completion)
            }
        }
        controller.delegate = context.coordinator
        controller.availablePermissions = [
            .allowPublic,
            .allowPrivate,
            .allowReadWrite
        ]
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UICloudSharingController,
        context: Context
    ) {
        context.coordinator.title = title
        context.coordinator.mode = mode
        context.coordinator.onSave = onSave
        context.coordinator.onStopSharing = onStopSharing
        context.coordinator.onError = onError
    }
}

extension CloudSharingControllerRepresentable {
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var title: String
        var mode: Mode
        var onSave: (() -> Void)?
        var onStopSharing: (() -> Void)?
        var onError: ((Error) -> Void)?

        init(
            title: String,
            mode: Mode,
            onSave: (() -> Void)?,
            onStopSharing: (() -> Void)?,
            onError: ((Error) -> Void)?
        ) {
            self.title = title
            self.mode = mode
            self.onSave = onSave
            self.onStopSharing = onStopSharing
            self.onError = onError
        }

        func prepareShare(
            completion: @escaping (CKShare?, CKContainer?, Error?) -> Void
        ) {
            guard case let .preparation(preparationHandler) = mode else {
                let error = NSError(
                    domain: "CloudSharingControllerRepresentable",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Share preparation is unavailable."]
                )
                completion(nil, nil, error)
                return
            }

            preparationHandler(completion)
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
