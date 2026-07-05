import Foundation

enum InventoryImportSchemaError: Error, Equatable {
    case unsupportedSchemaVersion(String)
}

struct InventoryImportDocument: Codable, Equatable {
    static let supportedSchemaVersion = "cubby-import-v1"

    let schemaVersion: String
    let items: [InventoryImportItem]

    init(
        schemaVersion: String = Self.supportedSchemaVersion,
        items: [InventoryImportItem]
    ) {
        self.schemaVersion = schemaVersion
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw InventoryImportSchemaError.unsupportedSchemaVersion(schemaVersion)
        }

        self.schemaVersion = schemaVersion
        self.items = try container.decode([InventoryImportItem].self, forKey: .items)
    }
}

struct InventoryImportItem: Codable, Equatable {
    let title: String
    let locationPath: [String]
    let itemDescription: String?
    let tags: [String]?
    let emoji: String?
    let includesDescription: Bool
    let includesTags: Bool
    let includesEmoji: Bool

    init(
        title: String,
        locationPath: [String],
        itemDescription: String? = nil,
        tags: [String]? = nil,
        emoji: String? = nil,
        includesDescription: Bool? = nil,
        includesTags: Bool? = nil,
        includesEmoji: Bool? = nil
    ) {
        self.title = title
        self.locationPath = locationPath
        self.itemDescription = itemDescription
        self.tags = tags
        self.emoji = emoji
        self.includesDescription = includesDescription ?? (itemDescription != nil)
        self.includesTags = includesTags ?? (tags != nil)
        self.includesEmoji = includesEmoji ?? (emoji != nil)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        locationPath = try container.decode([String].self, forKey: .locationPath)
        itemDescription = try container.decodeIfPresent(String.self, forKey: .itemDescription)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)

        let hasDescription = container.contains(.itemDescription)
        let hasTags = container.contains(.tags)
        let hasEmoji = container.contains(.emoji)
        let descriptionIsNil = hasDescription ? try container.decodeNil(forKey: .itemDescription) : true
        let tagsAreNil = hasTags ? try container.decodeNil(forKey: .tags) : true
        let emojiIsNil = hasEmoji ? try container.decodeNil(forKey: .emoji) : true
        includesDescription = hasDescription && !descriptionIsNil
        includesTags = hasTags && !tagsAreNil
        includesEmoji = hasEmoji && !emojiIsNil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(locationPath, forKey: .locationPath)
        if includesDescription {
            try container.encodeIfPresent(itemDescription, forKey: .itemDescription)
        }
        if includesTags {
            try container.encodeIfPresent(tags, forKey: .tags)
        }
        if includesEmoji {
            try container.encodeIfPresent(emoji, forKey: .emoji)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case locationPath
        case itemDescription = "description"
        case tags
        case emoji
    }
}

enum InventoryImportParserError: Error, Equatable {
    case unsupportedSchemaVersion(String)
    case malformedJSON(String)
}

struct InventoryImportParser {
    private let decoder: JSONDecoder

    init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    func parse(data: Data) throws -> InventoryImportDocument {
        do {
            return try decoder.decode(InventoryImportDocument.self, from: data)
        } catch let error as InventoryImportSchemaError {
            switch error {
            case .unsupportedSchemaVersion(let version):
                throw InventoryImportParserError.unsupportedSchemaVersion(version)
            }
        } catch {
            throw InventoryImportParserError.malformedJSON(error.localizedDescription)
        }
    }

    func parse(jsonString: String) throws -> InventoryImportDocument {
        try parse(data: Data(jsonString.utf8))
    }
}

struct InventoryHomeExportDocument: Codable, Equatable {
    static let schemaVersion = "cubby-home-context-v1"

    let schemaVersion: String
    let exportedAt: Date
    let home: InventoryExportHome
    let locations: [InventoryExportLocation]
    let items: [InventoryExportItem]
    let instructions: InventoryExportInstructions

