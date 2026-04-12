#if canImport(UIKit)
import CloudKit
import LinkPresentation
import SwiftUI
import UIKit

enum SharedHomeShareBranding {
    static let iconMaxDimension: CGFloat = 60

    static func shareTitle(for homeName: String) -> String {
        "Cubby Home: \(homeName)"
    }

    static func itemType() -> String {
        "Home Inventory"
    }

    static func appIconImage(maxDimension: CGFloat = iconMaxDimension) -> UIImage? {
        guard let iconName = primaryIconName(),
              let image = UIImage(named: iconName) else {
            return nil
        }
        return resizedImage(image, maxDimension: maxDimension)
    }

    private static func primaryIconName() -> String? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let iconName = iconFiles.last else {
            return nil
        }
        return iconName
    }

    private static func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let maxSourceDimension = max(image.size.width, image.size.height)
        guard maxSourceDimension > maxDimension else {
            return image
        }

        let scale = maxDimension / maxSourceDimension
        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

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
            SharedHomeShareBranding.shareTitle(for: title)
        }

        func itemType(for csc: UICloudSharingController) -> String? {
            SharedHomeShareBranding.itemType()
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            SharedHomeShareBranding.appIconImage()?.pngData()
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
