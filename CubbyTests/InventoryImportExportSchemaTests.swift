import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("Inventory Import/Export Schema Tests")
struct InventoryImportExportSchemaTests {
    @Test("Decodes supported import schema version")
    func decodesSupportedImportSchemaVersion() throws {
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "AA Batteries",
                  "locationPath": ["Storage Closet", "Top Shelf"],
                  "description": "AA only",
                  "tags": ["batteries", "household"],
                  "emoji": "🔋"
                }
              ]
            }
            """
        )

        let item = try #require(document.items.first)
        #expect(document.schemaVersion == InventoryImportDocument.supportedSchemaVersion)
        #expect(item.title == "AA Batteries")
        #expect(item.locationPath == ["Storage Closet", "Top Shelf"])
        #expect(item.itemDescription == "AA only")
        #expect(item.tags == ["batteries", "household"])
        #expect(item.emoji == "🔋")
    }

    @Test("Rejects unsupported import schema version")
    func rejectsUnsupportedImportSchemaVersion() throws {
        let data = Data(
            """
            {
              "schemaVersion": "cubby-import-v999",
              "items": []
            }
            """.utf8
        )

        do {
            _ = try JSONDecoder().decode(InventoryImportDocument.self, from: data)
            Issue.record("Unsupported schema version should throw")
        } catch let error as InventoryImportSchemaError {
            #expect(error == .unsupportedSchemaVersion("cubby-import-v999"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Exports selected home context with locations and existing items")
    @MainActor
    func exportsSelectedHomeContextWithLocationsAndExistingItems() throws {
        let fixture = try makeNestedFixture()
        let exportedAt = try #require(ISO8601DateFormatter().date(from: "2026-07-05T12:00:00Z"))

        let document = try InventoryHomeContextExportBuilder.build(
            selectedHomeID: fixture.home.id,
            homes: try fixture.repository.listHomes(),
            locations: try fixture.repository.listLocations(),
            items: try fixture.repository.listItems(),
            exportedAt: exportedAt
        )

        #expect(document.schemaVersion == InventoryHomeExportDocument.schemaVersion)
        #expect(document.exportedAt == exportedAt)
        #expect(document.home.id == fixture.home.id)
        #expect(document.home.name == "Main Home")
        #expect(document.instructions.importSchemaVersion == InventoryImportDocument.supportedSchemaVersion)

        let root = try #require(document.locations.first { $0.name == "Storage Closet" })
        #expect(root.id == fixture.rootLocation.id)
        #expect(root.path == ["Storage Closet"])
        #expect(root.parentLocationId == nil)

        let child = try #require(document.locations.first { $0.name == "Top Shelf" })
        #expect(child.id == fixture.childLocation.id)
        #expect(child.path == ["Storage Closet", "Top Shelf"])
        #expect(child.parentLocationId == fixture.rootLocation.id)

        let item = try #require(document.items.first { $0.title == "AA Batteries" })
        #expect(item.id == fixture.item.id)
        #expect(item.locationPath == ["Storage Closet", "Top Shelf"])
        #expect(item.itemDescription == "AA only")
        #expect(item.tags == ["batteries", "household"])
        #expect(item.emoji == "🔋")
    }
}

@Suite("Inventory Import/Export Planner Tests")
struct InventoryImportExportPlannerTests {
    @Test("Strict location path matching uses the complete path")
    @MainActor
    func strictLocationPathMatchingUsesCompletePath() throws {
        let fixture = try makeNestedFixture()
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "Socket Set",
                  "locationPath": ["Top Shelf"]
                }
              ]
            }
            """
        )

        let plan = try planImport(document, fixture: fixture)

        #expect(plan.blockingErrors.isEmpty)
        #expect(plan.newLocations.map(\.path) == [["Top Shelf"]])
        #expect(plan.newItems.map(\.locationPath) == [["Top Shelf"]])
        #expect(plan.updatedItems.isEmpty)
    }

    @Test("Plans missing locations from item location path")
    @MainActor
    func plansMissingLocationsFromItemLocationPath() throws {
        let fixture = try makeHomeOnlyFixture()
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "Socket Set",
                  "locationPath": ["Garage", "Tool Wall"]
                }
              ]
            }
            """
        )

        let plan = try planImport(document, fixture: fixture)

        #expect(plan.blockingErrors.isEmpty)
        #expect(plan.newLocations.map(\.path) == [
            ["Garage"],
            ["Garage", "Tool Wall"]
        ])
        #expect(plan.newLocations.map(\.parentPath) == [
            nil,
            ["Garage"]
        ])
        #expect(plan.newItems.first?.locationPath == ["Garage", "Tool Wall"])
    }

    @Test("Upsert matches by normalized title plus normalized location path")
    @MainActor
    func upsertMatchesByNormalizedTitleAndLocationPath() throws {
        let fixture = try makeNestedFixture()
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "  aa   batteries  ",
                  "locationPath": [" storage closet ", "top   shelf"],
                  "description": "Updated description"
                }
              ]
            }
            """
        )

        let plan = try planImport(document, fixture: fixture)
        let update = try #require(plan.updatedItems.first)

        #expect(plan.blockingErrors.isEmpty)
        #expect(plan.newLocations.isEmpty)
        #expect(plan.newItems.isEmpty)
        #expect(update.existingItemID == fixture.item.id)
        #expect(update.locationPath == ["Storage Closet", "Top Shelf"])
        #expect(update.proposedDescription == "Updated description")
    }

    @Test("Preserves existing fields when import omits optional fields in update plan")
    @MainActor
    func preservesExistingFieldsWhenImportOmitsOptionalUpdateFields() throws {
        let fixture = try makeNestedFixture()
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "aa batteries",
                  "locationPath": ["Storage Closet", "Top Shelf"]
                }
              ]
            }
            """
        )

        let plan = try planImport(document, fixture: fixture)
        let update = try #require(plan.updatedItems.first)

        #expect(plan.blockingErrors.isEmpty)
        #expect(update.existingItemID == fixture.item.id)
        #expect(update.proposedDescription == "AA only")
        #expect(update.proposedTags == ["batteries", "household"])
        #expect(update.proposedEmoji == "🔋")
    }

    @Test("Null optional fields preserve existing values in update plan")
    @MainActor
    func nullOptionalFieldsPreserveExistingUpdateFields() throws {
        let fixture = try makeNestedFixture()
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "aa batteries",
                  "locationPath": ["Storage Closet", "Top Shelf"],
                  "description": null,
                  "tags": null,
                  "emoji": null
                }
              ]
            }
            """
        )

        let plan = try planImport(document, fixture: fixture)
        let update = try #require(plan.updatedItems.first)

        #expect(plan.blockingErrors.isEmpty)
        #expect(update.proposedDescription == "AA only")
        #expect(update.proposedTags == ["batteries", "household"])
        #expect(update.proposedEmoji == "🔋")
    }

    @Test("Duplicate targets inside import JSON are blocking")
    @MainActor
    func duplicateTargetsInsideImportJSONAreBlocking() throws {
        let fixture = try makeHomeOnlyFixture()
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "AA Batteries",
                  "locationPath": ["Garage"]
                },
                {
                  "title": " aa   batteries ",
                  "locationPath": [" garage "]
                }
              ]
            }
            """
        )

        let plan = try planImport(document, fixture: fixture)

        #expect(plan.blockingErrors.map(\.kind).contains(.duplicateImportTarget))
        #expect(plan.canCommit == false)
    }

    @Test("Ambiguous existing matches in selected home are blocking")
    @MainActor
    func ambiguousExistingMatchesInSelectedHomeAreBlocking() throws {
        let fixture = try makeNestedFixture()
        _ = try fixture.repository.createItem(
            AppItemDraft(
                id: UUID(),
                title: "AA Batteries",
                itemDescription: "Second copy",
                storageLocationID: fixture.childLocation.id,
                tags: [],
                emoji: nil,
                isPendingAiEmoji: false,
                photoFileName: nil
            )
        )
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "aa batteries",
                  "locationPath": ["Storage Closet", "Top Shelf"]
                }
              ]
            }
            """
        )

        let plan = try planImport(document, fixture: fixture)

        #expect(plan.blockingErrors.map(\.kind).contains(.ambiguousExistingMatch))
        #expect(plan.canCommit == false)
    }

    @Test("Validation errors cover title description tags empty path segment and max nesting depth")
    @MainActor
    func validationErrorsCoverImportLimits() throws {
        let fixture = try makeHomeOnlyFixture()
        let tooDeepPath = (0...StorageLocation.maxNestingDepth).map { "Level \($0)" }
        let tooDeepPathJSON = tooDeepPath.map { "\"\($0)\"" }.joined(separator: ", ")
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "",
                  "locationPath": ["Garage"]
                },
                {
                  "title": "Long description",
                  "locationPath": ["Garage"],
                  "description": "\(String(repeating: "d", count: 1001))"
                },
                {
                  "title": "Invalid tags",
                  "locationPath": ["Garage"],
                  "tags": ["!!!"]
                },
                {
                  "title": "Too many tags",
                  "locationPath": ["Garage"],
                  "tags": ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven"]
                },
                {
                  "title": "Empty segment",
                  "locationPath": ["Garage", ""]
                },
                {
                  "title": "Too deep",
                  "locationPath": [\(tooDeepPathJSON)]
                }
              ]
            }
            """
        )

        let plan = try planImport(document, fixture: fixture)
        let validationFields = Set(plan.blockingErrors.compactMap(\.field))

        #expect(validationFields.contains(.title))
        #expect(validationFields.contains(.description))
        #expect(validationFields.contains(.tags))
        #expect(validationFields.contains(.locationPathSegment))
        #expect(validationFields.contains(.nestingDepth))
        #expect(plan.canCommit == false)
    }

    @Test("Dry-run planning does not mutate Core Data or AppStore state")
    @MainActor
    func dryRunPlanningDoesNotMutateCoreDataOrAppStoreState() throws {
        let fixture = try makeNestedFixture()
        let appStore = AppStore(repository: fixture.repository)
        let originalLocations = appStore.locations
        let originalItems = appStore.items
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "aa batteries",
                  "locationPath": ["Storage Closet", "Top Shelf"],
                  "description": "Would update if committed"
                },
                {
                  "title": "Socket Set",
                  "locationPath": ["Garage", "Tool Wall"],
                  "tags": ["tools"]
                }
              ]
            }
            """
        )

        let plan = InventoryImportDryRunPlanner().plan(
            document: document,
            selectedHomeID: fixture.home.id,
            homes: appStore.homes,
            locations: appStore.locations,
            items: appStore.items
        )

        #expect(plan.blockingErrors.isEmpty)
        #expect(plan.updatedItems.count == 1)
        #expect(plan.newLocations.map(\.path) == [
            ["Garage"],
            ["Garage", "Tool Wall"]
        ])
        #expect(plan.newItems.count == 1)

        #expect(try fixture.repository.listLocations() == originalLocations)
        #expect(try fixture.repository.listItems() == originalItems)

        appStore.refresh()
        #expect(appStore.locations == originalLocations)
        #expect(appStore.items == originalItems)
    }
}