    init(
        schemaVersion: String = Self.schemaVersion,
        exportedAt: Date,
        home: InventoryExportHome,
        locations: [InventoryExportLocation],
        items: [InventoryExportItem],
        instructions: InventoryExportInstructions = InventoryExportInstructions()
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.home = home
        self.locations = locations
        self.items = items
        self.instructions = instructions
    }
}

struct InventoryExportHome: Codable, Equatable {
    let id: UUID
    let name: String
}

struct InventoryExportLocation: Codable, Equatable {
    let id: UUID
    let name: String
    let path: [String]
    let parentLocationId: UUID?
}

struct InventoryExportItem: Codable, Equatable {
    let id: UUID
    let title: String
    let locationPath: [String]
    let itemDescription: String?
    let tags: [String]
    let emoji: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case locationPath
        case itemDescription = "description"
        case tags
        case emoji
    }
}

struct InventoryExportInstructions: Codable, Equatable {
    let importSchemaVersion: String
    let matchingRule: String
    let photos: String

    init(
        importSchemaVersion: String = InventoryImportDocument.supportedSchemaVersion,
        matchingRule: String = "Items match by normalized title plus normalized locationPath in the selected home.",
        photos: String = "Photos are not supported in v1."
    ) {
        self.importSchemaVersion = importSchemaVersion
        self.matchingRule = matchingRule
        self.photos = photos
    }
}

enum InventoryHomeContextExportBuilderError: Error, Equatable {
    case selectedHomeNotFound(UUID)
}

