import Foundation
import Testing
@testable import Cubby

@Suite("Options Import/Export View Model Tests")
struct OptionsImportExportViewModelTests {
    @Test("Malformed JSON produces a blocking review issue")
    func malformedJSONProducesBlockingReviewIssue() {
        let home = makeHome()
        let model = InventoryImportExportOptionsModel()

        let summary = model.reviewImport(
            jsonString: "{",
            selectedHomeID: home.id,
            homes: [home],
            locations: [],
            items: []
        )

        #expect(summary.canConfirm == false)
        #expect(summary.blockingIssues.map(\.title) == ["JSON needs fixing"])
        #expect(summary.newLocations.isEmpty)
        #expect(summary.newItems.isEmpty)
        #expect(summary.updatedItems.isEmpty)
        #expect(summary.unchangedItems.isEmpty)
    }

    @Test("Unsupported import version produces a blocking review issue")
    func unsupportedImportVersionProducesBlockingReviewIssue() {
        let home = makeHome()
        let model = InventoryImportExportOptionsModel()

        let summary = model.reviewImport(
            jsonString: """
            {
              "schemaVersion": "cubby-import-v999",
              "items": []
            }
            """,
            selectedHomeID: home.id,
            homes: [home],
            locations: [],
            items: []
        )

        #expect(summary.canConfirm == false)
        #expect(summary.blockingIssues.first?.title == "Unsupported import version")
        #expect(summary.blockingIssues.first?.detail?.contains("cubby-import-v999") == true)
    }

    @Test("Blocking planner errors disable confirmation")
    func blockingPlannerErrorsDisableConfirmation() {
        let home = makeHome(permission: SharePermission(role: .readOnlyParticipant))
        let model = InventoryImportExportOptionsModel()

        let summary = model.reviewImport(
            jsonString: """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "Socket Set",
                  "locationPath": ["Garage"]
                }
              ]
            }
            """,
            selectedHomeID: home.id,
            homes: [home],
            locations: [],
            items: []
        )

        #expect(summary.canConfirm == false)
        #expect(summary.blockingIssues.map(\.title) == ["The selected home is read-only."])
    }

    @Test("Successful review summary groups all planner buckets")
    func successfulReviewSummaryGroupsAllPlannerBuckets() throws {
        let home = makeHome()
        let rootLocation = makeLocation(name: "Storage Closet", homeID: home.id, fullPath: "Storage Closet")
        let childLocation = makeLocation(
            name: "Top Shelf",
            homeID: home.id,
            parentLocationID: rootLocation.id,
            fullPath: "Storage Closet > Top Shelf"
        )
        let batteries = makeItem(
            title: "AA Batteries",
            itemDescription: "AA only",
            tags: ["batteries", "household"],
            emoji: "🔋",
            homeID: home.id,
            storageLocationID: childLocation.id,
            storageLocationPath: childLocation.fullPath
        )
        let tapeMeasure = makeItem(
            title: "Tape Measure",
            itemDescription: "25 ft",
            tags: ["tools"],
            emoji: "📏",
            homeID: home.id,
            storageLocationID: childLocation.id,
            storageLocationPath: childLocation.fullPath
        )
        let model = InventoryImportExportOptionsModel()

        let summary = model.reviewImport(
            jsonString: """
            {
              "schemaVersion": "cubby-import-v1",
              "items": [
                {
                  "title": "AA Batteries",
                  "locationPath": ["Storage Closet", "Top Shelf"],
                  "description": "Rechargeables only",
                  "tags": ["batteries", "rechargeable"],
                  "emoji": "🔋"
                },
                {
                  "title": "Socket Set",
                  "locationPath": ["Garage", "Tool Wall"],
                  "tags": ["tools"]
                },
                {
                  "title": "Tape Measure",
                  "locationPath": ["Storage Closet", "Top Shelf"],
                  "description": "25 ft",
                  "tags": ["tools"],
                  "emoji": "📏"
                }
              ]
            }
            """,
            selectedHomeID: home.id,
            homes: [home],
            locations: [rootLocation, childLocation],
            items: [batteries, tapeMeasure]
        )

        #expect(summary.canConfirm)
        #expect(summary.blockingIssues.isEmpty)
        #expect(summary.newLocations.map(\.title) == ["Garage", "Garage > Tool Wall"])
        #expect(summary.newItems.map(\.title) == ["Socket Set"])
        #expect(summary.updatedItems.map(\.title) == ["AA Batteries"])
        #expect(summary.unchangedItems.map(\.title) == ["Tape Measure"])
        #expect(try #require(summary.plan).newItems.count == 1)
    }

    @Test("Export JSON uses selected home context builder")
    func exportJSONUsesSelectedHomeContextBuilder() throws {
        let home = makeHome()
        let location = makeLocation(name: "Garage", homeID: home.id, fullPath: "Garage")
        let item = makeItem(
            title: "Socket Set",
            tags: ["tools"],
            homeID: home.id,
            storageLocationID: location.id,
            storageLocationPath: location.fullPath
        )
        let exportedAt = try #require(ISO8601DateFormatter().date(from: "2026-07-05T12:00:00Z"))
        let model = InventoryImportExportOptionsModel()

        let jsonString = try model.exportJSONString(
            selectedHomeID: home.id,
            homes: [home],
            locations: [location],
            items: [item],
            exportedAt: exportedAt
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(InventoryHomeExportDocument.self, from: Data(jsonString.utf8))

        #expect(document.schemaVersion == InventoryHomeExportDocument.schemaVersion)
        #expect(document.home.id == home.id)
        #expect(document.locations.map(\.path) == [["Garage"]])
        #expect(document.items.map(\.title) == ["Socket Set"])
    }
}

private func makeHome(
    id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    name: String = "Main Home",
    permission: SharePermission = SharePermission(role: .owner)
) -> AppHome {
    AppHome(
        id: id,
        name: name,
        createdAt: referenceDate,
        modifiedAt: referenceDate,
        isShared: permission.role != .owner,
        isOwnedByCurrentUser: permission.role == .owner,
        permission: permission,
        participantSummary: nil
    )
}

private func makeLocation(
    id: UUID = UUID(),
    name: String,
    homeID: UUID,
    parentLocationID: UUID? = nil,
    fullPath: String
) -> AppStorageLocation {
    AppStorageLocation(
        id: id,
        name: name,
        createdAt: referenceDate,
        modifiedAt: referenceDate,
        depth: fullPath.components(separatedBy: " > ").count - 1,
        homeID: homeID,
        homeName: "Main Home",
        parentLocationID: parentLocationID,
        fullPath: fullPath,
        childLocationIDs: [],
        itemCount: 0
    )
}

private func makeItem(
    id: UUID = UUID(),
    title: String,
    itemDescription: String? = nil,
    tags: [String] = [],
    emoji: String? = nil,
    homeID: UUID,
    storageLocationID: UUID,
    storageLocationPath: String
) -> AppInventoryItem {
    AppInventoryItem(
        id: id,
        title: title,
        itemDescription: itemDescription,
        photoFileName: nil,
        emoji: emoji,
        isPendingAiEmoji: false,
        createdAt: referenceDate,
        modifiedAt: referenceDate,
        tags: tags,
        homeID: homeID,
        homeName: "Main Home",
        storageLocationID: storageLocationID,
        storageLocationName: storageLocationPath.components(separatedBy: " > ").last,
        storageLocationPath: storageLocationPath
    )
}

private let referenceDate = Date(timeIntervalSince1970: 1_783_254_400)
