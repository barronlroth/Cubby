import Foundation
import SwiftData

enum LastUsedLocationService {
    private static let lastUsedLocationIdKey = "lastUsedStorageLocationId"
    private static let lastUsedHomeIdKey = "lastUsedStorageLocationHomeId"

    static func remember(
        location: StorageLocation,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(location.id.uuidString, forKey: lastUsedLocationIdKey)
        if let homeId = location.home?.id {
            userDefaults.set(homeId.uuidString, forKey: lastUsedHomeIdKey)
        } else {
            userDefaults.removeObject(forKey: lastUsedHomeIdKey)
        }
    }

    static func preferredLocation(
        for homeId: UUID?,
        in modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) -> StorageLocation? {
        if let restored = restoreLastUsedLocation(
            for: homeId,
            in: modelContext,
            userDefaults: userDefaults
        ) {
            return restored
        }

        return unsortedLocation(for: homeId, in: modelContext)
    }

    static func restoreLastUsedLocation(
        for homeId: UUID?,
        in modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) -> StorageLocation? {
        guard
            let locationIdString = userDefaults.string(forKey: lastUsedLocationIdKey),
            let locationId = UUID(uuidString: locationIdString)
        else {
            return nil
        }

        if let storedHomeIdString = userDefaults.string(forKey: lastUsedHomeIdKey),
           let storedHomeId = UUID(uuidString: storedHomeIdString),
           let homeId,
           storedHomeId != homeId {
            return nil
        }

        let descriptor = FetchDescriptor<StorageLocation>(
            predicate: #Predicate { $0.id == locationId }
        )

        guard let locations = try? modelContext.fetch(descriptor),
              let restored = locations.first
        else {
            return nil
        }

        if let homeId,
           let restoredHomeId = restored.home?.id,
           restoredHomeId != homeId {
            return nil
        }

        return restored
    }

    static func clear(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: lastUsedLocationIdKey)
        userDefaults.removeObject(forKey: lastUsedHomeIdKey)
    }

    private static func unsortedLocation(
        for homeId: UUID?,
        in modelContext: ModelContext
    ) -> StorageLocation? {
        guard let homeId else { return nil }
        let descriptor = FetchDescriptor<StorageLocation>(
            predicate: #Predicate { $0.home?.id == homeId && $0.name == "Unsorted" }
        )
        if let locations = try? modelContext.fetch(descriptor) {
            return locations.first
        }
        return nil
    }
}
