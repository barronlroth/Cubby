import Foundation
import Testing
@testable import Cubby

/// Uses the shared undo stack, so the cases run one at a time.
@Suite("Reorganize Undo Tests", .serialized)
struct ReorganizeUndoTests {
    @MainActor
    private func makeStore() throws -> AppStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReorganizeUndoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory)
        let repository = CoreDataAppRepository(persistenceController: controller, shareService: nil)
        let defaults = try #require(UserDefaults(suiteName: "ReorganizeUndoTests-\(UUID().uuidString)"))
        return AppStore(
            repository: repository,
            hiddenSharedHomeIDStore: HiddenSharedHomeIDStore(userDefaults: defaults)
        )
    }

    @MainActor
    private func makeItem(_ title: String, in locationID: UUID, store: AppStore) throws -> AppInventoryItem {
        let item = try store.repository.createItem(
            AppItemDraft(
                id: UUID(),
                title: title,
                itemDescription: nil,
                storageLocationID: locationID,
                tags: [],
                emoji: "📦",
                isPendingAiEmoji: false,
                photoFileName: nil
            )
        )
        store.refresh()
        return item
    }

    @Test("Undoing a location move restores its parent and shows one toast")
    @MainActor
    func undoLocationMove() throws {
        let undo = UndoManager.shared
        undo.clearUndoStack()
        defer { undo.clearUndoStack() }

        let store = try makeStore()
        let home = try store.createHome(name: "Home")
        let office = try store.createLocation(name: "Office", homeID: home.id, parentLocationID: nil)
        let desk = try store.createLocation(name: "Desk", homeID: home.id, parentLocationID: office.id)
        let closet = try store.createLocation(name: "Hall Closet", homeID: home.id, parentLocationID: nil)

        try InventoryReorganizer.moveLocation(desk, toParent: closet.id, appStore: store, systemUndoManager: nil)

        #expect(store.location(id: desk.id)?.parentLocationID == closet.id)
        #expect(undo.canUndo)
        #expect(undo.undoDescription == "Moved Desk to Hall Closet \u{00B7} Undo")

        #expect(undo.undo(using: store))
        #expect(store.location(id: desk.id)?.parentLocationID == office.id)
        #expect(store.location(id: desk.id)?.depth == 1)
        #expect(undo.canUndo == false)
    }

    @Test("Undoing a batch item move returns each item to its own location")
    @MainActor
    func undoItemsMove() throws {
        let undo = UndoManager.shared
        undo.clearUndoStack()
        defer { undo.clearUndoStack() }

        let store = try makeStore()
        let home = try store.createHome(name: "Home")
        let garage = try store.createLocation(name: "Garage", homeID: home.id, parentLocationID: nil)
        let shed = try store.createLocation(name: "Shed", homeID: home.id, parentLocationID: nil)
        let attic = try store.createLocation(name: "Attic", homeID: home.id, parentLocationID: nil)
        let drill = try makeItem("Drill", in: garage.id, store: store)
        let rake = try makeItem("Rake", in: shed.id, store: store)

        try InventoryReorganizer.moveItems([drill.id, rake.id], to: attic.id, appStore: store, systemUndoManager: nil)
        #expect(undo.undoDescription == "Moved 2 items to Attic \u{00B7} Undo")
        #expect(store.item(id: drill.id)?.storageLocationID == attic.id)

        #expect(undo.undo(using: store))
        #expect(store.item(id: drill.id)?.storageLocationID == garage.id)
        #expect(store.item(id: rake.id)?.storageLocationID == shed.id)
    }

    @Test("Undoing a rename restores the old name")
    @MainActor
    func undoRename() throws {
        let undo = UndoManager.shared
        undo.clearUndoStack()
        defer { undo.clearUndoStack() }

        let store = try makeStore()
        let home = try store.createHome(name: "Home")
        let garage = try store.createLocation(name: "Garage", homeID: home.id, parentLocationID: nil)

        try InventoryReorganizer.renameLocation(id: garage.id, to: "Workshop", appStore: store, systemUndoManager: nil)
        #expect(store.location(id: garage.id)?.name == "Workshop")

        #expect(undo.undo(using: store))
        #expect(store.location(id: garage.id)?.name == "Garage")

        try InventoryReorganizer.renameHome(id: home.id, to: "Cabin", appStore: store, systemUndoManager: nil)
        #expect(undo.undo(using: store))
        #expect(store.home(id: home.id)?.name == "Home")
    }

    @Test("The system undo manager performs the same undo and clears the toast")
    @MainActor
    func systemUndoPerformsRecordedAction() throws {
        let undo = UndoManager.shared
        undo.clearUndoStack()
        defer { undo.clearUndoStack() }

        let store = try makeStore()
        let home = try store.createHome(name: "Home")
        let garage = try store.createLocation(name: "Garage", homeID: home.id, parentLocationID: nil)
        let systemUndo = Foundation.UndoManager()
        systemUndo.groupsByEvent = false

        systemUndo.beginUndoGrouping()
        try InventoryReorganizer.renameLocation(id: garage.id, to: "Shop", appStore: store, systemUndoManager: systemUndo)
        systemUndo.endUndoGrouping()
        #expect(systemUndo.canUndo)

        systemUndo.undo()
        #expect(store.location(id: garage.id)?.name == "Garage")
        #expect(undo.canUndo == false)

        // Undoing from the toast instead removes the system registration.
        systemUndo.beginUndoGrouping()
        try InventoryReorganizer.renameLocation(id: garage.id, to: "Shop", appStore: store, systemUndoManager: systemUndo)
        systemUndo.endUndoGrouping()
        #expect(undo.undo(using: store))
        #expect(systemUndo.canUndo == false)
    }
}
