import Foundation
import SwiftData
import Testing
@testable import Cubby

@Suite("Legacy Search View Model Tests")
struct SearchViewModelTests {
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Home.self,
            StorageLocation.self,
            InventoryItem.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    private func seedSearchData(in context: ModelContext) throws -> (mainHome: Home, beachHome: Home) {
        let mainHome = Home(name: "Main Home")
        let beachHome = Home(name: "Beach House")
        let office = StorageLocation(name: "Office", home: mainHome)
        let shed = StorageLocation(name: "Beach Shed", home: beachHome)
        let passport = InventoryItem(title: "Passport", description: "Expires 2028", storageLocation: office)
        passport.tags = ["documents"]
        let surfboard = InventoryItem(title: "Surfboard", description: "7 foot funboard", storageLocation: shed)
        surfboard.tags = ["beach"]

        context.insert(mainHome)
        context.insert(beachHome)
        context.insert(office)
        context.insert(shed)
        context.insert(passport)
        context.insert(surfboard)
        try context.save()

        return (mainHome, beachHome)
    }

    @Test("Legacy search debounces, matches tags, and filters by selected home")
    @MainActor
    func testLegacySearchMatchesTagsAndFiltersByHome() async throws {
        let container = try makeContainer()
        let (mainHome, beachHome) = try seedSearchData(in: container.mainContext)
        let viewModel = SearchViewModel(modelContext: container.mainContext)

        viewModel.searchText = "beach"
        viewModel.selectedHome = mainHome
        viewModel.performSearch()
        try await waitForSearchToFinish(viewModel)
        #expect(viewModel.searchResults.isEmpty)

        viewModel.selectedHome = beachHome
        viewModel.performSearch()
        try await waitForSearchToFinish(viewModel)
        #expect(viewModel.searchResults.map(\.title) == ["Surfboard"])
    }

    @Test("Legacy search clear resets text and results")
    @MainActor
    func testLegacySearchClearResetsState() async throws {
        let container = try makeContainer()
        _ = try seedSearchData(in: container.mainContext)
        let viewModel = SearchViewModel(modelContext: container.mainContext)

        viewModel.searchText = "passport"
        viewModel.performSearch()
        try await waitForSearchToFinish(viewModel)
        #expect(viewModel.searchResults.map(\.title) == ["Passport"])

        viewModel.clearSearch()

        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.isSearching == false)
    }

    @MainActor
    private func waitForSearchToFinish(
        _ viewModel: SearchViewModel,
        timeout: TimeInterval = 1.5
    ) async throws {
        try await Task.sleep(nanoseconds: 350_000_000)
        let deadline = Date().addingTimeInterval(timeout)
        while viewModel.isSearching && Date() < deadline {
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        #expect(viewModel.isSearching == false)
    }
}
