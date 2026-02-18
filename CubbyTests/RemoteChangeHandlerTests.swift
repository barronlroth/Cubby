import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("Remote Change Handler Tests")
struct RemoteChangeHandlerTests {
    private func makeController() throws -> PersistenceController {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RemoteChangeHandlerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try PersistenceController(storeDirectory: directory)
    }

    private func postRemoteChange(
        for store: NSPersistentStore?,
        in controller: PersistenceController,
        notificationCenter: NotificationCenter
    ) {
        notificationCenter.post(
            name: .NSPersistentStoreRemoteChange,
            object: controller.persistentContainer.persistentStoreCoordinator,
            userInfo: [NSPersistentStoreURLKey: store?.url as Any]
        )
    }

    @Test
    func test_remoteChange_notifiesViewContext() async throws {
        let notificationCenter = NotificationCenter()
        let controller = try makeController()
        var mergeCount = 0

        let handler = RemoteChangeHandler(
            persistenceController: controller,
            notificationCenter: notificationCenter,
            debounceInterval: 0.01,
            onViewContextMerge: { mergeCount += 1 }
        )

        handler.start()
        postRemoteChange(
            for: controller.privatePersistentStore(),
            in: controller,
            notificationCenter: notificationCenter
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(mergeCount == 1)
        handler.stop()
    }

    @Test
    func test_remoteChange_mergesChangesFromBothStores() async throws {
        let notificationCenter = NotificationCenter()
        let controller = try makeController()
        var mergeCount = 0
        var latestUserInfo: [AnyHashable: Any] = [:]

        let observer = notificationCenter.addObserver(
            forName: RemoteChangeHandler.didMergeRemoteChangesNotification,
            object: nil,
            queue: nil
        ) { notification in
            latestUserInfo = notification.userInfo ?? [:]
        }

        let handler = RemoteChangeHandler(
            persistenceController: controller,
            notificationCenter: notificationCenter,
            debounceInterval: 0.02,
            onViewContextMerge: { mergeCount += 1 }
        )

        handler.start()
        postRemoteChange(
            for: controller.privatePersistentStore(),
            in: controller,
            notificationCenter: notificationCenter
        )
        postRemoteChange(
            for: controller.sharedPersistentStore(),
            in: controller,
            notificationCenter: notificationCenter
        )

        try? await Task.sleep(nanoseconds: 250_000_000)

        #expect(mergeCount == 1)
        #expect(
            latestUserInfo[RemoteChangeHandler.NotificationUserInfoKey.includesPrivateStoreChanges]
                as? Bool == true
        )
        #expect(
            latestUserInfo[RemoteChangeHandler.NotificationUserInfoKey.includesSharedStoreChanges]
                as? Bool == true
        )

        notificationCenter.removeObserver(observer)
        handler.stop()
    }

    @Test
    func test_remoteChange_handlesPrivateStoreUpdates() async throws {
        let notificationCenter = NotificationCenter()
        let controller = try makeController()
        var latestUserInfo: [AnyHashable: Any] = [:]

        let observer = notificationCenter.addObserver(
            forName: RemoteChangeHandler.didMergeRemoteChangesNotification,
            object: nil,
            queue: nil
        ) { notification in
            latestUserInfo = notification.userInfo ?? [:]
        }

        let handler = RemoteChangeHandler(
            persistenceController: controller,
            notificationCenter: notificationCenter,
            debounceInterval: 0.01
        )

        handler.start()
        postRemoteChange(
            for: controller.privatePersistentStore(),
            in: controller,
            notificationCenter: notificationCenter
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(
            latestUserInfo[RemoteChangeHandler.NotificationUserInfoKey.includesPrivateStoreChanges]
                as? Bool == true
        )
        #expect(
            latestUserInfo[RemoteChangeHandler.NotificationUserInfoKey.includesSharedStoreChanges]
                as? Bool == false
        )

        notificationCenter.removeObserver(observer)
        handler.stop()
    }

    @Test
    func test_remoteChange_handlesSharedStoreUpdates() async throws {
        let notificationCenter = NotificationCenter()
        let controller = try makeController()
        var latestUserInfo: [AnyHashable: Any] = [:]

        let observer = notificationCenter.addObserver(
            forName: RemoteChangeHandler.didMergeRemoteChangesNotification,
            object: nil,
            queue: nil
        ) { notification in
            latestUserInfo = notification.userInfo ?? [:]
        }

        let handler = RemoteChangeHandler(
            persistenceController: controller,
            notificationCenter: notificationCenter,
            debounceInterval: 0.01
        )

        handler.start()
        postRemoteChange(
            for: controller.sharedPersistentStore(),
            in: controller,
            notificationCenter: notificationCenter
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(
            latestUserInfo[RemoteChangeHandler.NotificationUserInfoKey.includesPrivateStoreChanges]
                as? Bool == false
        )
        #expect(
            latestUserInfo[RemoteChangeHandler.NotificationUserInfoKey.includesSharedStoreChanges]
                as? Bool == true
        )

        notificationCenter.removeObserver(observer)
        handler.stop()
    }
}
