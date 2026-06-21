import Foundation
import Testing
import UIKit
@testable import Cubby

@Suite("App Store Photo Tests", .serialized)
struct AppStorePhotoTests {
    @MainActor
    private func makeRepository() throws -> CoreDataAppRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStorePhotoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory)
        return CoreDataAppRepository(
            persistenceController: controller,
            shareService: nil
        )
    }

    @MainActor
    private func makeAppStoreGraph() throws -> (appStore: AppStore, location: AppStorageLocation) {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Photo Home")
        let location = try #require(try repository.listLocations().first { $0.homeID == home.id })
        let appStore = AppStore(repository: repository, notificationCenter: NotificationCenter())
        return (appStore, location)
    }

    @Test("Creating an item with a selected image saves photo metadata and file")
    @MainActor
    func testCreateItemWithPhotoSavesFileAndMetadata() async throws {
        let (appStore, location) = try makeAppStoreGraph()
        let item = try await appStore.createItem(
            title: "Photo Item",
            itemDescription: nil,
            storageLocationID: location.id,
            tags: [],
            selectedImage: makeImage(color: .systemBlue)
        )
        let photoFileName = try #require(item.photoFileName)
        defer { try? FileManager.default.removeItem(at: photoURL(fileName: photoFileName)) }

        #expect(photoURL(fileName: photoFileName).isFileURL)
        #expect(FileManager.default.fileExists(atPath: photoURL(fileName: photoFileName).path))
        let loadedPhoto = await PhotoService.shared.loadPhoto(fileName: photoFileName)
        #expect(loadedPhoto != nil)
        #expect(appStore.item(id: item.id)?.photoFileName == photoFileName)
    }

    @Test("Creating an item deletes the saved photo if persistence fails")
    @MainActor
    func testCreateItemPhotoRollbackWhenPersistenceFails() async throws {
        let (appStore, _) = try makeAppStoreGraph()
        let beforeFiles = photoFileNames()

        do {
            _ = try await appStore.createItem(
                title: "Invalid Photo Item",
                itemDescription: nil,
                storageLocationID: UUID(),
                tags: [],
                selectedImage: makeImage(color: .systemRed)
            )
            Issue.record("Expected item creation to fail for an invalid location.")
        } catch {
            #expect(photoFileNames() == beforeFiles)
        }
    }

    @Test("Updating an item replaces and removes local photo files")
    @MainActor
    func testUpdateItemReplacesAndRemovesPhotoFiles() async throws {
        let (appStore, location) = try makeAppStoreGraph()
        let item = try await appStore.createItem(
            title: "Editable Photo Item",
            itemDescription: nil,
            storageLocationID: location.id,
            tags: [],
            selectedImage: makeImage(color: .systemBlue)
        )
        let originalPhotoFileName = try #require(item.photoFileName)
        defer { try? FileManager.default.removeItem(at: photoURL(fileName: originalPhotoFileName)) }

        let updated = try await appStore.updateItem(
            id: item.id,
            title: item.title,
            itemDescription: item.itemDescription,
            tags: item.tagsSet,
            selectedPhoto: makeImage(color: .systemGreen),
            removePhoto: false,
            emoji: item.emoji,
            isPendingAiEmoji: item.isPendingAiEmoji
        )
        let replacementPhotoFileName = try #require(updated.photoFileName)
        defer { try? FileManager.default.removeItem(at: photoURL(fileName: replacementPhotoFileName)) }

        #expect(replacementPhotoFileName != originalPhotoFileName)
        #expect(FileManager.default.fileExists(atPath: photoURL(fileName: originalPhotoFileName).path) == false)
        #expect(FileManager.default.fileExists(atPath: photoURL(fileName: replacementPhotoFileName).path))

        let removed = try await appStore.updateItem(
            id: item.id,
            title: item.title,
            itemDescription: item.itemDescription,
            tags: item.tagsSet,
            selectedPhoto: nil,
            removePhoto: true,
            emoji: item.emoji,
            isPendingAiEmoji: item.isPendingAiEmoji
        )

        #expect(removed.photoFileName == nil)
        #expect(FileManager.default.fileExists(atPath: photoURL(fileName: replacementPhotoFileName).path) == false)
    }

    @Test("Cleanup removes orphaned photos and preserves active photo metadata")
    @MainActor
    func testCleanupRemovesOrphanedPhotos() async throws {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Cleanup Home")
        let location = try #require(try repository.listLocations().first { $0.homeID == home.id })
        let activeFileName = "active-\(UUID().uuidString).jpg"
        let orphanFileName = "orphan-\(UUID().uuidString).jpg"
        try Data("active".utf8).write(to: photoURL(fileName: activeFileName))
        try Data("orphan".utf8).write(to: photoURL(fileName: orphanFileName))
        defer { try? FileManager.default.removeItem(at: photoURL(fileName: activeFileName)) }
        defer { try? FileManager.default.removeItem(at: photoURL(fileName: orphanFileName)) }

        _ = try repository.createItem(
            AppItemDraft(
                id: UUID(),
                title: "Active Photo Item",
                itemDescription: nil,
                storageLocationID: location.id,
                tags: [],
                emoji: nil,
                isPendingAiEmoji: false,
                photoFileName: activeFileName
            )
        )

        await DataCleanupService.shared.performCleanup(persistenceController: repository.persistenceController)

        #expect(FileManager.default.fileExists(atPath: photoURL(fileName: activeFileName).path))
        #expect(FileManager.default.fileExists(atPath: photoURL(fileName: orphanFileName).path) == false)
    }

    private func makeImage(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
    }

    private func photoFileNames() -> Set<String> {
        let directory = photosDirectory()
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return Set(urls.map(\.lastPathComponent))
    }

    private func photoURL(fileName: String) -> URL {
        let directory = photosDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    private func photosDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ItemPhotos")
    }
}
