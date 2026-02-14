import Foundation
import Testing
import SwiftData
@testable import Cubby

@Suite("Last Used Location Service")
struct LastUsedLocationServiceTests {
    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "LastUsedLocationServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @MainActor
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            Home.self,
            StorageLocation.self,
            InventoryItem.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }

    @Test("Returns stored last used location for matching home")
    @MainActor
    func testPreferredLocationUsesLastUsedForHome() async throws {
        let defaults = makeUserDefaults()
        let container = try createTestContainer()
        let context = container.mainContext

        let home = Home(name: "Primary")
        let lastUsed = StorageLocation(name: "Closet", home: home)
        let unsorted = StorageLocation(name: "Unsorted", home: home)
        context.insert(home)
        context.insert(lastUsed)
        context.insert(unsorted)
        try context.save()

        LastUsedLocationService.remember(location: lastUsed, userDefaults: defaults)

        let preferred = LastUsedLocationService.preferredLocation(
            for: home.id,
            in: context,
            userDefaults: defaults
        )

        #expect(preferred?.id == lastUsed.id)
    }

    @Test("Falls back to Unsorted when there is no last used location")
    @MainActor
    func testPreferredLocationFallsBackToUnsorted() async throws {
        let defaults = makeUserDefaults()
        let container = try createTestContainer()
        let context = container.mainContext

        let home = Home(name: "Primary")
        let unsorted = StorageLocation(name: "Unsorted", home: home)
        context.insert(home)
        context.insert(unsorted)
        try context.save()

        let preferred = LastUsedLocationService.preferredLocation(
            for: home.id,
            in: context,
            userDefaults: defaults
        )

        #expect(preferred?.id == unsorted.id)
    }

    @Test("Ignores last used location from a different home")
    @MainActor
    func testPreferredLocationIgnoresMismatchedHome() async throws {
        let defaults = makeUserDefaults()
        let container = try createTestContainer()
        let context = container.mainContext

        let homeA = Home(name: "Home A")
        let homeB = Home(name: "Home B")
        let locationA = StorageLocation(name: "Closet", home: homeA)
        let unsortedB = StorageLocation(name: "Unsorted", home: homeB)
        context.insert(homeA)
        context.insert(homeB)
        context.insert(locationA)
        context.insert(unsortedB)
        try context.save()

        LastUsedLocationService.remember(location: locationA, userDefaults: defaults)

        let preferred = LastUsedLocationService.preferredLocation(
            for: homeB.id,
            in: context,
            userDefaults: defaults
        )

        #expect(preferred?.id == unsortedB.id)
    }
}
