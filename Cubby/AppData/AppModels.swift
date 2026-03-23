import Foundation

struct AppHome: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let createdAt: Date
    let modifiedAt: Date
    let isShared: Bool
    let isOwnedByCurrentUser: Bool
    let permission: SharePermission
    let participantSummary: String?
}

struct AppStorageLocation: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let createdAt: Date
    let modifiedAt: Date
    let depth: Int
    let homeID: UUID
    let homeName: String
    let parentLocationID: UUID?
    let fullPath: String
    let childLocationIDs: [UUID]
    let itemCount: Int

    var canDelete: Bool {
        childLocationIDs.isEmpty && itemCount == 0
    }
}

struct AppInventoryItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
    let itemDescription: String?
    let photoFileName: String?
    let emoji: String?
    let isPendingAiEmoji: Bool
    let createdAt: Date
    let modifiedAt: Date
    let tags: [String]
    let homeID: UUID?
    let homeName: String?
    let storageLocationID: UUID?
    let storageLocationName: String?
    let storageLocationPath: String?

    var tagsSet: Set<String> {
        Set(tags)
    }
}

struct AppLocationCreationDraft: Equatable {
    let name: String
    let homeID: UUID
    let parentLocationID: UUID?
}

struct AppItemDraft: Equatable {
    let id: UUID
    let title: String
    let itemDescription: String?
    let storageLocationID: UUID
    let tags: Set<String>
    let emoji: String?
    let isPendingAiEmoji: Bool
    let photoFileName: String?
}

struct AppItemUpdateDraft: Equatable {
    let title: String
    let itemDescription: String?
    let tags: Set<String>
    let photoFileName: String?
    let removePhoto: Bool
}

struct AppDeletedItemSnapshot: Equatable {
    let itemID: UUID
    let storageLocationID: UUID
    let title: String
    let itemDescription: String?
    let photoFileName: String?
    let emoji: String?
    let tags: Set<String>
    let isPendingAiEmoji: Bool
    let createdAt: Date
    let modifiedAt: Date
}
