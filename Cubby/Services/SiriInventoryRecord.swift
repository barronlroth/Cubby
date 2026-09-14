import Foundation

/// A value snapshot for system integration. Never carries managed objects or photo paths.
struct SiriInventoryRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let homeID: UUID
    let homeName: String
    let locationPath: String
    let itemDescription: String?
    let tags: [String]
    let emoji: String?

    var fullPath: String {
        [homeName, locationPath].filter { !$0.isEmpty }.joined(separator: " > ")
    }
}

struct SiriNavigationRequest: Identifiable, Equatable {
    enum Destination: Equatable {
        case item(UUID)
        case search(String)
    }

    let id = UUID()
    let destination: Destination
}

enum SiriInventoryError: LocalizedError, Equatable {
    case storageUnavailable
    case deviceLocked
    case subscriptionRequired
    case itemUnavailable

    var errorDescription: String? {
        switch self {
        case .deviceLocked:
            "Unlock your iPhone to search your Cubby inventory."
        case .storageUnavailable:
            "Cubby couldn’t read your inventory. Open Cubby and try again."
        case .subscriptionRequired:
            "Open Cubby to check your Pro subscription before searching your inventory."
        case .itemUnavailable:
            "That item is no longer available in your Cubby inventory."
        }
    }
}