struct InventoryHomeContextExportBuilder {
    static func build(
        selectedHomeID: UUID,
        homes: [AppHome],
        locations: [AppStorageLocation],
        items: [AppInventoryItem],
        exportedAt: Date = Date()
    ) throws -> InventoryHomeExportDocument {
        guard let home = homes.first(where: { $0.id == selectedHomeID }) else {
            throw InventoryHomeContextExportBuilderError.selectedHomeNotFound(selectedHomeID)
        }

        let selectedLocations = locations
            .filter { $0.homeID == selectedHomeID }
            .sorted { lhs, rhs in
                lhs.fullPath.localizedCaseInsensitiveCompare(rhs.fullPath) == .orderedAscending
            }

        let selectedItems = items
            .filter { $0.homeID == selectedHomeID }
            .sorted { lhs, rhs in
                if lhs.storageLocationPath == rhs.storageLocationPath {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return (lhs.storageLocationPath ?? "").localizedCaseInsensitiveCompare(rhs.storageLocationPath ?? "") == .orderedAscending
            }

        return InventoryHomeExportDocument(
            exportedAt: exportedAt,
            home: InventoryExportHome(id: home.id, name: home.name),
            locations: selectedLocations.map { location in
                InventoryExportLocation(
                    id: location.id,
                    name: location.name,
                    path: pathComponents(fromFullPath: location.fullPath),
                    parentLocationId: location.parentLocationID
                )
            },
            items: selectedItems.map { item in
                InventoryExportItem(
                    id: item.id,
                    title: item.title,
                    locationPath: item.storageLocationPath.map(pathComponents(fromFullPath:)) ?? [],
                    itemDescription: item.itemDescription,
                    tags: item.tags,
                    emoji: item.emoji
                )
            }
        )
    }

    static func makeJSONData(from document: InventoryHomeExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    private static func pathComponents(fromFullPath fullPath: String) -> [String] {
        fullPath
            .components(separatedBy: " > ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct InventoryImportPlan: Equatable {
    let selectedHomeID: UUID
    let homeName: String
    let newLocations: [InventoryImportPlannedLocation]
    let newItems: [InventoryImportPlannedItemCreation]
    let updatedItems: [InventoryImportPlannedItemUpdate]
    let unchangedItems: [InventoryImportPlannedUnchangedItem]
    let blockingErrors: [InventoryImportPlanError]

    var canCommit: Bool {
        blockingErrors.isEmpty
    }
}

struct InventoryImportPlannedLocation: Identifiable, Equatable {
    let id: String
    let name: String
    let path: [String]
    let parentPath: [String]?
}

struct InventoryImportPlannedItemCreation: Identifiable, Equatable {
    let id: String
    let title: String
    let locationPath: [String]
    let itemDescription: String?
    let tags: [String]
    let emoji: String?
    let matchedLocationID: UUID?
}

struct InventoryImportPlannedItemUpdate: Identifiable, Equatable {
    let id: String
    let existingItemID: UUID
    let currentTitle: String
    let proposedTitle: String
    let locationPath: [String]
    let currentDescription: String?
    let proposedDescription: String?
    let currentTags: [String]
    let proposedTags: [String]
    let currentEmoji: String?
    let proposedEmoji: String?
}

struct InventoryImportPlannedUnchangedItem: Identifiable, Equatable {
    let id: String
    let existingItemID: UUID
    let title: String
    let locationPath: [String]
}

struct InventoryImportPlanError: Identifiable, Equatable {
    enum Kind: Equatable {
        case selectedHomeNotFound
        case selectedHomeReadOnly
        case validation
        case duplicateImportTarget
        case ambiguousExistingMatch
    }

    enum Field: Hashable {
        case title
        case description
        case tags
        case locationPath
        case locationPathSegment
        case nestingDepth
    }

    let id: String
    let kind: Kind
    let field: Field?
    let itemIndex: Int?
    let message: String
    let path: [String]
    let matchingItemIDs: [UUID]
}

struct InventoryImportCommitResult: Equatable {
    let createdLocationIDs: [UUID]
    let createdItemIDs: [UUID]
    let updatedItemIDs: [UUID]
    let pendingEmojiItemIDs: [UUID]

    init(
        createdLocationIDs: [UUID] = [],
        createdItemIDs: [UUID] = [],
        updatedItemIDs: [UUID] = [],
        pendingEmojiItemIDs: [UUID] = []
    ) {
        self.createdLocationIDs = createdLocationIDs
        self.createdItemIDs = createdItemIDs
        self.updatedItemIDs = updatedItemIDs
        self.pendingEmojiItemIDs = pendingEmojiItemIDs
    }
}

enum InventoryImportCommitError: LocalizedError, Equatable {
    case selectedHomeNotFound
    case selectedHomeReadOnly
    case planHasBlockingErrors([InventoryImportPlanError])
    case locationResolutionFailed([String])
    case itemNotFound(UUID)
    case simulatedFailure

    var errorDescription: String? {
        switch self {
        case .selectedHomeNotFound:
            "The selected home could not be found."
        case .selectedHomeReadOnly:
            "The selected home is read-only."
        case .planHasBlockingErrors:
            "The import plan still has blocking errors."
        case .locationResolutionFailed:
            "A planned location could not be resolved."
        case .itemNotFound:
            "A planned item update could not be resolved."
        case .simulatedFailure:
            "The import failed during the batch."
        }
    }
}

struct InventoryImportDryRunPlanner {
    func plan(
        document: InventoryImportDocument,
        selectedHomeID: UUID,
        homes: [AppHome],
        locations: [AppStorageLocation],
        items: [AppInventoryItem]
    ) -> InventoryImportPlan {
        guard let selectedHome = homes.first(where: { $0.id == selectedHomeID }) else {
            let error = InventoryImportPlanError(
                id: "selected-home-not-found-\(selectedHomeID.uuidString)",
                kind: .selectedHomeNotFound,
                field: nil,
                itemIndex: nil,
                message: "The selected home could not be found.",
                path: [],
                matchingItemIDs: []
            )
            return emptyPlan(selectedHomeID: selectedHomeID, homeName: "", errors: [error])
        }

        guard selectedHome.permission.canMutate else {
            let error = InventoryImportPlanError(
                id: "selected-home-read-only-\(selectedHomeID.uuidString)",
                kind: .selectedHomeReadOnly,
                field: nil,
                itemIndex: nil,
                message: "The selected home is read-only.",
                path: [],
                matchingItemIDs: []
            )
            return emptyPlan(selectedHomeID: selectedHomeID, homeName: selectedHome.name, errors: [error])
        }

        let selectedLocations = locations.filter { $0.homeID == selectedHomeID }
        let selectedItems = items.filter { $0.homeID == selectedHomeID }
        let locationIndex = makeLocationIndex(from: selectedLocations)
        let itemIndex = makeItemIndex(from: selectedItems)

        var errors: [InventoryImportPlanError] = []
        var validatedItems: [ValidatedImportItem] = []

        for (index, item) in document.items.enumerated() {
            let validation = validate(item, index: index)
            errors.append(contentsOf: validation.errors)
            if let value = validation.item {
                validatedItems.append(value)
            }
        }

        var firstImportIndexByTarget: [String: Int] = [:]
        var duplicateImportIndexes = Set<Int>()
        for item in validatedItems {
            if let firstIndex = firstImportIndexByTarget[item.targetKey] {
                duplicateImportIndexes.insert(firstIndex)
                duplicateImportIndexes.insert(item.index)
                errors.append(
                    InventoryImportPlanError(
                        id: "duplicate-import-target-\(firstIndex)-\(item.index)",
                        kind: .duplicateImportTarget,
                        field: nil,
                        itemIndex: item.index,
                        message: "The import contains more than one item with the same title and location path.",
                        path: item.cleanedLocationPath,
                        matchingItemIDs: []
                    )
                )
            } else {
                firstImportIndexByTarget[item.targetKey] = item.index
            }
        }

        var plannedLocationKeys = Set<String>()
        var newLocations: [InventoryImportPlannedLocation] = []
        var newItems: [InventoryImportPlannedItemCreation] = []
        var updatedItems: [InventoryImportPlannedItemUpdate] = []
        var unchangedItems: [InventoryImportPlannedUnchangedItem] = []

        for item in validatedItems where !duplicateImportIndexes.contains(item.index) {
            let matchingExistingItems = itemIndex[item.targetKey] ?? []
            if matchingExistingItems.count > 1 {
                errors.append(
                    InventoryImportPlanError(
                        id: "ambiguous-existing-match-\(item.index)",
                        kind: .ambiguousExistingMatch,
                        field: nil,
                        itemIndex: item.index,
                        message: "The selected home already has multiple matching items for this title and location path.",
                        path: item.cleanedLocationPath,
                        matchingItemIDs: matchingExistingItems.map(\.id)
                    )
                )
                continue
            }

            let resolvedLocation = locationIndex[item.locationPathKey]
            let canonicalLocationPath = resolvedLocation.map { pathComponents(fromFullPath: $0.fullPath) }
                ?? item.cleanedLocationPath

            if resolvedLocation == nil {
                appendMissingLocationPlans(
                    for: item.cleanedLocationPath,
                    existingLocationsByPathKey: locationIndex,
                    plannedLocationKeys: &plannedLocationKeys,
                    newLocations: &newLocations
                )
            }

            if let existingItem = matchingExistingItems.first {
                let proposed = proposedUpdate(for: existingItem, using: item, canonicalLocationPath: canonicalLocationPath)
                if proposed.hasChanges {
                    updatedItems.append(proposed.update)
                } else {
                    unchangedItems.append(
                        InventoryImportPlannedUnchangedItem(
                            id: "unchanged-\(existingItem.id.uuidString)",
                            existingItemID: existingItem.id,
                            title: existingItem.title,
                            locationPath: canonicalLocationPath
                        )
                    )
                }
            } else {
                newItems.append(
                    InventoryImportPlannedItemCreation(
                        id: "create-item-\(item.index)",
                        title: item.cleanedTitle,
                        locationPath: canonicalLocationPath,
                        itemDescription: item.itemDescription,
                        tags: item.tags ?? [],
                        emoji: item.emoji,
                        matchedLocationID: resolvedLocation?.id
                    )
                )
            }
        }

        return InventoryImportPlan(
            selectedHomeID: selectedHomeID,
            homeName: selectedHome.name,
            newLocations: newLocations,
            newItems: newItems,
            updatedItems: updatedItems,
            unchangedItems: unchangedItems,
            blockingErrors: errors
        )
    }
}

private extension InventoryImportDryRunPlanner {
    struct ValidatedImportItem {
        let index: Int
        let cleanedTitle: String
        let normalizedTitle: String
        let cleanedLocationPath: [String]
        let locationPathKey: String
        let itemDescription: String?
        let includesDescription: Bool
        let tags: [String]?
        let includesTags: Bool
        let emoji: String?
        let includesEmoji: Bool

        var targetKey: String {
            InventoryImportDryRunPlanner.targetKey(
                normalizedTitle: normalizedTitle,
                locationPathKey: locationPathKey
            )
        }
    }

    func emptyPlan(
        selectedHomeID: UUID,
        homeName: String,
        errors: [InventoryImportPlanError]
    ) -> InventoryImportPlan {
        InventoryImportPlan(
            selectedHomeID: selectedHomeID,
            homeName: homeName,
            newLocations: [],
            newItems: [],
            updatedItems: [],
            unchangedItems: [],
            blockingErrors: errors
        )
    }

    func validate(
        _ item: InventoryImportItem,
        index: Int
    ) -> (item: ValidatedImportItem?, errors: [InventoryImportPlanError]) {
        var errors: [InventoryImportPlanError] = []

        let cleanedTitle = Self.cleanDisplayString(item.title)
        if cleanedTitle.isEmpty {
            errors.append(validationError(index: index, field: .title, message: "Item title cannot be empty."))
        } else if cleanedTitle.count > 200 {
            errors.append(validationError(index: index, field: .title, message: "Item title must be 200 characters or fewer."))
        }

        var cleanedPath: [String] = []
        if item.locationPath.isEmpty {
            errors.append(validationError(index: index, field: .locationPath, message: "Location path cannot be empty."))
        }

        if item.locationPath.count > StorageLocation.maxNestingDepth {
            errors.append(validationError(index: index, field: .nestingDepth, message: "Location path exceeds the maximum nesting depth."))
        }

        for segment in item.locationPath {
            let cleanedSegment = Self.cleanDisplayString(segment)
            if cleanedSegment.isEmpty {
                errors.append(validationError(index: index, field: .locationPathSegment, message: "Location path segments cannot be empty."))
            } else if cleanedSegment.count > 100 {
                errors.append(validationError(index: index, field: .locationPathSegment, message: "Location path segments must be 100 characters or fewer."))
            }
            cleanedPath.append(cleanedSegment)
        }

        let cleanedDescription = item.itemDescription.map(Self.cleanDisplayString)
        if let cleanedDescription, cleanedDescription.count > 1000 {
            errors.append(validationError(index: index, field: .description, message: "Description must be 1000 characters or fewer."))
        }

        let normalizedTags: [String]?
        if let tags = item.tags {
            if tags.count > TagValidator.maxTags {
                errors.append(validationError(index: index, field: .tags, message: "Items can have at most \(TagValidator.maxTags) tags."))
            }

            let formattedTags = tags.map { $0.formatAsTag(maxLength: .max) }
            for tag in formattedTags {
                if tag.count < TagValidator.minLength || tag.count > TagValidator.maxLength {
                    errors.append(validationError(index: index, field: .tags, message: "Tags must normalize to 1-\(TagValidator.maxLength) characters."))
                    break
                }
            }
            normalizedTags = Array(Set(formattedTags)).sorted()
        } else {
            normalizedTags = nil
        }

        guard errors.isEmpty else {
            return (nil, errors)
        }

        return (
            ValidatedImportItem(
                index: index,
                cleanedTitle: cleanedTitle,
                normalizedTitle: Self.normalizedKeyComponent(cleanedTitle),
                cleanedLocationPath: cleanedPath,
                locationPathKey: Self.locationPathKey(cleanedPath),
                itemDescription: cleanedDescription,
                includesDescription: item.includesDescription,
                tags: normalizedTags,
                includesTags: item.includesTags,
                emoji: item.emoji.map(Self.cleanDisplayString).flatMap { $0.isEmpty ? nil : $0 },
                includesEmoji: item.includesEmoji
            ),
            []
        )
    }

    func validationError(
        index: Int,
        field: InventoryImportPlanError.Field,
        message: String
    ) -> InventoryImportPlanError {
        InventoryImportPlanError(
            id: "validation-\(index)-\(field)",
            kind: .validation,
            field: field,
            itemIndex: index,
            message: message,
            path: [],
            matchingItemIDs: []
        )
    }

    func makeLocationIndex(
        from locations: [AppStorageLocation]
    ) -> [String: AppStorageLocation] {
        locations.reduce(into: [:]) { result, location in
            result[Self.locationPathKey(pathComponents(fromFullPath: location.fullPath))] = location
        }
    }

    func makeItemIndex(
        from items: [AppInventoryItem]
    ) -> [String: [AppInventoryItem]] {
        items.reduce(into: [:]) { result, item in
            guard let storageLocationPath = item.storageLocationPath else { return }
            let key = Self.targetKey(
                normalizedTitle: Self.normalizedKeyComponent(item.title),
                locationPathKey: Self.locationPathKey(pathComponents(fromFullPath: storageLocationPath))
            )
            result[key, default: []].append(item)
        }
    }

    func appendMissingLocationPlans(
        for path: [String],
        existingLocationsByPathKey: [String: AppStorageLocation],
        plannedLocationKeys: inout Set<String>,
        newLocations: inout [InventoryImportPlannedLocation]
    ) {
        var prefix: [String] = []
        for segment in path {
            prefix.append(segment)
            let key = Self.locationPathKey(prefix)
            guard existingLocationsByPathKey[key] == nil,
                  plannedLocationKeys.contains(key) == false else {
                continue
            }

            plannedLocationKeys.insert(key)
            newLocations.append(
                InventoryImportPlannedLocation(
                    id: "create-location-\(key)",
                    name: segment,
                    path: prefix,
                    parentPath: prefix.count > 1 ? Array(prefix.dropLast()) : nil
                )
            )
        }
    }

    func proposedUpdate(
        for existingItem: AppInventoryItem,
        using importItem: ValidatedImportItem,
        canonicalLocationPath: [String]
    ) -> (update: InventoryImportPlannedItemUpdate, hasChanges: Bool) {
        let proposedDescription = importItem.includesDescription
            ? importItem.itemDescription
            : existingItem.itemDescription
        let proposedTags = importItem.includesTags
            ? (importItem.tags ?? [])
            : existingItem.tags
        let proposedEmoji = importItem.includesEmoji
            ? importItem.emoji
            : existingItem.emoji
        let update = InventoryImportPlannedItemUpdate(
            id: "update-\(existingItem.id.uuidString)",
            existingItemID: existingItem.id,
            currentTitle: existingItem.title,
            proposedTitle: importItem.cleanedTitle,
            locationPath: canonicalLocationPath,
            currentDescription: existingItem.itemDescription,
            proposedDescription: proposedDescription,
            currentTags: existingItem.tags,
            proposedTags: proposedTags,
            currentEmoji: existingItem.emoji,
            proposedEmoji: proposedEmoji
        )
        let hasChanges = update.currentTitle != update.proposedTitle
            || update.currentDescription != update.proposedDescription
            || update.currentTags != update.proposedTags
            || update.currentEmoji != update.proposedEmoji
        return (update, hasChanges)
    }

    static func cleanDisplayString(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func normalizedKeyComponent(_ value: String) -> String {
        cleanDisplayString(value).lowercased()
    }

    static func locationPathKey(_ path: [String]) -> String {
        path
            .map(normalizedKeyComponent)
            .map { "\($0.count):\($0)" }
            .joined(separator: "|")
    }

    static func targetKey(normalizedTitle: String, locationPathKey: String) -> String {
        "\(normalizedTitle.count):\(normalizedTitle)|\(locationPathKey)"
    }

    func pathComponents(fromFullPath fullPath: String) -> [String] {
        fullPath
            .components(separatedBy: " > ")
            .map(Self.cleanDisplayString)
            .filter { !$0.isEmpty }
    }
}
