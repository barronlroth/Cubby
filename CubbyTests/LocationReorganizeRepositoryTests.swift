import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("Location Rename and Move Repository Tests")
struct LocationReorganizeRepositoryTests {
    @MainActor
    private func makeRepository(
        shareService: (any HomeSharingServiceProtocol)? = nil
    ) throws -> CoreDataAppRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocationReorganizeRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory)
        return CoreDataAppRepository(persistenceController: controller, shareService: shareService)
    }

    @MainActor
    private func makeLocation(
        _ name: String,
        in homeID: UUID,
        parent: UUID? = nil,
        using repository: CoreDataAppRepository
    ) throws -> AppStorageLocation {
        try repository.createLocation(
            AppLocationCreationDraft(name: name, homeID: homeID, parentLocationID: parent)
        )
    }

    @MainActor
    private func makeItem(
        _ title: String,
        in locationID: UUID,
        using repository: CoreDataAppRepository
    ) throws -> AppInventoryItem {
        try repository.createItem(
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
    }

    /// Builds a straight chain of `count` nested locations and returns them top-down.
    @MainActor
    private func makeChain(
        _ count: Int,
        prefix: String,
        in homeID: UUID,
        under parent: UUID? = nil,
        using repository: CoreDataAppRepository
    ) throws -> [AppStorageLocation] {
        var chain: [AppStorageLocation] = []
        var parentID = parent
        for index in 0..<count {
            let location = try makeLocation("\(prefix) \(index)", in: homeID, parent: parentID, using: repository)
            chain.append(location)
            parentID = location.id
        }
        return chain
    }

    // MARK: Rename

    @Test("Renaming to a sibling's name fails, while a case-only rename succeeds")
    @MainActor
    func renameRejectsDuplicateSiblingButAllowsCaseChange() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        let garage = try makeLocation("Garage", in: home.id, using: repository)
        _ = try makeLocation("Attic", in: home.id, using: repository)

        #expect(throws: AppRepositoryError.duplicateLocationName) {
            try repository.renameLocation(id: garage.id, to: "attic")
        }
        #expect(try repository.location(id: garage.id)?.name == "Garage")

        let renamed = try repository.renameLocation(id: garage.id, to: "  GARAGE ")
        #expect(renamed.name == "GARAGE")
        #expect(renamed.modifiedAt >= garage.modifiedAt)
    }

    @Test("Renaming to an empty name fails and an unchanged name is a no-op")
    @MainActor
    func renameRejectsEmptyName() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        let garage = try makeLocation("Garage", in: home.id, using: repository)

        #expect(throws: AppRepositoryError.invalidName) {
            try repository.renameLocation(id: garage.id, to: "   ")
        }

        let unchanged = try repository.renameLocation(id: garage.id, to: "Garage")
        #expect(unchanged.modifiedAt == garage.modifiedAt)
    }

    @Test("A duplicate name in a different parent is allowed")
    @MainActor
    func renameAllowsSameNameUnderDifferentParent() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        let garage = try makeLocation("Garage", in: home.id, using: repository)
        let attic = try makeLocation("Attic", in: home.id, using: repository)
        _ = try makeLocation("Shelf", in: home.id, parent: garage.id, using: repository)
        let atticBox = try makeLocation("Box", in: home.id, parent: attic.id, using: repository)

        let renamed = try repository.renameLocation(id: atticBox.id, to: "Shelf")
        #expect(renamed.name == "Shelf")
    }

    @Test("Renaming a home trims the name and updates it")
    @MainActor
    func renameHome() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")

        let renamed = try repository.renameHome(id: home.id, to: "  Beach House ")
        #expect(renamed.name == "Beach House")
        #expect(throws: AppRepositoryError.invalidName) {
            try repository.renameHome(id: home.id, to: "")
        }
    }

    // MARK: Move

    @Test("Moving a location into itself or a descendant throws")
    @MainActor
    func moveIntoSelfOrDescendantThrows() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        let chain = try makeChain(3, prefix: "Level", in: home.id, using: repository)

        #expect(throws: AppRepositoryError.invalidMoveTarget) {
            try repository.moveLocation(id: chain[0].id, toParent: chain[0].id)
        }
        #expect(throws: AppRepositoryError.invalidMoveTarget) {
            try repository.moveLocation(id: chain[0].id, toParent: chain[2].id)
        }
        #expect(repository.canMoveLocation(id: chain[0].id, toParent: chain[1].id) == false)
        #expect(try repository.location(id: chain[0].id)?.parentLocationID == nil)
    }

    @Test("Moving a three-level subtree recomputes every depth")
    @MainActor
    func moveRecomputesSubtreeDepth() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        let destination = try makeChain(2, prefix: "Dest", in: home.id, using: repository)
        let subtree = try makeChain(3, prefix: "Sub", in: home.id, using: repository)

        let moved = try repository.moveLocation(id: subtree[0].id, toParent: destination[1].id)

        #expect(moved.parentLocationID == destination[1].id)
        #expect(moved.depth == 2)
        #expect(try repository.location(id: subtree[1].id)?.depth == 3)
        #expect(try repository.location(id: subtree[2].id)?.depth == 4)
        #expect(moved.fullPath == "Dest 0 > Dest 1 > Sub 0")
    }

    @Test("Moving to the top level works")
    @MainActor
    func moveToTopLevel() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        let chain = try makeChain(3, prefix: "Level", in: home.id, using: repository)

        let moved = try repository.moveLocation(id: chain[1].id, toParent: nil)

        #expect(moved.parentLocationID == nil)
        #expect(moved.depth == 0)
        #expect(try repository.location(id: chain[2].id)?.depth == 1)
        #expect(try repository.location(id: chain[0].id)?.childLocationIDs.isEmpty == true)
    }

    @Test("Exceeding the maximum depth throws and saves nothing")
    @MainActor
    func moveBeyondMaxDepthThrows() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        // Depths 0...7: the deepest can hold one more level (8), plus one below it (9).
        let deep = try makeChain(8, prefix: "Deep", in: home.id, using: repository)
        let subtree = try makeChain(3, prefix: "Sub", in: home.id, using: repository)

        #expect(throws: AppRepositoryError.maximumNestingDepthReached) {
            try repository.moveLocation(id: subtree[0].id, toParent: deep[7].id)
        }

        let context = repository.persistenceController.persistentContainer.viewContext
        #expect(context.hasChanges == false)
        #expect(try repository.location(id: subtree[0].id)?.parentLocationID == nil)
        #expect(try repository.location(id: subtree[2].id)?.depth == 2)

        // A two-level subtree fits exactly (depths 8 and 9).
        let fits = try repository.moveLocation(id: subtree[1].id, toParent: deep[7].id)
        #expect(fits.depth == 8)
        #expect(try repository.location(id: subtree[2].id)?.depth == 9)
    }

    @Test("Moving next to a sibling with the same name throws")
    @MainActor
    func moveRejectsDuplicateNameAtTarget() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        let garage = try makeLocation("Garage", in: home.id, using: repository)
        _ = try makeLocation("Shelf", in: home.id, parent: garage.id, using: repository)
        let topShelf = try makeLocation("shelf", in: home.id, using: repository)

        #expect(throws: AppRepositoryError.duplicateLocationName) {
            try repository.moveLocation(id: topShelf.id, toParent: garage.id)
        }
    }

    @Test("Moving a location to another home throws")
    @MainActor
    func crossHomeMoveThrows() throws {
        let repository = try makeRepository()
        let homeA = try repository.createHome(name: "A")
        let homeB = try repository.createHome(name: "B")
        let fromA = try makeLocation("Closet", in: homeA.id, using: repository)
        let inB = try makeLocation("Garage", in: homeB.id, using: repository)

        #expect(throws: AppRepositoryError.invalidMoveTarget) {
            try repository.moveLocation(id: fromA.id, toParent: inB.id)
        }
        #expect(try repository.location(id: fromA.id)?.homeID == homeA.id)
    }

    // MARK: Permissions

    @Test("A read-only participant can't rename or move")
    @MainActor
    func readOnlyParticipantCannotRenameOrMove() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        let garage = try makeLocation("Garage", in: home.id, using: repository)
        let attic = try makeLocation("Attic", in: home.id, using: repository)
        let item = try makeItem("Drill", in: garage.id, using: repository)

        let readOnly = CoreDataAppRepository(
            persistenceController: repository.persistenceController,
            shareService: DebugMockHomeSharingService(mode: .readOnlyParticipant)
        )

        #expect(throws: AppRepositoryError.readOnlyHome) {
            try readOnly.renameLocation(id: garage.id, to: "Shop")
        }
        #expect(throws: AppRepositoryError.readOnlyHome) {
            try readOnly.moveLocation(id: garage.id, toParent: attic.id)
        }
        #expect(throws: AppRepositoryError.readOnlyHome) {
            try readOnly.moveItems(ids: [item.id], to: attic.id)
        }
        #expect(throws: AppRepositoryError.readOnlyHome) {
            try readOnly.renameHome(id: home.id, to: "Mine Now")
        }
        #expect(readOnly.canMoveLocation(id: garage.id, toParent: attic.id) == false)
    }

    @Test("A read-write participant can rename locations but not the home")
    @MainActor
    func readWriteParticipantRenamesLocationsOnly() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        let garage = try makeLocation("Garage", in: home.id, using: repository)

        let collaborator = CoreDataAppRepository(
            persistenceController: repository.persistenceController,
            shareService: DebugMockHomeSharingService(mode: .readWriteParticipant)
        )

        #expect(try collaborator.renameLocation(id: garage.id, to: "Shop").name == "Shop")
        #expect(throws: AppRepositoryError.readOnlyHome) {
            try collaborator.renameHome(id: home.id, to: "Mine Now")
        }
    }

    // MARK: Items

    @Test("moveItems moves every item in one call")
    @MainActor
    func moveItemsMovesAll() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Home")
        let garage = try makeLocation("Garage", in: home.id, using: repository)
        let attic = try makeLocation("Attic", in: home.id, using: repository)
        let shed = try makeLocation("Shed", in: home.id, using: repository)
        let items = [
            try makeItem("Drill", in: garage.id, using: repository),
            try makeItem("Saw", in: garage.id, using: repository),
            try makeItem("Tent", in: shed.id, using: repository)
        ]

        let moved = try repository.moveItems(ids: items.map(\.id), to: attic.id)

        #expect(moved.count == 3)
        #expect(moved.allSatisfy { $0.storageLocationID == attic.id })
        #expect(try repository.location(id: attic.id)?.itemCount == 3)
        #expect(try repository.location(id: garage.id)?.itemCount == 0)
    }

    @Test("moveItems across homes throws and moves nothing")
    @MainActor
    func moveItemsAcrossHomesThrows() throws {
        let repository = try makeRepository()
        let homeA = try repository.createHome(name: "A")
        let homeB = try repository.createHome(name: "B")
        let inA = try makeLocation("Closet", in: homeA.id, using: repository)
        let inB = try makeLocation("Garage", in: homeB.id, using: repository)
        let otherInB = try makeLocation("Shed", in: homeB.id, using: repository)
        let fromA = try makeItem("Coat", in: inA.id, using: repository)
        let fromB = try makeItem("Rake", in: otherInB.id, using: repository)

        #expect(throws: AppRepositoryError.invalidMoveTarget) {
            try repository.moveItems(ids: [fromB.id, fromA.id], to: inB.id)
        }
        #expect(try repository.item(id: fromB.id)?.storageLocationID == otherInB.id)
        #expect(try repository.item(id: fromA.id)?.storageLocationID == inA.id)
    }
}
