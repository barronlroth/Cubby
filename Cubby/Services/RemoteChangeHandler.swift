import CoreData
import Foundation

final class RemoteChangeHandler {
    enum NotificationUserInfoKey {
        static let includesPrivateStoreChanges = "includesPrivateStoreChanges"
        static let includesSharedStoreChanges = "includesSharedStoreChanges"
    }

    static let didMergeRemoteChangesNotification = Notification.Name(
        "RemoteChangeHandler.didMergeRemoteChanges"
    )

    private enum StoreScope: Hashable {
        case privateStore
        case sharedStore
    }

    private let persistenceController: PersistenceController
    private let notificationCenter: NotificationCenter
    private let debounceInterval: TimeInterval
    private let callbackQueue: DispatchQueue
    private let onViewContextMerge: (() -> Void)?

    private var observer: NSObjectProtocol?
    private var debounceWorkItem: DispatchWorkItem?
    private var pendingScopes = Set<StoreScope>()
    private let lock = NSLock()

    init(
        persistenceController: PersistenceController,
        notificationCenter: NotificationCenter = .default,
        debounceInterval: TimeInterval = 0.2,
        callbackQueue: DispatchQueue = .main,
        onViewContextMerge: (() -> Void)? = nil
    ) {
        self.persistenceController = persistenceController
        self.notificationCenter = notificationCenter
        self.debounceInterval = debounceInterval
        self.callbackQueue = callbackQueue
        self.onViewContextMerge = onViewContextMerge
    }

    deinit {
        stop()
    }

    func start() {
        guard observer == nil else { return }
        observer = notificationCenter.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: persistenceController.persistentContainer.persistentStoreCoordinator,
            queue: nil
        ) { [weak self] notification in
            self?.handleRemoteChange(notification)
        }
    }

    func stop() {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
        observer = nil

        lock.lock()
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        pendingScopes.removeAll()
        lock.unlock()
    }
}

private extension RemoteChangeHandler {
    private func handleRemoteChange(_ notification: Notification) {
        let scopes = scopesForRemoteChange(notification)
        if scopes.isEmpty {
            return
        }

        lock.lock()
        pendingScopes.formUnion(scopes)
        lock.unlock()
        scheduleDebouncedMerge()
    }

    private func scheduleDebouncedMerge() {
        lock.lock()
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPendingChanges()
        }
        debounceWorkItem = workItem
        lock.unlock()

        callbackQueue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    private func flushPendingChanges() {
        let scopes: Set<StoreScope>
        lock.lock()
        scopes = pendingScopes
        pendingScopes.removeAll()
        debounceWorkItem = nil
        lock.unlock()

        guard scopes.isEmpty == false else { return }

        let includesPrivate = scopes.contains(.privateStore)
        let includesShared = scopes.contains(.sharedStore)
        let viewContext = persistenceController.persistentContainer.viewContext

        viewContext.perform { [weak self] in
            guard let self else { return }
            viewContext.processPendingChanges()
            self.onViewContextMerge?()
            self.notificationCenter.post(
                name: Self.didMergeRemoteChangesNotification,
                object: self,
                userInfo: [
                    NotificationUserInfoKey.includesPrivateStoreChanges: includesPrivate,
                    NotificationUserInfoKey.includesSharedStoreChanges: includesShared
                ]
            )
        }
    }

    private func scopesForRemoteChange(_ notification: Notification) -> Set<StoreScope> {
        var scopes = Set<StoreScope>()

        let userInfo = notification.userInfo ?? [:]
        if let storeURL = userInfo[NSPersistentStoreURLKey] as? URL {
            let normalizedStoreURL = storeURL.standardizedFileURL
            if let privateURL = persistenceController.privatePersistentStore()?.url?.standardizedFileURL,
               privateURL == normalizedStoreURL {
                scopes.insert(.privateStore)
            }
            if let sharedURL = persistenceController.sharedPersistentStore()?.url?.standardizedFileURL,
               sharedURL == normalizedStoreURL {
                scopes.insert(.sharedStore)
            }
        }

        if let storeUUID = userInfo[NSStoreUUIDKey] as? String {
            if let privateStoreUUID = persistenceController.privatePersistentStore()?
                .metadata[NSStoreUUIDKey] as? String,
               privateStoreUUID == storeUUID {
                scopes.insert(.privateStore)
            }
            if let sharedStoreUUID = persistenceController.sharedPersistentStore()?
                .metadata[NSStoreUUIDKey] as? String,
               sharedStoreUUID == storeUUID {
                scopes.insert(.sharedStore)
            }
        }

        if scopes.isEmpty {
            if persistenceController.privatePersistentStore() != nil {
                scopes.insert(.privateStore)
            }
            if persistenceController.sharedPersistentStore() != nil {
                scopes.insert(.sharedStore)
            }
        }

        return scopes
    }
}
