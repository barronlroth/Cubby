import AppIntents
import CoreSpotlight
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A saved inventory record exposed to system search. The repository remains authoritative.
struct InventoryItemEntity: IndexedEntity, Transferable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Inventory Item"
    static let defaultQuery = InventoryItemQuery()

    let id: UUID
    let homeID: UUID

    @Property(title: "Name") var title: String
    @Property(title: "Home") var homeName: String
    @Property(title: "Location") var locationPath: String
    @Property(title: "Description") var itemDescription: String?
    @Property(title: "Tags") var tags: [String]

    var fullPath: String {
        [homeName, locationPath].filter { !$0.isEmpty }.joined(separator: " > ")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(fullPath)",
            image: .init(systemName: "shippingbox")
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = title
        attributes.contentDescription = [fullPath, itemDescription]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        attributes.keywords = tags
        return attributes
    }

    /// Export only a human-readable summary; importing text never creates inventory.
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { (item: InventoryItemEntity) in
            let current = try await SiriInventoryService.shared.locateItem(id: item.id)
            return Data("\(current.title): \(current.fullPath)".utf8)
        }
    }

    init(record: SiriInventoryRecord) {
        id = record.id
        homeID = record.homeID
        title = record.title
        homeName = record.homeName
        locationPath = record.locationPath
        itemDescription = record.itemDescription
        tags = record.tags
    }
}

struct InventoryItemQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [InventoryItemEntity] {
        try await SiriInventoryService.shared.entities(for: identifiers)
            .map { InventoryItemEntity(record: $0) }
    }

    func entities(matching string: String) async throws -> [InventoryItemEntity] {
        try await SiriInventoryService.shared.entities(matching: string)
            .map { InventoryItemEntity(record: $0) }
    }

    func suggestedEntities() async throws -> [InventoryItemEntity] {
        try await SiriInventoryService.shared.suggestedEntities()
            .map { InventoryItemEntity(record: $0) }
    }
}

#if compiler(>=6.4)
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension InventoryItemQuery: IndexedEntityQuery {
    func reindexEntities(
        for identifiers: [UUID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        try await reindexAllEntities(indexDescription: indexDescription)
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        // The shipping SDK exposes protectionClass, not the index name. Cubby has
        // one entity index; never recreate its contents in a less protected index.
        guard indexDescription.protectionClass == .complete else {
            throw SiriInventoryIndexError.unsupportedProtectionClass
        }
        try await SiriInventoryService.shared.reindexForSystemRequest()
    }
}
#endif
