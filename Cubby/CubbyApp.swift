//
//  CubbyApp.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@main
struct CubbyApp: App {
#if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
#endif
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    let modelContainer: ModelContainer
    private let isUITesting: Bool
    private let cloudKitSettings: CloudKitSyncSettings
    private let shouldSeedMockData: Bool
    private let forceOnboardingSnapshot: Bool
    private let shouldSeedItemLimitReachedData: Bool
    private let shouldSeedFreeTierData: Bool
    private let shouldSeedEmptyHomeData: Bool
    private let shouldSeedMissingLocalPhotoData: Bool
    private let skipSeeding: Bool
    private let coreDataPersistenceController: PersistenceController?
    private let coreDataRemoteChangeHandler: RemoteChangeHandler?
    private let appStore: AppStore?
    private let sharedHomesGateService: any SharedHomesGateServiceProtocol
    private let homeSharingService: (any HomeSharingServiceProtocol)?

    private static func logModelContainerError(_ message: String, error: Error) {
        let nsError = error as NSError
        let details = "\(message): \(String(reflecting: error)) (domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo))"
        DebugLogger.error(details)
        NSLog("%@", details)
        if let data = (details + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
    
    @MainActor
    init() {
        let args = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let bundlePath = Bundle.main.bundlePath
        let isRunningTests = CloudKitSyncSettings.isRunningTests(
            environment: environment,
            bundlePath: bundlePath
        ) || NSClassFromString("XCTestCase") != nil
        // Fastlane snapshot passes "-ui_testing"; support both.
        self.isUITesting = args.contains("UI-TESTING") || args.contains("-ui_testing")
        self.forceOnboardingSnapshot = args.contains("SNAPSHOT_ONBOARDING")
        self.shouldSeedItemLimitReachedData = args.contains("SEED_ITEM_LIMIT_REACHED")
        self.shouldSeedFreeTierData = args.contains("SEED_FREE_TIER")
        self.shouldSeedEmptyHomeData = args.contains("SEED_EMPTY_HOME")
        self.shouldSeedMissingLocalPhotoData = args.contains("SEED_MISSING_LOCAL_PHOTO")
        self.skipSeeding = args.contains("SKIP_SEEDING") || args.contains("SEED_NONE")
        self.cloudKitSettings = CloudKitSyncSettings.resolve(
            arguments: args,
            environment: environment,
            bundlePath: bundlePath,
            isUITesting: isUITesting,
            isRunningTestsOverride: isRunningTests
        )
        self.shouldSeedMockData = !skipSeeding && !forceOnboardingSnapshot && (
            isUITesting
                || args.contains("SEED_MOCK_DATA")
                || shouldSeedItemLimitReachedData
                || shouldSeedFreeTierData
                || shouldSeedEmptyHomeData
                || shouldSeedMissingLocalPhotoData
        )

        if isUITesting, let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.synchronize()
        }
        if forceOnboardingSnapshot {
            hasCompletedOnboarding = false
        }

        let schema = Schema([
            Home.self,
            StorageLocation.self,
            InventoryItem.self
        ])

        let modelConfiguration: ModelConfiguration
        if cloudKitSettings.isInMemory {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else if cloudKitSettings.usesCloudKit {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(CloudKitSyncSettings.containerIdentifier)
            )
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .none
            )
        }

        CloudKitSchemaBootstrapper.initializeIfRequested(
            settings: cloudKitSettings
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            #if DEBUG
            Self.logModelContainerError("Failed to create ModelContainer", error: error)
            if CloudKitStartupPolicy.shouldFallbackToInMemoryAfterContainerError(
                settings: cloudKitSettings
            ) {
                do {
                    let fallbackConfiguration = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true,
                        cloudKitDatabase: .none
                    )
                    modelContainer = try ModelContainer(
                        for: schema,
                        configurations: [fallbackConfiguration]
                    )
                } catch {
                    Self.logModelContainerError("Failed to create fallback ModelContainer", error: error)
                    fatalError("Failed to create fallback ModelContainer: \(error)")
                }
            } else {
                fatalError("STRICT_CLOUDKIT_STARTUP is enabled. Failed to create ModelContainer: \(error)")
            }
            #else
            Self.logModelContainerError("Failed to create ModelContainer with CloudKit, falling back to local-only", error: error)
            do {
                let fallbackConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none
                )
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [fallbackConfiguration]
                )
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
            #endif
        }

        if shouldSeedMockData {
            // Recreate data for UI runs so snapshots and previews have content.
            MockDataGenerator.clearAllData(in: modelContainer.mainContext)
            if shouldSeedItemLimitReachedData {
                MockDataGenerator.generateItemLimitReachedMockData(in: modelContainer.mainContext)
            } else if shouldSeedFreeTierData {
                MockDataGenerator.generateFreeTierMockData(in: modelContainer.mainContext)
            } else if shouldSeedEmptyHomeData {
                MockDataGenerator.generateEmptyHomeMockData(in: modelContainer.mainContext)
            } else if shouldSeedMissingLocalPhotoData {
                MockDataGenerator.generateMissingLocalPhotoMockData(in: modelContainer.mainContext)
            } else {
                MockDataGenerator.generateMockData(in: modelContainer.mainContext)
            }
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }

        let mockSharingMode = DebugMockSharingMode.resolve(
            arguments: args,
            environment: environment
        )
        let resolvedSharedHomesGateService: any SharedHomesGateServiceProtocol
        if mockSharingMode.isEnabled {
            resolvedSharedHomesGateService = SharedHomesGateService(
                arguments: args,
                environment: environment,
                distributionEnabled: true,
                runtimeOverride: true,
                localOverride: true,
                allowLocalOverride: true
            )
            DebugLogger.warning("Running with debug mock sharing mode: \(mockSharingMode)")
        } else {
            resolvedSharedHomesGateService = SharedHomesGateService(
                arguments: args,
                environment: environment
            )
        }
        sharedHomesGateService = resolvedSharedHomesGateService

        var configuredPersistenceController: PersistenceController?
        var configuredRemoteChangeHandler: RemoteChangeHandler?
        var configuredHomeSharingService: (any HomeSharingServiceProtocol)?
        var configuredAppStore: AppStore?
        if FeatureGate.shouldUseCoreDataSharingStack(arguments: args, environment: environment) {
            do {
                let persistenceController = try PersistenceController(
                    inMemory: cloudKitSettings.isInMemory
                )
                let migrationService: DataMigrationService
                if cloudKitSettings.isInMemory || shouldSeedMockData {
                    let sourceContainer = modelContainer
                    migrationService = DataMigrationService(
                        persistenceController: persistenceController,
                        sourceContainerProvider: { .available(sourceContainer) }
                    )
                } else {
                    migrationService = DataMigrationService(
                        persistenceController: persistenceController
                    )
                }
                _ = migrationService.runMigrationIfNeeded()

                let remoteChangeHandler = RemoteChangeHandler(
                    persistenceController: persistenceController
                )
                let resolvedHomeSharingService: (any HomeSharingServiceProtocol)?
                if mockSharingMode.isEnabled {
                    resolvedHomeSharingService = DebugMockHomeSharingService(mode: mockSharingMode)
                } else if resolvedSharedHomesGateService.isEnabled(),
                          PersistenceController.isCoreDataSharingStackEnabled {
                    resolvedHomeSharingService = HomeSharingService(persistenceController: persistenceController)
                } else {
                    resolvedHomeSharingService = nil
                }

                let repository = CoreDataAppRepository(
                    persistenceController: persistenceController,
                    shareService: resolvedHomeSharingService
                )
                configuredAppStore = AppStore(repository: repository)
                configuredPersistenceController = persistenceController
                configuredRemoteChangeHandler = remoteChangeHandler
                configuredHomeSharingService = resolvedHomeSharingService

                #if canImport(UIKit)
                AppDelegate.makeHomeSharingService = {
                    resolvedHomeSharingService
                }
                AppDelegate.makeSharingErrorHandler = {
                    SharingErrorHandler()
                }
                #endif
            } catch {
                DebugLogger.error("Failed to initialize Core Data sharing stack: \(error)")
                #if canImport(UIKit)
                AppDelegate.makeHomeSharingService = { nil }
                AppDelegate.makeSharingErrorHandler = {
                    SharingErrorHandler()
                }
                #endif
            }
        } else {
            #if canImport(UIKit)
            AppDelegate.makeHomeSharingService = { nil }
            AppDelegate.makeSharingErrorHandler = {
                SharingErrorHandler()
            }
            #endif
        }

        coreDataPersistenceController = configuredPersistenceController
        coreDataRemoteChangeHandler = configuredRemoteChangeHandler
        homeSharingService = configuredHomeSharingService
        appStore = configuredAppStore
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let appStore {
                    LaunchContentView(
                        cloudKitSettings: cloudKitSettings,
                        sharedHomesGateService: sharedHomesGateService,
                        homeSharingService: homeSharingService
                    )
                    .environmentObject(appStore)
                } else {
                    RuntimeInitializationFailureView()
                }
            }
            .task {
                coreDataRemoteChangeHandler?.start()

                if cloudKitSettings.usesCloudKit {
                    await CloudKitAvailabilityChecker.logIfUnavailable(
                        forcedAvailability: cloudKitSettings.forcedAvailability
                    )
                }
                if let coreDataPersistenceController {
                    await DataCleanupService.shared.performCleanup(
                        persistenceController: coreDataPersistenceController
                    )
                }
            }
            .onDisappear {
                coreDataRemoteChangeHandler?.stop()
            }
        }
    }
}

