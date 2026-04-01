import Foundation
import SwiftData

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

struct GateResult: Equatable {
    let isAllowed: Bool
    let reason: GateReason?

    static let allowed = GateResult(isAllowed: true, reason: nil)

    static func denied(_ reason: GateReason) -> GateResult {
        GateResult(isAllowed: false, reason: reason)
    }
}

enum ShareManagementAccess: Equatable {
    case hidden
    case upgradeRequired
    case allowed

    var showsAffordance: Bool {
        self != .hidden
    }
}

struct FeatureGate {
    static let freeMaxHomes = 1
    static let freeMaxItemsPerHome = 10
    nonisolated static let useCoreDataSharingStackLaunchArgument = "USE_CORE_DATA_SHARING_STACK"

    nonisolated static func shouldUseCoreDataSharingStack(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if let rawValue = environment[useCoreDataSharingStackLaunchArgument] {
            switch rawValue.lowercased() {
            case "1", "true", "yes", "y", "on":
                return true
            case "0", "false", "no", "n", "off":
                return false
            default:
                break
            }
        }

        if arguments.contains(useCoreDataSharingStackLaunchArgument) {
            return true
        }

        // Core Data sharing stack enabled by default
        return true
    }

    @MainActor
    static func canCreateHome(modelContext: ModelContext, isPro: Bool) -> GateResult {
        canCreateHome(
            homeCountProvider: {
                let homeCountDescriptor = FetchDescriptor<Home>()
                return (try? modelContext.fetchCount(homeCountDescriptor)) ?? 0
            },
            isPro: isPro
        )
    }

    @MainActor
    static func canCreateHome(dataSource: any FeatureGateDataSource, isPro: Bool) -> GateResult {
        canCreateHome(
            homeCountProvider: { (try? dataSource.ownerHomeCount()) ?? 0 },
            isPro: isPro
        )
    }

    @MainActor
    static func canCreateItem(homeId: UUID?, modelContext: ModelContext, isPro: Bool) -> GateResult {
        canCreateItem(
            homeId: homeId,
            homeCountProvider: {
                let homeCountDescriptor = FetchDescriptor<Home>()
                return (try? modelContext.fetchCount(homeCountDescriptor)) ?? 0
            },
            itemCountProvider: { homeId in
                let itemsDescriptor = FetchDescriptor<InventoryItem>()
                let items = (try? modelContext.fetch(itemsDescriptor)) ?? []
                return items.filter { $0.storageLocation?.home?.id == homeId }.count
            },
            isPro: isPro
        )
    }

    @MainActor
    static func canCreateItem(homeId: UUID?, dataSource: any FeatureGateDataSource, isPro: Bool) -> GateResult {
        canCreateItem(
            homeId: homeId,
            homeCountProvider: { (try? dataSource.ownerHomeCount()) ?? 0 },
            itemCountProvider: { homeId in
                (try? dataSource.ownerItemCount(for: homeId)) ?? 0
            },
            isPro: isPro
        )
    }

    static func shareManagementAccess(
        for home: AppHome?,
        isPro: Bool,
        sharedHomesEnabled: Bool
    ) -> ShareManagementAccess {
        guard sharedHomesEnabled,
              let home,
              home.isOwnedByCurrentUser else {
            return .hidden
        }

        guard isPro else {
            return .upgradeRequired
        }

        return .allowed
    }

    private static func canCreateHome(
        homeCountProvider: () -> Int,
        isPro: Bool
    ) -> GateResult {
        guard !isPro else { return .allowed }
        let homeCount = homeCountProvider()

        if homeCount > freeMaxHomes {
            return .denied(.overLimit)
        }

        if homeCount >= freeMaxHomes {
            return .denied(.homeLimitReached)
        }

        return .allowed
    }

    private static func canCreateItem(
        homeId: UUID?,
        homeCountProvider: () -> Int,
        itemCountProvider: (UUID) -> Int,
        isPro: Bool
    ) -> GateResult {
        guard !isPro else { return .allowed }
        guard let homeId else { return .allowed }

        let homeCount = homeCountProvider()
        if homeCount > freeMaxHomes {
            return .denied(.overLimit)
        }

        let itemCount = itemCountProvider(homeId)

        if itemCount >= freeMaxItemsPerHome {
            return .denied(.itemLimitReached)
        }

        return .allowed
    }
}
