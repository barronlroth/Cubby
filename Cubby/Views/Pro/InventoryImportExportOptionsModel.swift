import Foundation

enum InventoryImportExportOptionsError: Error, Equatable, LocalizedError {
    case missingSelectedHome
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingSelectedHome:
            "Choose a home before continuing."
        case .exportFailed(let message):
            message
        }
    }
}

struct InventoryImportExportOptionsModel {
    var parser = InventoryImportParser()
    var planner = InventoryImportDryRunPlanner()

    func reviewImport(
        jsonString: String,
        selectedHomeID: UUID?,
        homes: [AppHome],
        locations: [AppStorageLocation],
        items: [AppInventoryItem]
    ) -> InventoryImportReviewSummary {
        guard let selectedHomeID else {
            return InventoryImportReviewSummary.blockingIssue(
                title: "Choose a home before importing.",
                detail: nil
            )
        }

        do {
            let document = try parser.parse(jsonString: jsonString)
            let plan = planner.plan(
                document: document,
                selectedHomeID: selectedHomeID,
                homes: homes,
                locations: locations,
                items: items
            )
            return InventoryImportReviewSummary(plan: plan)
        } catch let error as InventoryImportParserError {
            return InventoryImportReviewSummary.parserError(error)
        } catch {
            return InventoryImportReviewSummary.blockingIssue(
                title: "Import could not be reviewed",
                detail: error.localizedDescription
            )
        }
    }

    func exportJSONString(
        selectedHomeID: UUID?,
        homes: [AppHome],
        locations: [AppStorageLocation],
        items: [AppInventoryItem],
        exportedAt: Date = Date()
    ) throws -> String {
        guard let selectedHomeID else {
            throw InventoryImportExportOptionsError.missingSelectedHome
        }

        let document = try InventoryHomeContextExportBuilder.build(
            selectedHomeID: selectedHomeID,
            homes: homes,
            locations: locations,
            items: items,
            exportedAt: exportedAt
        )
        let data = try InventoryHomeContextExportBuilder.makeJSONData(from: document)

        guard let string = String(data: data, encoding: .utf8) else {
            throw InventoryImportExportOptionsError.exportFailed("Unable to encode export JSON.")
        }

        return string
    }
}

struct InventoryImportReviewSummary: Equatable {
    let homeName: String
    let newLocations: [InventoryImportReviewRow]
    let newItems: [InventoryImportReviewRow]
    let updatedItems: [InventoryImportReviewRow]
    let unchangedItems: [InventoryImportReviewRow]
    let blockingIssues: [InventoryImportReviewIssue]
    let plan: InventoryImportPlan?

    var canConfirm: Bool {
        plan?.canCommit == true
    }

    init(plan: InventoryImportPlan) {
        self.homeName = plan.homeName
        self.newLocations = plan.newLocations.map { location in
            InventoryImportReviewRow(
                id: location.id,
                title: Self.displayPath(location.path),
                detail: location.parentPath.map { "Inside \(Self.displayPath($0))" } ?? "Top-level location"
            )
        }
        self.newItems = plan.newItems.map { item in
            InventoryImportReviewRow(
                id: item.id,
                title: item.title,
                detail: Self.itemDetail(path: item.locationPath, tags: item.tags)
            )
        }
        self.updatedItems = plan.updatedItems.map { item in
            InventoryImportReviewRow(
                id: item.id,
                title: item.currentTitle,
                detail: Self.updateDetail(for: item)
            )
        }
        self.unchangedItems = plan.unchangedItems.map { item in
            InventoryImportReviewRow(
                id: item.id,
                title: item.title,
                detail: Self.displayPath(item.locationPath)
            )
        }
        self.blockingIssues = plan.blockingErrors.map(Self.issueRow(for:))
        self.plan = plan
    }

    private init(
        homeName: String = "",
        newLocations: [InventoryImportReviewRow] = [],
        newItems: [InventoryImportReviewRow] = [],
        updatedItems: [InventoryImportReviewRow] = [],
        unchangedItems: [InventoryImportReviewRow] = [],
        blockingIssues: [InventoryImportReviewIssue],
        plan: InventoryImportPlan? = nil
    ) {
        self.homeName = homeName
        self.newLocations = newLocations
        self.newItems = newItems
        self.updatedItems = updatedItems
        self.unchangedItems = unchangedItems
        self.blockingIssues = blockingIssues
        self.plan = plan
    }

    static func parserError(_ error: InventoryImportParserError) -> InventoryImportReviewSummary {
        switch error {
        case .malformedJSON(let message):
            return blockingIssue(title: "JSON needs fixing", detail: message)
        case .unsupportedSchemaVersion(let version):
            return blockingIssue(
                title: "Unsupported import version",
                detail: "This JSON uses \(version). Use \(InventoryImportDocument.supportedSchemaVersion)."
            )
        }
    }

    static func blockingIssue(title: String, detail: String?) -> InventoryImportReviewSummary {
        InventoryImportReviewSummary(
            blockingIssues: [
                InventoryImportReviewIssue(
                    id: "blocking-\(title)",
                    title: title,
                    detail: detail
                )
            ]
        )
    }

    private static func issueRow(for error: InventoryImportPlanError) -> InventoryImportReviewIssue {
        var detailParts: [String] = []
        if let itemIndex = error.itemIndex {
            detailParts.append("Item \(itemIndex + 1)")
        }
        if !error.path.isEmpty {
            detailParts.append(displayPath(error.path))
        }

        return InventoryImportReviewIssue(
            id: error.id,
            title: error.message,
            detail: detailParts.isEmpty ? nil : detailParts.joined(separator: " - ")
        )
    }

    private static func itemDetail(path: [String], tags: [String]) -> String {
        let pathText = displayPath(path)
        guard !tags.isEmpty else { return pathText }
        return "\(pathText) - Tags: \(tags.joined(separator: ", "))"
    }

    private static func updateDetail(for item: InventoryImportPlannedItemUpdate) -> String {
        var changes: [String] = []
        if item.currentTitle != item.proposedTitle {
            changes.append("title")
        }
        if item.currentDescription != item.proposedDescription {
            changes.append("description")
        }
        if item.currentTags != item.proposedTags {
            changes.append("tags")
        }
        if item.currentEmoji != item.proposedEmoji {
            changes.append("emoji")
        }

        let pathText = displayPath(item.locationPath)
        guard !changes.isEmpty else { return pathText }
        return "\(pathText) - Updates \(changes.joined(separator: ", "))"
    }

    private static func displayPath(_ path: [String]) -> String {
        path.joined(separator: " > ")
    }
}

struct InventoryImportReviewRow: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String?
}

struct InventoryImportReviewIssue: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String?
}
