import Foundation

enum HomeLaunchSelectionService {
    static func preferredHomeID(
        lastUsedHomeId: String?,
        homes: [AppHome],
        locations: [AppStorageLocation],
        items: [AppInventoryItem]
    ) -> UUID? {
        if let lastUsedHomeId,
           let homeID = UUID(uuidString: lastUsedHomeId),
           homes.contains(where: { $0.id == homeID }) {
            return homeID
        }

        return preferredHome(
            homes: homes,
            locations: locations,
            items: items
        )?.id
    }

    static func preferredHome(
        homes: [AppHome],
        locations: [AppStorageLocation],
        items: [AppInventoryItem]
    ) -> AppHome? {
        guard homes.isEmpty == false else { return nil }

        let latestLocationActivityByHomeID = latestLocationActivityByHomeID(locations)
        let latestItemActivityByHomeID = latestItemActivityByHomeID(items)

        return homes.sorted { lhs, rhs in
            let lhsActivity = activityDate(
                for: lhs,
                latestLocationActivityByHomeID: latestLocationActivityByHomeID,
                latestItemActivityByHomeID: latestItemActivityByHomeID
            )
            let rhsActivity = activityDate(
                for: rhs,
                latestLocationActivityByHomeID: latestLocationActivityByHomeID,
                latestItemActivityByHomeID: latestItemActivityByHomeID
            )

            if lhsActivity != rhsActivity {
                return lhsActivity > rhsActivity
            }

            let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }.first
    }

    private static func latestLocationActivityByHomeID(
        _ locations: [AppStorageLocation]
    ) -> [UUID: Date] {
        locations.reduce(into: [:]) { latestByHomeID, location in
            latestByHomeID[location.homeID] = max(
                latestByHomeID[location.homeID] ?? .distantPast,
                location.modifiedAt
            )
        }
    }

    private static func latestItemActivityByHomeID(
        _ items: [AppInventoryItem]
    ) -> [UUID: Date] {
        items.reduce(into: [:]) { latestByHomeID, item in
            guard let homeID = item.homeID else { return }
            latestByHomeID[homeID] = max(
                latestByHomeID[homeID] ?? .distantPast,
                item.modifiedAt
            )
        }
    }

    private static func activityDate(
        for home: AppHome,
        latestLocationActivityByHomeID: [UUID: Date],
        latestItemActivityByHomeID: [UUID: Date]
    ) -> Date {
        max(
            home.modifiedAt,
            latestLocationActivityByHomeID[home.id] ?? .distantPast,
            latestItemActivityByHomeID[home.id] ?? .distantPast
        )
    }
}
