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

        let didMerge = await waitUntil {
            mergeCount == 1
        }

        #expect(didMerge)
        #expect(mergeCount == 1)
        handler.stop()
    }

    @Test
    func test_remoteChange_mergesChangesFromBothStores() async throws {
        let notificationCenter = NotificationCenter()
        let controller = try makeController()
        var mergeCount = 0
        let notificationCapture = RemoteChangeCapture()

        let observer = notificationCenter.addObserver(
            forName: RemoteChangeHandler.didMergeRemoteChangesNotification,
            object: nil,
            queue: nil
        ) { notification in
            notificationCapture.record(notification.userInfo ?? [:])
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

        let didMergeBothStores = await waitUntil {
            mergeCount == 1 &&
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesPrivateStoreChanges
            ) == true &&
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesSharedStoreChanges
            ) == true
        }

        #expect(didMergeBothStores)
        #expect(mergeCount == 1)
        #expect(
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesPrivateStoreChanges
            ) == true
        )
        #expect(
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesSharedStoreChanges
            ) == true
        )

        notificationCenter.removeObserver(observer)
        handler.stop()
    }

    @Test
    func test_remoteChange_handlesPrivateStoreUpdates() async throws {
        let notificationCenter = NotificationCenter()
        let controller = try makeController()
        let notificationCapture = RemoteChangeCapture()

        let observer = notificationCenter.addObserver(
            forName: RemoteChangeHandler.didMergeRemoteChangesNotification,
            object: nil,
            queue: nil
        ) { notification in
            notificationCapture.record(notification.userInfo ?? [:])
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

        let didMergePrivateStore = await waitUntil {
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesPrivateStoreChanges
            ) == true &&
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesSharedStoreChanges
            ) == false
        }

        #expect(didMergePrivateStore)
        #expect(
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesPrivateStoreChanges
            ) == true
        )
        #expect(
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesSharedStoreChanges
            ) == false
        )

        notificationCenter.removeObserver(observer)
        handler.stop()
    }

    @Test
    func test_remoteChange_handlesSharedStoreUpdates() async throws {
        let notificationCenter = NotificationCenter()
        let controller = try makeController()
        let notificationCapture = RemoteChangeCapture()

        let observer = notificationCenter.addObserver(
            forName: RemoteChangeHandler.didMergeRemoteChangesNotification,
            object: nil,
            queue: nil
        ) { notification in
            notificationCapture.record(notification.userInfo ?? [:])
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

        let didMergeSharedStore = await waitUntil {
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesPrivateStoreChanges
            ) == false &&
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesSharedStoreChanges
            ) == true
        }

        #expect(didMergeSharedStore)
        #expect(
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesPrivateStoreChanges
            ) == false
        )
        #expect(
            notificationCapture.bool(
                for: RemoteChangeHandler.NotificationUserInfoKey.includesSharedStoreChanges
            ) == true
        )

        notificationCenter.removeObserver(observer)
        handler.stop()
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        condition: () -> Bool
    ) async -> Bool {
        let start = ContinuousClock.now
        let timeout = Duration.nanoseconds(Int64(timeoutNanoseconds))

        while ContinuousClock.now - start < timeout {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        return condition()
    }

    private final class RemoteChangeCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var userInfo: [AnyHashable: Any] = [:]

        func record(_ userInfo: [AnyHashable: Any]) {
            lock.lock()
            self.userInfo = userInfo
            lock.unlock()
        }

        func bool(for key: String) -> Bool? {
            lock.lock()
            defer { lock.unlock() }
            return userInfo[key] as? Bool
        }
    }
}
