import Foundation
import SwiftData

@MainActor
enum GateReason: Equatable {
    case homeLimitReached
    case itemLimitReached
    case overLimit
}

@MainActor
struct GateResult: Equatable {
    let isAllowed: Bool
    let reason: GateReason?

    static let allowed = GateResult(isAllowed: true, reason: nil)

    static func denied(_ reason: GateReason) -> GateResult {
        GateResult(isAllowed: false, reason: reason)
    }
}

@MainActor
struct FeatureGate {
    static let freeMaxHomes = 1
    static let freeMaxItemsPerHome = 10

    static func canCreateHome(modelContext: ModelContext, isPro: Bool) -> GateResult {
        guard !isPro else { return .allowed }

        let homeCountDescriptor = FetchDescriptor<Home>()
        let homeCount = (try? modelContext.fetchCount(homeCountDescriptor)) ?? 0

        if homeCount > freeMaxHomes {
            return .denied(.overLimit)
        }

        if homeCount >= freeMaxHomes {
            return .denied(.homeLimitReached)
        }

        return .allowed
    }

    static func canCreateItem(homeId: UUID?, modelContext: ModelContext, isPro: Bool) -> GateResult {
        guard !isPro else { return .allowed }
        guard let homeId else { return .allowed }

        let homeCountDescriptor = FetchDescriptor<Home>()
        let homeCount = (try? modelContext.fetchCount(homeCountDescriptor)) ?? 0
        if homeCount > freeMaxHomes {
            return .denied(.overLimit)
        }

        // Single query: count items where storageLocation.home.id matches
        let itemCountDescriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate { $0.storageLocation?.home?.id == homeId }
        )
        let itemCount = (try? modelContext.fetchCount(itemCountDescriptor)) ?? 0

        if itemCount >= freeMaxItemsPerHome {
            return .denied(.itemLimitReached)
        }

        return .allowed
    }
}
