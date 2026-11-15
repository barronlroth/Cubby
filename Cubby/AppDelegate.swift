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
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = AppDelegate.self
        return config
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        _ = application
        handleShareAcceptance(cloudKitShareMetadata)
    }

    /// Cold launch from an invitation: the metadata arrives in the connection
    /// options instead of `windowScene(_:userDidAcceptCloudKitShareWith:)`.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        _ = scene
        _ = session
        if let metadata = connectionOptions.cloudKitShareMetadata {
            DebugLogger.info("Cold launch with a CloudKit share invitation")
            handleShareAcceptance(metadata)
        }
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

        let service = homeSharingService
        let errorHandler = sharingErrorHandler
        Task { @MainActor in
            await ShareAcceptanceCoordinator.shared.accept(
                metadata,
                using: service,
                errorHandler: errorHandler
            )
        }
    }
}
#endif
