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

        let locationIdsDescriptor = FetchDescriptor<StorageLocation>(
            predicate: #Predicate { $0.home?.id == homeId }
        )
        let locationIds = (try? modelContext.fetch(locationIdsDescriptor).map(\.id)) ?? []

        var itemCount = 0
        for locationId in locationIds {
            let itemCountDescriptor = FetchDescriptor<InventoryItem>(
                predicate: #Predicate { $0.storageLocation?.id == locationId }
            )
            itemCount += (try? modelContext.fetchCount(itemCountDescriptor)) ?? 0
            if itemCount >= freeMaxItemsPerHome {
                return .denied(.itemLimitReached)
            }
        }

        return .allowed
    }
}