@Suite("Inventory Import/Export Commit Tests")
struct InventoryImportExportCommitTests {
    @Test("AppStore commits missing locations and new items")
    @MainActor
    func appStoreCommitsMissingLocationsAndNewItems() throws {
        let fixture = try makeHomeOnlyFixture()
        let appStore = AppStore(repository: fixture.repository, notificationCenter: NotificationCenter())
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "Socket Set",
                  "locationPath": ["Garage", "Tool Wall"],
                  "description": "Metric and SAE",
                  "tags": ["tools"],
                  "emoji": "🔧"
                },
                {
                  "title": "Label Maker",
                  "locationPath": ["Garage", "Tool Wall"],
                  "tags": ["office"]
                }
              ]
            }
            """
        )
        let plan = InventoryImportDryRunPlanner().plan(
            document: document,
            selectedHomeID: fixture.home.id,
            homes: appStore.homes,
            locations: appStore.locations,
            items: appStore.items
        )

        let result = try appStore.commitInventoryImportPlan(plan)

        #expect(result.createdLocationIDs.count == 2)
        #expect(result.createdItemIDs.count == 2)
        #expect(result.updatedItemIDs.isEmpty)
        let garage = try #require(appStore.locations.first { $0.homeID == fixture.home.id && $0.fullPath == "Garage" })
        let toolWall = try #require(appStore.locations.first { $0.homeID == fixture.home.id && $0.fullPath == "Garage > Tool Wall" })
        #expect(toolWall.parentLocationID == garage.id)

        let socketSet = try #require(appStore.items.first { $0.title == "Socket Set" })
        #expect(socketSet.storageLocationID == toolWall.id)
        #expect(socketSet.itemDescription == "Metric and SAE")
        #expect(socketSet.tags == ["tools"])
        #expect(socketSet.emoji == "🔧")
        #expect(socketSet.photoFileName == nil)

        let labelMaker = try #require(appStore.items.first { $0.title == "Label Maker" })
        #expect(labelMaker.storageLocationID == toolWall.id)
        #expect(labelMaker.tags == ["office"])
        #expect(labelMaker.emoji == EmojiPicker.emoji(for: labelMaker.id))
        #expect(labelMaker.photoFileName == nil)
    }

    @Test("Commit updates existing items while preserving photo and omitted emoji state")
    @MainActor
    func commitUpdatesExistingItemWhilePreservingPhotoAndOmittedEmojiState() throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Main Home")
        let location = try #require(try repository.listLocations().first { $0.homeID == home.id })
        let existing = try repository.createItem(
            AppItemDraft(
                id: UUID(),
                title: "Passport",
                itemDescription: "Old note",
                storageLocationID: location.id,
                tags: ["documents"],
                emoji: "🛂",
                isPendingAiEmoji: true,
                photoFileName: "passport-photo.jpg"
            )
        )
        let appStore = AppStore(repository: repository, notificationCenter: NotificationCenter())
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "Passport",
                  "locationPath": ["Unsorted"],
                  "description": "Updated note",
                  "tags": ["travel", "documents"]
                }
              ]
            }
            """
        )
        let plan = InventoryImportDryRunPlanner().plan(
            document: document,
            selectedHomeID: home.id,
            homes: appStore.homes,
            locations: appStore.locations,
            items: appStore.items
        )

        let result = try appStore.commitInventoryImportPlan(plan)

        #expect(result.createdLocationIDs.isEmpty)
        #expect(result.createdItemIDs.isEmpty)
        #expect(result.updatedItemIDs == [existing.id])
        let updated = try #require(appStore.item(id: existing.id))
        #expect(updated.itemDescription == "Updated note")
        #expect(updated.tags == ["documents", "travel"])
        #expect(updated.emoji == "🛂")
        #expect(updated.isPendingAiEmoji)
        #expect(updated.photoFileName == "passport-photo.jpg")
    }

    @Test("Read-only selected home is rejected before writing")
    @MainActor
    func readOnlySelectedHomeIsRejectedBeforeWriting() throws {
        let repository = try makeRepository(
            shareService: DebugMockHomeSharingService(mode: .readOnlyParticipant)
        )
        let home = try repository.createHome(name: "Read Only Home")
        let appStore = AppStore(repository: repository, notificationCenter: NotificationCenter())
        let originalLocations = appStore.locations
        let originalItems = appStore.items
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "Socket Set",
                  "locationPath": ["Garage"]
                }
              ]
            }
            """
        )
        let plan = InventoryImportDryRunPlanner().plan(
            document: document,
            selectedHomeID: home.id,
            homes: appStore.homes,
            locations: appStore.locations,
            items: appStore.items
        )

        #expect(plan.canCommit == false)
        #expect(throws: InventoryImportCommitError.selectedHomeReadOnly) {
            try appStore.commitInventoryImportPlan(plan)
        }
        appStore.refresh()
        #expect(appStore.locations == originalLocations)
        #expect(appStore.items == originalItems)
    }

    @Test("Repository rolls back all changes when commit fails mid-batch")
    @MainActor
    func repositoryRollsBackAllChangesWhenCommitFailsMidBatch() throws {
        let fixture = try makeHomeOnlyFixture()
        let originalLocations = try fixture.repository.listLocations()
        let originalItems = try fixture.repository.listItems()
        let document = try decodeImportDocument(
            """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "Socket Set",
                  "locationPath": ["Garage", "Tool Wall"],
                  "tags": ["tools"]
                }
              ]
            }
            """
        )
        let plan = try planImport(document, fixture: fixture)

        #expect(throws: InventoryImportCommitError.simulatedFailure) {
            try fixture.repository.commitInventoryImportPlan(
                plan,
                testFailureAfterMutationCount: 1
            )
        }
        #expect(try fixture.repository.listLocations() == originalLocations)
        #expect(try fixture.repository.listItems() == originalItems)
    }
}

@MainActor
private struct ImportExportFixture {
    let repository: CoreDataAppRepository
    let home: AppHome
    let rootLocation: AppStorageLocation
    let childLocation: AppStorageLocation
    let item: AppInventoryItem
}

@MainActor
private func makeRepository(
    shareService: (any HomeSharingServiceProtocol)? = nil
) throws -> CoreDataAppRepository {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("InventoryImportExportTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let controller = try PersistenceController(storeDirectory: directory)
    return CoreDataAppRepository(persistenceController: controller, shareService: shareService)
}

@MainActor
private func makeHomeOnlyFixture() throws -> ImportExportFixture {
    let repository = try makeRepository()
    let home = try repository.createHome(name: "Main Home")
    let unsorted = try #require(try repository.listLocations().first { $0.homeID == home.id })
    let item = try repository.createItem(
        AppItemDraft(
            id: UUID(),
            title: "Placeholder",
            itemDescription: nil,
            storageLocationID: unsorted.id,
            tags: [],
            emoji: nil,
            isPendingAiEmoji: false,
            photoFileName: nil
        )
    )
    return ImportExportFixture(
        repository: repository,
        home: home,
        rootLocation: unsorted,
        childLocation: unsorted,
        item: item
    )
}

@MainActor
private func makeNestedFixture() throws -> ImportExportFixture {
    let repository = try makeRepository()
    let home = try repository.createHome(name: "Main Home")
    let root = try repository.createLocation(
        AppLocationCreationDraft(
            name: "Storage Closet",
            homeID: home.id,
            parentLocationID: nil
        )
    )
    let child = try repository.createLocation(
        AppLocationCreationDraft(
            name: "Top Shelf",
            homeID: home.id,
            parentLocationID: root.id
        )
    )
    let item = try repository.createItem(
        AppItemDraft(
            id: UUID(),
            title: "AA Batteries",
            itemDescription: "AA only",
            storageLocationID: child.id,
            tags: ["batteries", "household"],
            emoji: "🔋",
            isPendingAiEmoji: false,
            photoFileName: nil
        )
    )

    return ImportExportFixture(
        repository: repository,
        home: home,
        rootLocation: root,
        childLocation: child,
        item: item
    )
}

private func decodeImportDocument(_ json: String) throws -> InventoryImportDocument {
    try JSONDecoder().decode(InventoryImportDocument.self, from: Data(json.utf8))
}

@MainActor
private func planImport(
    _ document: InventoryImportDocument,
    fixture: ImportExportFixture
) throws -> InventoryImportPlan {
    InventoryImportDryRunPlanner().plan(
        document: document,
        selectedHomeID: fixture.home.id,
        homes: try fixture.repository.listHomes(),
        locations: try fixture.repository.listLocations(),
        items: try fixture.repository.listItems()
    )
}