private struct LaunchContentView: View {
    let cloudKitSettings: CloudKitSyncSettings
    let sharedHomesGateService: any SharedHomesGateServiceProtocol
    let homeSharingService: (any HomeSharingServiceProtocol)?

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("lastUsedHomeId") private var lastUsedHomeId: String?
    @EnvironmentObject private var appStore: AppStore
    @State private var shouldShowNewHomeSetup = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                homeSearchContainer
            } else if appStore.homes.isEmpty {
                if cloudKitSettings.usesCloudKit && shouldShowNewHomeSetup == false {
                    ExistingHomesRecoveryView {
                        shouldShowNewHomeSetup = true
                    }
                } else {
                    OnboardingView()
                }
            } else {
                RestoringExistingHomeView()
            }
        }
        .onAppear(perform: completeOnboardingIfExistingHomesAreAvailable)
        .onChange(of: appStore.homes) { _, _ in
            completeOnboardingIfExistingHomesAreAvailable()
        }
        .onChange(of: appStore.locations) { _, _ in
            completeOnboardingIfExistingHomesAreAvailable()
        }
        .onChange(of: appStore.items) { _, _ in
            completeOnboardingIfExistingHomesAreAvailable()
        }
    }

    private var homeSearchContainer: some View {
        HomeSearchContainer(
            cloudKitSettings: cloudKitSettings,
            sharedHomesGateService: sharedHomesGateService,
            homeSharingService: homeSharingService
        )
    }

    private func completeOnboardingIfExistingHomesAreAvailable() {
        guard hasCompletedOnboarding == false else { return }
        guard let homeID = HomeLaunchSelectionService.preferredHomeID(
            lastUsedHomeId: lastUsedHomeId,
            homes: appStore.homes,
            locations: appStore.locations,
            items: appStore.items
        ) else {
            return
        }

        lastUsedHomeId = homeID.uuidString
        hasCompletedOnboarding = true
    }
}

private struct ExistingHomesRecoveryView: View {
    let onSetUpNewHome: () -> Void

    @State private var canSetUpNewHome = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)

                    Text("Looking for your homes")
                        .font(.title3.weight(.semibold))

                    Text("Cubby is checking iCloud before starting a new inventory.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if canSetUpNewHome {
                    Button(action: onSetUpNewHome) {
                        Label("Set Up a New Home", systemImage: "house.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 40)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CubbyDesign.Palette.canvas)
        }
        .task {
            guard canSetUpNewHome == false else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            canSetUpNewHome = true
        }
    }

}

private struct RestoringExistingHomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading your homes")
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CubbyDesign.Palette.canvas)
    }
}

private struct RuntimeInitializationFailureView: View {
    var body: some View {
        ContentUnavailableView(
            "Cubby Couldn’t Start",
            systemImage: "exclamationmark.triangle",
            description: Text("The shared-home data stack failed to initialize. Relaunch the app to try again.")
        )
    }
}
