import CoreData
import Foundation

/// Keeps the most recent `NSPersistentCloudKitContainer` events in memory (and
/// logs each one) so sharing problems can be diagnosed on device.
final class CloudKitEventLog: ObservableObject, @unchecked Sendable {
    struct Entry: Identifiable, Equatable {
        enum Kind: String {
            case setup, `import`, export, unknown
        }

        let id: UUID
        let kind: Kind
        let store: String
        let startDate: Date
        let endDate: Date?
        let succeeded: Bool
        let errorDescription: String?

        var isFinished: Bool { endDate != nil }
    }

    static let shared = CloudKitEventLog()

    @MainActor @Published private(set) var entries: [Entry] = []

    let capacity: Int
    private var observer: NSObjectProtocol?
    private let lock = NSLock()

    init(capacity: Int = 200) {
        self.capacity = capacity
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Starts observing a container's events; later calls are ignored.
    func start(observing container: NSPersistentCloudKitContainer, storeLabel: @escaping (String) -> String) {
        lock.lock()
        defer { lock.unlock() }
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: nil
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else {
                return
            }
            let entry = Entry(
                id: event.identifier,
                kind: Self.kind(for: event.type),
                store: storeLabel(event.storeIdentifier),
                startDate: event.startDate,
                endDate: event.endDate,
                succeeded: event.succeeded,
                errorDescription: event.error.map { String(describing: $0) }
            )
            Self.log(entry)
            Task { @MainActor [weak self] in
                self?.record(entry)
            }
        }
    }

    /// Adds or updates an entry (an event is reported at start and at end).
    @MainActor
    func record(_ entry: Entry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.insert(entry, at: 0)
            if entries.count > capacity {
                entries.removeLast(entries.count - capacity)
            }
        }
    }

    private static func kind(for type: NSPersistentCloudKitContainer.EventType) -> Entry.Kind {
        switch type {
        case .setup: .setup
        case .import: .import
        case .export: .export
        @unknown default: .unknown
        }
    }

    private static func log(_ entry: Entry) {
        let phase = entry.isFinished ? (entry.succeeded ? "succeeded" : "failed") : "started"
        let message = "CloudKit \(entry.kind.rawValue) [\(entry.store)] \(phase)"
            + (entry.errorDescription.map { ": \($0)" } ?? "")
        if entry.isFinished && !entry.succeeded {
            DebugLogger.error(message)
        } else {
            DebugLogger.info(message)
        }
    }
}
