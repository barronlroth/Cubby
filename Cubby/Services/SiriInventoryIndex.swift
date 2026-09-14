import AppIntents
import CoreSpotlight
import Foundation

@MainActor
protocol SiriInventoryIndexWriting {
    func removeAll() async throws
    func index(_ records: [SiriInventoryRecord]) async throws
}

/// Keep inventory separate from other app indexes and unavailable while the device is locked.
@MainActor
final class SiriInventoryIndex: SiriInventoryIndexWriting {
    private let searchableIndex = CSSearchableIndex(
        name: "CubbyInventory",
        protectionClass: .complete
    )

    func removeAll() async throws {
        try await searchableIndex.deleteAppEntities(ofType: InventoryItemEntity.self)
    }

    func index(_ records: [SiriInventoryRecord]) async throws {
        try await searchableIndex.indexAppEntities(records.map { InventoryItemEntity(record: $0) })
        CubbyAppShortcuts.updateAppShortcutParameters()
    }
}
