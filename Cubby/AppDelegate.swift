#if canImport(UIKit)
import CloudKit
import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UIWindowSceneDelegate {
    static var makeHomeSharingService: () -> (any HomeSharingServiceProtocol)? = {
        nil
    }

    var homeSharingService: (any HomeSharingServiceProtocol)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = application
        _ = launchOptions
        if homeSharingService == nil {
            homeSharingService = Self.makeHomeSharingService()
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
                DebugLogger.error("Failed to accept CloudKit share invitation: \(error)")
            }
        }
    }
}
#endif
