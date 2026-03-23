import CloudKit
import CoreData
import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var homes: [AppHome] = []
    @Published private(set) var locations: [AppStorageLocation] = []
    @Published private(set) var items: [AppInventoryItem] = []
    @Published var recoveryMessage: String?

    let repository: CoreDataAppRepository

    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(
        repository: CoreDataAppRepository,
        notificationCenter: NotificationCenter = .default
    ) {
        self.repository = repository
        self.notificationCenter = notificationCenter
        refresh()
        startObserving()
    }

    deinit {
        observers.forEach(notificationCenter.removeObserver(_:))
    }

    func refresh() {
        do {
            homes = try repository.listHomes()
            locations = try repository.listLocations()
            items = try repository.listItems()
        } catch {
            DebugLogger.error("AppStore refresh failed: \(error)")
        }
    }

    func home(id: UUID?) -> AppHome? {
        guard let id else { return nil }
        return homes.first { $0.id == id }
    }

    func location(id: UUID?) -> AppStorageLocation? {
        guard let id else { return nil }
        return locations.first { $0.id == id }
    }

    func item(id: UUID) -> AppInventoryItem? {
        items.first { $0.id == id }
    }

    func rootLocations(in homeID: UUID?) -> [AppStorageLocation] {
        locations
            .filter { $0.homeID == homeID && $0.parentLocationID == nil }
            .sorted(by: locationSort)
    }

    func childLocations(of parentLocationID: UUID) -> [AppStorageLocation] {
        locations
            .filter { $0.parentLocationID == parentLocationID }
            .sorted(by: locationSort)
    }

    func items(in homeID: UUID?) -> [AppInventoryItem] {
        items
            .filter { $0.homeID == homeID }
            .sorted(by: itemSort)
    }

    func items(inLocation locationID: UUID?) -> [AppInventoryItem] {
        items
            .filter { $0.storageLocationID == locationID }
            .sorted(by: itemSort)
    }

    func searchItems(query: String, homeID: UUID?) -> [AppInventoryItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return items(in: homeID)
        }

        let terms = trimmed.split(separator: " ").map(String.init)
        return items(in: homeID)
            .filter { item in
                terms.allSatisfy { term in
                    item.title.localizedCaseInsensitiveContains(term)
                        || (item.itemDescription?.localizedCaseInsensitiveContains(term) ?? false)
                        || item.tags.contains(where: { $0.localizedCaseInsensitiveContains(term) })
                }
            }
            .sorted { lhs, rhs in
                searchMatchCount(for: lhs, terms: terms) > searchMatchCount(for: rhs, terms: terms)
            }
    }

    func allKnownTags() -> [String] {
        Array(Set(items.flatMap(\.tags))).sorted()
    }

    func canCreateHome(isPro: Bool) -> GateResult {
        FeatureGate.canCreateHome(dataSource: repository, isPro: isPro)
    }

    func canCreateItem(homeID: UUID?, isPro: Bool) -> GateResult {
        FeatureGate.canCreateItem(homeId: homeID, dataSource: repository, isPro: isPro)
    }

    func shareManagementAccess(
        for home: AppHome?,
        isPro: Bool,
        sharedHomesEnabled: Bool
    ) -> ShareManagementAccess {
        FeatureGate.shareManagementAccess(
            for: home,
            isPro: isPro,
            sharedHomesEnabled: sharedHomesEnabled
        )
    }

    func createHome(name: String) throws -> AppHome {
        let home = try repository.createHome(name: name)
        refresh()
        return home
    }

    func createLocation(name: String, homeID: UUID, parentLocationID: UUID?) throws -> AppStorageLocation {
        let location = try repository.createLocation(
            AppLocationCreationDraft(
                name: name,
                homeID: homeID,
                parentLocationID: parentLocationID
            )
        )
        refresh()
        return location
    }

    func deleteLocation(id: UUID) throws {
        try repository.deleteLocation(id: id)
        refresh()
    }

    func createItem(
        title: String,
        itemDescription: String?,
        storageLocationID: UUID,
        tags: Set<String>,
        selectedImage: UIImage?
    ) async throws -> AppInventoryItem {
        var savedPhotoFileName: String?
        if let selectedImage {
            savedPhotoFileName = try await PhotoService.shared.savePhoto(selectedImage)
        }

        let newItemID = UUID()
        let draft = AppItemDraft(
            id: newItemID,
            title: title,
            itemDescription: itemDescription,
            storageLocationID: storageLocationID,
            tags: tags,
            emoji: EmojiPicker.emoji(for: newItemID),
            isPendingAiEmoji: FoundationModelEmojiService.isSupported,
            photoFileName: savedPhotoFileName
        )

        do {
            let item = try repository.createItem(draft)
            refresh()
            LastUsedLocationService.remember(location: location(id: storageLocationID))
            Task {
                await EmojiAssignmentCoordinator.shared.postSaveEmojiEnhancement(
                    for: item.id,
                    title: item.title,
                    persistenceController: repository.persistenceController
                )
            }
            return item
        } catch {
            if let savedPhotoFileName {
                await PhotoService.shared.deletePhoto(fileName: savedPhotoFileName)
            }
            throw error
        }
    }

    func updateItem(
        id: UUID,
        title: String,
        itemDescription: String?,
        tags: Set<String>,
        selectedPhoto: UIImage?,
        removePhoto: Bool
    ) async throws -> AppInventoryItem {
        let existingItem = try repository.item(id: id)
        let oldPhotoFileName = existingItem?.photoFileName

        var replacementPhotoFileName = oldPhotoFileName
        if let selectedPhoto {
            replacementPhotoFileName = try await PhotoService.shared.savePhoto(selectedPhoto)
        }

        let draft = AppItemUpdateDraft(
            title: title,
            itemDescription: itemDescription,
            tags: tags,
            photoFileName: replacementPhotoFileName,
            removePhoto: removePhoto
        )

        do {
            let item = try repository.updateItem(id: id, draft: draft)
            refresh()

            if selectedPhoto != nil,
               let oldPhotoFileName,
               oldPhotoFileName != replacementPhotoFileName {
                await PhotoService.shared.deletePhoto(fileName: oldPhotoFileName)
            }

            if removePhoto, let oldPhotoFileName {
                await PhotoService.shared.deletePhoto(fileName: oldPhotoFileName)
            }

            return item
        } catch {
            if selectedPhoto != nil,
               let replacementPhotoFileName,
               replacementPhotoFileName != oldPhotoFileName {
                await PhotoService.shared.deletePhoto(fileName: replacementPhotoFileName)
            }
            throw error
        }
    }

    func moveItem(id: UUID, to locationID: UUID) throws {
        _ = try repository.moveItem(id: id, to: locationID)
        refresh()
        LastUsedLocationService.remember(location: location(id: locationID))
    }

    func deleteItem(id: UUID) throws {
        try repository.deleteItem(id: id)
        refresh()
    }

    func restoreDeletedItem(_ snapshot: AppDeletedItemSnapshot) throws {
        _ = try repository.restoreDeletedItem(snapshot)
        refresh()
    }

    func deleteSnapshot(for itemID: UUID) -> AppDeletedItemSnapshot? {
        guard let item = item(id: itemID),
              let storageLocationID = item.storageLocationID else {
            return nil
        }

        return AppDeletedItemSnapshot(
            itemID: item.id,
            storageLocationID: storageLocationID,
            title: item.title,
            itemDescription: item.itemDescription,
            photoFileName: item.photoFileName,
            emoji: item.emoji,
            tags: item.tagsSet,
            isPendingAiEmoji: item.isPendingAiEmoji,
            createdAt: item.createdAt,
            modifiedAt: item.modifiedAt
        )
    }

    func preferredLocation(for homeID: UUID?) -> AppStorageLocation? {
        LastUsedLocationService.preferredLocation(for: homeID, availableLocations: locations)
    }

    func shareHome(homeID: UUID) throws -> CKShare {
        let share = try repository.share(for: homeID)
        refresh()
        return share
    }

    func existingShare(homeID: UUID) -> CKShare? {
        repository.existingShare(for: homeID)
    }

    var shareContainer: CKContainer {
        repository.ckContainer
    }

    private func startObserving() {
        observers.append(
            notificationCenter.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: repository.persistenceController.persistentContainer.viewContext,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        )

        observers.append(
            notificationCenter.addObserver(
                forName: RemoteChangeHandler.didMergeRemoteChangesNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        )

        observers.append(
            notificationCenter.addObserver(
                forName: DataMigrationService.didRequestRecoveryNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.recoveryMessage = notification.userInfo?[DataMigrationService.recoveryMessageUserInfoKey] as? String
                    self?.refresh()
                }
            }
        )
    }

    private func itemSort(lhs: AppInventoryItem, rhs: AppInventoryItem) -> Bool {
        lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func locationSort(lhs: AppStorageLocation, rhs: AppStorageLocation) -> Bool {
        lhs.fullPath.localizedCaseInsensitiveCompare(rhs.fullPath) == .orderedAscending
    }

    private func searchMatchCount(for item: AppInventoryItem, terms: [String]) -> Int {
        terms.reduce(0) { count, term in
            var matches = 0
            if item.title.localizedCaseInsensitiveContains(term) { matches += 1 }
            if item.itemDescription?.localizedCaseInsensitiveContains(term) ?? false { matches += 1 }
            if item.tags.contains(where: { $0.localizedCaseInsensitiveContains(term) }) { matches += 1 }
            return count + matches
        }
    }
}
