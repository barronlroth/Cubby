import CloudKit
import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("App Store Home Deletion Tests")
struct AppStoreHomeDeletionTests {
    @MainActor
    private func makeRepository(
        shareService: (any HomeSharingServiceProtocol)? = nil
    ) throws -> CoreDataAppRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStoreHomeDeletionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory)
        return CoreDataAppRepository(
            persistenceController: controller,
            shareService: shareService
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

    @Test("Leaving a shared home keeps it hidden after AppStore relaunch")
    @MainActor
    func testLeaveSharedHomePersistsHiddenHomeAcrossAppStoreInstances() async throws {
        let suiteName = "AppStoreHomeDeletionTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let hiddenHomeStore = HiddenSharedHomeIDStore(userDefaults: userDefaults)
        let shareService = AppStoreRecordingHomeSharingService(role: .readWriteParticipant)
        let repository = try makeRepository(shareService: shareService)
        let leftHome = try repository.createHome(name: "Shared With Me")
        let keptHome = try repository.createHome(name: "Still Here")

        let appStore = AppStore(
            repository: repository,
            notificationCenter: NotificationCenter(),
            hiddenSharedHomeIDStore: hiddenHomeStore
        )

        try await appStore.leaveSharedHome(id: leftHome.id)

        #expect(shareService.leftHomeIDs == [leftHome.id])
        #expect(appStore.homes.contains { $0.id == leftHome.id } == false)
        #expect(appStore.homes.contains { $0.id == keptHome.id })

        let relaunchedAppStore = AppStore(
            repository: repository,
            notificationCenter: NotificationCenter(),
            hiddenSharedHomeIDStore: hiddenHomeStore
        )

        #expect(relaunchedAppStore.homes.contains { $0.id == leftHome.id } == false)
        #expect(relaunchedAppStore.homes.contains { $0.id == keptHome.id })
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

private final class AppStoreRecordingHomeSharingService: HomeSharingServiceProtocol {
    var leftHomeIDs: [UUID] = []
    private let role: SharePermission.Role

    init(role: SharePermission.Role) {
        self.role = role
    }

    func shareHome(_ home: AppHome) async throws -> CKShare {
        makeShare(for: home)
    }

    func shareURL(for home: AppHome) async throws -> URL {
        URL(string: "https://icloud.com/share/\(home.id.uuidString)")!
    }

    func fetchShare(for home: AppHome) -> CKShare? {
        makeShare(for: home)
    }

    func permission(for home: AppHome) -> SharePermission {
        _ = home
        return SharePermission(role: role)
    }

    func canEdit(_ home: AppHome) -> Bool {
        permission(for: home).canMutate
    }

    func isShared(_ home: AppHome) -> Bool {
        _ = home
        return true
    }

    func acceptShareInvitation(from metadata: CKShare.Metadata) async throws {
        _ = metadata
    }

    func participants(for home: AppHome) -> [CKShare.Participant] {
        _ = home
        return []
    }

    func leaveSharedHome(_ home: AppHome) async throws {
        leftHomeIDs.append(home.id)
    }

    func shareForController(
        _ home: AppHome,
        completion: @escaping (CKShare?, CKContainer?, Error?) -> Void
    ) {
        completion(makeShare(for: home), CKContainer(identifier: CloudKitSyncSettings.containerIdentifier), nil)
    }

    private func makeShare(for home: AppHome) -> CKShare {
        let share = CKShare(rootRecord: CKRecord(recordType: "Home"))
        share[CKShare.SystemFieldKey.title] = home.name as CKRecordValue
        return share
    }
}
