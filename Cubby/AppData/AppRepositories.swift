import CloudKit
import Foundation

@MainActor
protocol HomeRepository {
    func listHomes() throws -> [AppHome]
    func home(id: UUID) throws -> AppHome?
    func createHome(name: String) throws -> AppHome
    @discardableResult
    func deleteHome(id: UUID) throws -> [String]
}

@MainActor
protocol LocationRepository {
    func listLocations() throws -> [AppStorageLocation]
    func location(id: UUID) throws -> AppStorageLocation?
    func createLocation(_ draft: AppLocationCreationDraft) throws -> AppStorageLocation
    func deleteLocation(id: UUID) throws
}

@MainActor
protocol ItemRepository {
    func listItems() throws -> [AppInventoryItem]
    func item(id: UUID) throws -> AppInventoryItem?
    func createItem(_ draft: AppItemDraft) throws -> AppInventoryItem
    func updateItem(id: UUID, draft: AppItemUpdateDraft) throws -> AppInventoryItem
    func moveItem(id: UUID, to locationID: UUID) throws -> AppInventoryItem
    func deleteItem(id: UUID) throws
    func restoreDeletedItem(_ snapshot: AppDeletedItemSnapshot) throws -> AppInventoryItem
}

@MainActor
protocol ShareRepository {
    var ckContainer: CKContainer { get }

    func share(for homeID: UUID) async throws -> CKShare
    func shareURL(for homeID: UUID) async throws -> URL
    func existingShare(for homeID: UUID) -> CKShare?
    func permission(for homeID: UUID) -> SharePermission
    func participants(for homeID: UUID) -> [CKShare.Participant]
    func isShared(homeID: UUID) -> Bool
    func leaveSharedHome(id: UUID) async throws
}

@MainActor
protocol FeatureGateDataSource {
    func ownerHomeCount() throws -> Int
    func ownerItemCount(for homeID: UUID) throws -> Int
}
