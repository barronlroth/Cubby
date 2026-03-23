#if canImport(UIKit)
import CloudKit
import Foundation
import LinkPresentation
import SwiftUI
import UIKit

struct CloudShareActivityControllerRepresentable: UIViewControllerRepresentable {
    let title: String
    let share: CKShare
    let container: CKContainer
    var onComplete: (() -> Void)?
    var onError: ((Error) -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let itemProvider = NSItemProvider()
        let sharingOptions = CKAllowedSharingOptions(
            allowedParticipantPermissionOptions: .readWrite,
            allowedParticipantAccessOptions: .specifiedRecipientsOnly
        )
        sharingOptions.allowsParticipantsToInviteOthers = false
        sharingOptions.allowsAccessRequests = false

        itemProvider.registerCKShare(
            share,
            container: container,
            allowedSharingOptions: sharingOptions
        )

        let configuration = UIActivityItemsConfiguration(itemProviders: [itemProvider])
        let metadata = LPLinkMetadata()
        metadata.title = title

        if let thumbnail = ShareThumbnailProvider.image() {
            let imageProvider = NSItemProvider(object: thumbnail)
            metadata.iconProvider = imageProvider
            metadata.imageProvider = imageProvider
        }

        configuration.metadataProvider = { key in
            switch key {
            case .title:
                return title
            case .linkPresentationMetadata:
                return metadata
            default:
                return nil
            }
        }

        let controller = UIActivityViewController(activityItemsConfiguration: configuration)
        controller.completionWithItemsHandler = { _, _, _, error in
            if let error {
                onError?(error)
            }
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

enum ShareThumbnailProvider {
    static let assetName = "ShareThumbnail"

    static func image() -> UIImage? {
        UIImage(named: assetName)
    }

    static func pngData() -> Data? {
        image()?.pngData()
    }
}
#endif
