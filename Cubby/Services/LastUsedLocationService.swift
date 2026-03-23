import Foundation
import SwiftData

enum LastUsedLocationService {
    private static let lastUsedLocationIdKey = "lastUsedStorageLocationId"
    private static let lastUsedHomeIdKey = "lastUsedStorageLocationHomeId"

    static func remember(
        location: AppStorageLocation?,
        userDefaults: UserDefaults = .standard
    ) {
        guard let location else {
            clear(userDefaults: userDefaults)
            return
        }
        userDefaults.set(location.id.uuidString, forKey: lastUsedLocationIdKey)
        userDefaults.set(location.homeID.uuidString, forKey: lastUsedHomeIdKey)
    }

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
        availableLocations: [AppStorageLocation],
        userDefaults: UserDefaults = .standard
    ) -> AppStorageLocation? {
        if let restored = restoreLastUsedLocation(
            for: homeId,
            availableLocations: availableLocations,
            userDefaults: userDefaults
        ) {
            return restored
        }

        return unsortedLocation(for: homeId, availableLocations: availableLocations)
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
        availableLocations: [AppStorageLocation],
        userDefaults: UserDefaults = .standard
    ) -> AppStorageLocation? {
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

        guard let restored = availableLocations.first(where: { $0.id == locationId })
        else {
            return nil
        }

        if let homeId, restored.homeID != homeId {
            return nil
        }

        return restored
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
        availableLocations: [AppStorageLocation]
    ) -> AppStorageLocation? {
        guard let homeId else { return nil }
        return availableLocations.first { $0.homeID == homeId && $0.name == "Unsorted" }
    }

    private static func unsortedLocation(
        for homeId: UUID?,
        in modelContext: ModelContext
    ) -> StorageLocation? {
        guard let homeId else { return nil }
        let descriptor = FetchDescriptor<StorageLocation>(
            predicate: #Predicate { $0.home?.id == homeId && $0.name == "Unsorted" }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
