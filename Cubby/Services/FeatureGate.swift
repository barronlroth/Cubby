import Foundation
import SwiftData

@MainActor
enum GateReason: Equatable, CustomStringConvertible {
    case homeLimitReached
    case itemLimitReached
    case overLimit

    var description: String {
        switch self {
        case .homeLimitReached: "homeLimitReached"
        case .itemLimitReached: "itemLimitReached"
        case .overLimit: "overLimit"
        }
    }
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

        // Avoid fetchCount with nested optional relationship predicates; it can crash on some OS builds.
        let itemsDescriptor = FetchDescriptor<InventoryItem>()
        let items = (try? modelContext.fetch(itemsDescriptor)) ?? []
        let itemCount = items.filter { $0.storageLocation?.home?.id == homeId }.count

        if itemCount >= freeMaxItemsPerHome {
            return .denied(.itemLimitReached)
        }

        return .allowed
    }
}
