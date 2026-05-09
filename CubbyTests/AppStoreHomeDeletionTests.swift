import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("App Store Home Deletion Tests")
struct AppStoreHomeDeletionTests {
    @MainActor
    private func makeRepository() throws -> CoreDataAppRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStoreHomeDeletionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory)
        return CoreDataAppRepository(
            persistenceController: controller,
            shareService: nil
        )
    }

    @MainActor
    private func createPhotoBackedItem(
        in repository: CoreDataAppRepository,
        photoFileName: String
    ) throws -> AppHome {
        let home = try repository.createHome(name: "Photo Home")
        let location = try #require(try repository.listLocations().first { $0.homeID == home.id })
        _ = try repository.createItem(
            AppItemDraft(
                id: UUID(),
                title: "Photo Item",
                itemDescription: nil,
                storageLocationID: location.id,
                tags: [],
                emoji: nil,
                isPendingAiEmoji: false,
                photoFileName: photoFileName
            )
        )
        return home
    }

    @Test("Deleting a home through AppStore cleans up item photos")
    @MainActor
    func testDeleteHomeCleansUpPhotos() async throws {
        let repository = try makeRepository()
        let appStore = AppStore(repository: repository)
        let photoFileName = "home-delete-\(UUID().uuidString).jpg"
        let photoURL = try makePhotoFile(named: photoFileName)
        defer { try? FileManager.default.removeItem(at: photoURL) }
        let home = try createPhotoBackedItem(in: repository, photoFileName: photoFileName)
        appStore.refresh()

        try await appStore.deleteHome(id: home.id)

        #expect(FileManager.default.fileExists(atPath: photoURL.path) == false)
        #expect(appStore.homes.isEmpty)
        #expect(appStore.items.isEmpty)
    }

    private func makePhotoFile(named fileName: String) throws -> URL {
        let photosDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("ItemPhotos")
        try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        let photoURL = photosDirectory.appendingPathComponent(fileName)
        try Data("photo".utf8).write(to: photoURL)
        return photoURL
    }
}
