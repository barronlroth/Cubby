import Foundation
import Testing
@testable import Cubby

@Suite("App Store Search Tests")
struct AppStoreSearchTests {
    @MainActor
    private func makeRepository() throws -> CoreDataAppRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStoreSearchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory)
        return CoreDataAppRepository(
            persistenceController: controller,
            shareService: nil
        )
    }

    @MainActor
    private func makeItem(
        title: String,
        description: String?,
        tags: Set<String>,
        homeName: String,
        in repository: CoreDataAppRepository
    ) throws -> AppInventoryItem {
        let home = try repository.createHome(name: homeName)
        let location = try #require(try repository.listLocations().first { $0.homeID == home.id })
        return try repository.createItem(
            AppItemDraft(
                id: UUID(),
                title: title,
                itemDescription: description,
                storageLocationID: location.id,
                tags: tags,
                emoji: nil,
                isPendingAiEmoji: false,
                photoFileName: nil
            )
        )
    }

    @Test("Search with no selected home searches across all homes")
    @MainActor
    func testSearchWithoutSelectedHomeSearchesAllHomes() throws {
        let repository = try makeRepository()
        let passport = try makeItem(
            title: "Passport",
            description: "Expires 2028",
            tags: ["documents"],
            homeName: "Main Home",
            in: repository
        )
        let surfboard = try makeItem(
            title: "Surfboard",
            description: "7 foot funboard",
            tags: ["beach"],
            homeName: "Beach House",
            in: repository
        )
        let appStore = AppStore(repository: repository, notificationCenter: NotificationCenter())

        #expect(appStore.searchItems(query: "surf", homeID: nil).map(\.id) == [surfboard.id])
        #expect(appStore.searchItems(query: "documents", homeID: nil).map(\.id) == [passport.id])
        #expect(appStore.searchItems(query: "", homeID: nil).map(\.id) == [passport.id, surfboard.id])
    }

    @Test("Search with selected home filters out other homes")
    @MainActor
    func testSearchWithSelectedHomeFiltersResults() throws {
        let repository = try makeRepository()
        let passport = try makeItem(
            title: "Passport",
            description: "Expires 2028",
            tags: ["documents"],
            homeName: "Main Home",
            in: repository
        )
        let surfboard = try makeItem(
            title: "Surfboard",
            description: "7 foot funboard",
            tags: ["beach"],
            homeName: "Beach House",
            in: repository
        )
        let appStore = AppStore(repository: repository, notificationCenter: NotificationCenter())

        #expect(appStore.searchItems(query: "surf", homeID: passport.homeID).isEmpty)
        #expect(appStore.searchItems(query: "surf", homeID: surfboard.homeID).map(\.id) == [surfboard.id])
    }
}
