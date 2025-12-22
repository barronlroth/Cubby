import Foundation
import SwiftData

@MainActor
enum StorageLocationDeletionError: LocalizedError, Equatable {
    case locationNotFound
    case hasChildren(Int)
    case hasItems(Int)
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .locationNotFound:
            "This location no longer exists."
        case .hasChildren(let count):
            "This location can’t be deleted because it has \(count) sublocation\(count == 1 ? "" : "s")."
        case .hasItems(let count):
            "This location can’t be deleted because it contains \(count) item\(count == 1 ? "" : "s")."
        case .saveFailed:
            "Couldn’t save changes. Please try again."
        }
    }
}

@MainActor
struct StorageLocationDeletionService {
    static func deleteLocationIfAllowed(locationId: UUID, modelContext: ModelContext) throws {
        let childCountDescriptor = FetchDescriptor<StorageLocation>(
            predicate: #Predicate { $0.parentLocation?.id == locationId }
        )
        let childCount = try modelContext.fetchCount(childCountDescriptor)
        guard childCount == 0 else {
            throw StorageLocationDeletionError.hasChildren(childCount)
        }

        let itemCountDescriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate { $0.storageLocation?.id == locationId }
        )
        let itemCount = try modelContext.fetchCount(itemCountDescriptor)
        guard itemCount == 0 else {
            throw StorageLocationDeletionError.hasItems(itemCount)
        }

        let locationDescriptor = FetchDescriptor<StorageLocation>(
            predicate: #Predicate { $0.id == locationId }
        )
        guard let location = try modelContext.fetch(locationDescriptor).first else {
            throw StorageLocationDeletionError.locationNotFound
        }

        modelContext.delete(location)

        do {
            try modelContext.save()
        } catch {
            throw StorageLocationDeletionError.saveFailed
        }
    }
}

