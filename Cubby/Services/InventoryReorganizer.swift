import Foundation

/// Performs rename and move changes through `AppStore`, then records them with the
/// shared undo toast (and the system undo manager, for shake-to-undo).
@MainActor
enum InventoryReorganizer {
    @discardableResult
    static func moveLocation(
        _ location: AppStorageLocation,
        toParent parentID: UUID?,
        appStore: AppStore,
        systemUndoManager: Foundation.UndoManager?,
        undoManager: UndoManager? = nil
    ) throws -> AppStorageLocation {
        let fromParentID = (appStore.location(id: location.id) ?? location).parentLocationID
        let moved = try appStore.moveLocation(id: location.id, toParent: parentID)
        guard fromParentID != parentID else { return moved }

        let destinationName = parentID.flatMap { appStore.location(id: $0)?.name }
        let message = destinationName.map { "Moved \(moved.name) to \($0)" }
            ?? "Moved \(moved.name) to the top level"
        (undoManager ?? .shared).record(
            .locationMoved(id: location.id, fromParentID: fromParentID),
            message: message,
            appStore: appStore,
            systemUndoManager: systemUndoManager
        )
        CubbyDesign.Haptics.play(.success)
        return moved
    }

    static func moveItems(
        _ itemIDs: [UUID],
        to locationID: UUID,
        appStore: AppStore,
        systemUndoManager: Foundation.UndoManager?,
        undoManager: UndoManager? = nil
    ) throws {
        let origins: [UndoManager.MovedItem] = itemIDs.compactMap { id in
            guard let item = appStore.item(id: id),
                  let from = item.storageLocationID,
                  from != locationID else { return nil }
            return UndoManager.MovedItem(id: id, fromLocationID: from)
        }
        guard !origins.isEmpty else { return }

        let titles = origins.compactMap { appStore.item(id: $0.id)?.title }
        try appStore.moveItems(ids: origins.map(\.id), to: locationID)

        let destinationName = appStore.location(id: locationID)?.name ?? "location"
        let subject = origins.count == 1 ? (titles.first ?? "1 item") : "\(origins.count) items"
        (undoManager ?? .shared).record(
            .itemsMoved(origins),
            message: "Moved \(subject) to \(destinationName)",
            appStore: appStore,
            systemUndoManager: systemUndoManager
        )
        CubbyDesign.Haptics.play(.success)
    }

    static func renameLocation(
        id: UUID,
        to name: String,
        appStore: AppStore,
        systemUndoManager: Foundation.UndoManager?,
        undoManager: UndoManager? = nil
    ) throws {
        guard let oldName = appStore.location(id: id)?.name else {
            throw AppRepositoryError.locationNotFound
        }
        let renamed = try appStore.renameLocation(id: id, to: name)
        guard renamed.name != oldName else { return }
        (undoManager ?? .shared).record(
            .renamed(kind: .location, id: id, oldName: oldName),
            message: "Renamed \(oldName) to \(renamed.name)",
            appStore: appStore,
            systemUndoManager: systemUndoManager
        )
    }

    @discardableResult
    static func renameHome(
        id: UUID,
        to name: String,
        appStore: AppStore,
        systemUndoManager: Foundation.UndoManager?,
        undoManager: UndoManager? = nil
    ) throws -> AppHome {
        guard let oldName = appStore.home(id: id)?.name else {
            throw AppRepositoryError.homeNotFound
        }
        let renamed = try appStore.renameHome(id: id, to: name)
        guard renamed.name != oldName else { return renamed }
        (undoManager ?? .shared).record(
            .renamed(kind: .home, id: id, oldName: oldName),
            message: "Renamed \(oldName) to \(renamed.name)",
            appStore: appStore,
            systemUndoManager: systemUndoManager
        )
        return renamed
    }
}
