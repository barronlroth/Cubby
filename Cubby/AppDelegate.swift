#if canImport(UIKit)
import CloudKit
import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UIWindowSceneDelegate {
    static var makeHomeSharingService: () -> (any HomeSharingServiceProtocol)? = {
        nil
    }
    static var makeSharingErrorHandler: () -> (any SharingErrorHandlerProtocol)? = {
        SharingErrorHandler()
    }

    var homeSharingService: (any HomeSharingServiceProtocol)?
    var sharingErrorHandler: (any SharingErrorHandlerProtocol)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = application
        _ = launchOptions
        if homeSharingService == nil {
            homeSharingService = Self.makeHomeSharingService()
        }
        if sharingErrorHandler == nil {
            sharingErrorHandler = Self.makeSharingErrorHandler()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        _ = application
        handleShareAcceptance(cloudKitShareMetadata)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        _ = windowScene
        handleShareAcceptance(cloudKitShareMetadata)
    }

    private func handleShareAcceptance(_ metadata: CKShare.Metadata) {
        if homeSharingService == nil {
            homeSharingService = Self.makeHomeSharingService()
        }
        if sharingErrorHandler == nil {
            sharingErrorHandler = Self.makeSharingErrorHandler()
        }

        guard let homeSharingService else {
            DebugLogger.warning(
                "Received CloudKit share metadata, but HomeSharingService is not configured."
            )
            return
        }

        Task { @MainActor in
            do {
                try await homeSharingService.acceptShareInvitation(from: metadata)
            } catch {
                if let sharingErrorHandler {
                    let presentation = sharingErrorHandler.handleShareAcceptanceFailure(error)
                    DebugLogger.error(
                        "Failed to accept CloudKit share invitation: \(error). Message: \(presentation.message)"
                    )
                } else {
                    DebugLogger.error("Failed to accept CloudKit share invitation: \(error)")
                }
            }
        }
    }
}
#endif
