import Foundation
import Testing
@testable import Cubby

@Suite("App Store Recovery Tests")
struct AppStoreRecoveryTests {
    @MainActor
    private func makeRepository() throws -> CoreDataAppRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStoreRecoveryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory)
        return CoreDataAppRepository(
            persistenceController: controller,
            shareService: nil
        )
    }

    @Test("Migration recovery notification updates app state and refreshes")
    @MainActor
    func testMigrationRecoveryNotificationUpdatesMessageAndRefreshes() async throws {
        let repository = try makeRepository()
        let notificationCenter = NotificationCenter()
        let appStore = AppStore(repository: repository, notificationCenter: notificationCenter)

        let home = try repository.createHome(name: "Recovered Home")
        #expect(appStore.recoveryMessage == nil)
        #expect(appStore.homes.isEmpty)

        notificationCenter.post(
            name: DataMigrationService.didRequestRecoveryNotification,
            object: nil,
            userInfo: [
                DataMigrationService.recoveryMessageUserInfoKey: DataMigrationService.recoveryMessage
            ]
        )

        let didRefresh = await waitUntil {
            appStore.recoveryMessage == DataMigrationService.recoveryMessage
                && appStore.homes.contains { $0.id == home.id }
        }
        #expect(didRefresh)
    }

    @MainActor
    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let interval: UInt64 = 20_000_000
        var elapsed: UInt64 = 0

        while elapsed < timeoutNanoseconds {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: interval)
            elapsed += interval
        }

        return condition()
    }
}
