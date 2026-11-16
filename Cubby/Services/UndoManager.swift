import Foundation

/// Cubby's undo stack for the toast. Each entry can also be registered with the
/// system `Foundation.UndoManager` so shake-to-undo performs the same action.
@MainActor
class UndoManager: ObservableObject {
    static let shared = UndoManager()

    struct MovedItem: Equatable {
        let id: UUID
        let fromLocationID: UUID
    }

    enum RenameKind: Equatable {
        case home
        case location
    }

    enum Action {
        case itemDeleted(AppDeletedItemSnapshot)
        case itemsDeleted([AppDeletedItemSnapshot])
        case itemsMoved([MovedItem])
        case locationMoved(id: UUID, fromParentID: UUID?)
        case renamed(kind: RenameKind, id: UUID, oldName: String)
    }

    /// Target object for system undo registrations, so one entry's registration
    /// can be removed when the toast performs (or drops) it.
    private final class SystemUndoToken {}

    private struct Entry {
        let id = UUID()
        let action: Action
        let message: String
        let timestamp: Date
        let token = SystemUndoToken()
        weak var systemUndoManager: Foundation.UndoManager?
    }

    @Published private(set) var canUndo = false
    @Published private(set) var timeRemaining: Int = 0
    @Published private(set) var toastMessage: String?
    private var entries: [Entry] = []
    private let maxUndoItems = 10
    private let autoHideDelay: Int = 8 // seconds
    private var autoHideTimer: Timer?

    private init() {}

    func recordDeletion(snapshot: AppDeletedItemSnapshot) {
        record(
            .itemDeleted(snapshot),
            message: "\"\(snapshot.title)\"",
            appStore: nil,
            systemUndoManager: nil
        )
    }

    /// Records a reversible change and shows the toast. When `systemUndoManager`
    /// and `appStore` are supplied, shake-to-undo reverts the same change.
    func record(
        _ action: Action,
        message: String,
        appStore: AppStore?,
        systemUndoManager: Foundation.UndoManager?
    ) {
        var entry = Entry(action: action, message: message, timestamp: Date())
        if let systemUndoManager, let appStore {
            entry.systemUndoManager = systemUndoManager
            let entryID = entry.id
            systemUndoManager.registerUndo(withTarget: entry.token) { [weak self, weak appStore] _ in
                MainActor.assumeIsolated {
                    guard let self, let appStore else { return }
                    _ = self.undo(entryID: entryID, using: appStore)
                }
            }
            systemUndoManager.setActionName(message)
        }

        entries.append(entry)

        if entries.count > maxUndoItems {
            discard(entries.removeFirst())
        }

        canUndo = !entries.isEmpty
        switch action {
        case .itemDeleted, .itemsDeleted:
            // Deletions keep their original "Undo delete …" wording.
            toastMessage = "Undo delete \(message)"
        default:
            toastMessage = "\(message) \u{00B7} Undo"
        }
        startAutoHideTimer()
    }

    func undo(using appStore: AppStore) -> Bool {
        guard let last = entries.last else { return false }
        return undo(entryID: last.id, using: appStore)
    }

    private func undo(entryID: UUID, using appStore: AppStore) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return false }
        let entry = entries.remove(at: index)
        entry.systemUndoManager?.removeAllActions(withTarget: entry.token)

        // Cancel the auto-hide timer since user manually undid
        cancelAutoHideTimer()
        canUndo = false
        toastMessage = nil

        do {
            try perform(entry.action, using: appStore)
            return true
        } catch {
            DebugLogger.error("Failed to undo \(entry.message): \(error)")
            if case .itemDeleted = entry.action, error as? AppRepositoryError != .locationNotFound {
                // A failed restore keeps its snapshot so the user can retry from a later toast.
                entries.insert(entry, at: min(index, entries.count))
            }
            return false
        }
    }

    private func perform(_ action: Action, using appStore: AppStore) throws {
        switch action {
        case .itemDeleted(let snapshot):
            guard appStore.location(id: snapshot.storageLocationID) != nil else {
                throw AppRepositoryError.locationNotFound
            }
            try appStore.restoreDeletedItem(snapshot)
        case .itemsDeleted(let snapshots):
            for snapshot in snapshots where appStore.location(id: snapshot.storageLocationID) != nil {
                try appStore.restoreDeletedItem(snapshot)
            }
        case .itemsMoved(let movedItems):
            let byOrigin = Dictionary(grouping: movedItems, by: \.fromLocationID)
            for (locationID, items) in byOrigin {
                try appStore.moveItems(ids: items.map(\.id), to: locationID)
            }
        case .locationMoved(let id, let fromParentID):
            try appStore.moveLocation(id: id, toParent: fromParentID)
        case .renamed(.location, let id, let oldName):
            try appStore.renameLocation(id: id, to: oldName)
        case .renamed(.home, let id, let oldName):
            try appStore.renameHome(id: id, to: oldName)
        }
    }

    func clearUndoStack() {
        cancelAutoHideTimer()
        entries.forEach(discard)
        entries.removeAll()
        canUndo = false
        toastMessage = nil
    }

    var undoDescription: String? {
        toastMessage
    }

    func dismissUndo() {
        cancelAutoHideTimer()
        canUndo = false
        toastMessage = nil
    }

    private func discard(_ entry: Entry) {
        entry.systemUndoManager?.removeAllActions(withTarget: entry.token)
        let snapshots: [AppDeletedItemSnapshot]
        switch entry.action {
        case .itemDeleted(let snapshot):
            snapshots = [snapshot]
        case .itemsDeleted(let deleted):
            snapshots = deleted
        default:
            snapshots = []
        }
        for photoFileName in snapshots.compactMap(\.photoFileName) {
            Task {
                await PhotoService.shared.deletePhoto(fileName: photoFileName)
            }
        }
    }

    private func startAutoHideTimer() {
        cancelAutoHideTimer()
        timeRemaining = autoHideDelay

        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                self.timeRemaining -= 1

                if self.timeRemaining <= 0 {
                    self.dismissUndo()
                }
            }
        }
    }

    private func cancelAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        timeRemaining = 0
    }
}
