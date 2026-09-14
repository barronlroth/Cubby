import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// One runtime shared by SwiftUI and main-process App Intents, including cold launches.
@MainActor
final class SiriInventoryService: ObservableObject {
    static let shared = SiriInventoryService(indexWriter: SiriInventoryIndex())

    @Published private(set) var navigationRequest: SiriNavigationRequest?
    @Published private(set) var hasPresentationBlockers = false
    private var presentationBlockers = Set<UUID>()

    private var recordLoader: () throws -> [SiriInventoryRecord]
    private var accessProvider: () async -> ProEntitlementState
    private var protectedDataAvailable: () -> Bool
    private var prepareNavigation: () -> Void
    private let indexWriter: any SiriInventoryIndexWriting
    private var observations = Set<AnyCancellable>()
    private var indexUpdatesEnabled = true
    private var indexGeneration: UInt64 = 0
    private var indexTask: Task<Void, Never>?

    init(
        recordLoader: @escaping () throws -> [SiriInventoryRecord] = { throw SiriInventoryError.storageUnavailable },
        accessProvider: @escaping () async -> ProEntitlementState = { .resolving },
        prepareNavigation: @escaping () -> Void = {},
        protectedDataAvailable: @escaping () -> Bool = { true },
        indexWriter: any SiriInventoryIndexWriting
    ) {
        self.recordLoader = recordLoader
        self.accessProvider = accessProvider
        self.prepareNavigation = prepareNavigation
        self.protectedDataAvailable = protectedDataAvailable
        self.indexWriter = indexWriter
    }

    func configure(
        appStore: AppStore?,
        proAccessManager: ProAccessManager,
        indexingEnabled: Bool = true
    ) {
        observations.removeAll()
        indexUpdatesEnabled = indexingEnabled
        recordLoader = {
            guard let appStore else { throw SiriInventoryError.storageUnavailable }
            return try appStore.siriInventoryRecords()
        }
        accessProvider = {
            await proAccessManager.refresh()
            return proAccessManager.entitlementState
        }
        prepareNavigation = { appStore?.refresh() }
        #if canImport(UIKit)
        protectedDataAvailable = { UIApplication.shared.isProtectedDataAvailable }
        NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleIndexRefresh() }
            .store(in: &observations)
        #endif

        appStore?.$inventoryRevision
            .sink { [weak self] _ in self?.scheduleIndexRefresh() }
            .store(in: &observations)
        proAccessManager.$entitlementState
            .removeDuplicates()
            .sink { [weak self] state in
                // Published delivers the new value before the manager's property changes.
                if state != .pro { self?.navigationRequest = nil }
                self?.scheduleIndexRefresh()
            }
            .store(in: &observations)
        scheduleIndexRefresh()
    }

    func entities(matching query: String) async throws -> [SiriInventoryRecord] {
        let records = try await recordsForRequest()
        let terms = query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !terms.isEmpty else { return records }
        return records.filter { record in
            let fields = [record.title, record.homeName, record.locationPath]
                + [record.itemDescription].compactMap { $0 }
                + record.tags
            return terms.allSatisfy { term in
                fields.contains { $0.localizedStandardContains(term) }
            }
        }
    }

    func entities(for identifiers: [UUID]) async throws -> [SiriInventoryRecord] {
        let records = try await recordsForRequest()
        let requested = Set(identifiers)
        return records.filter { requested.contains($0.id) }
    }

    func suggestedEntities() async throws -> [SiriInventoryRecord] {
        Array(try await recordsForRequest().prefix(20))
    }

    func locateItem(id: UUID) async throws -> SiriInventoryRecord {
        guard let item = try await recordsForRequest().first(where: { $0.id == id }) else {
            scheduleIndexRefresh()
            throw SiriInventoryError.itemUnavailable
        }
        return item
    }

    func openItem(id: UUID) async throws {
        _ = try await locateItem(id: id)
        prepareNavigation()
        navigationRequest = SiriNavigationRequest(destination: .item(id))
    }

    func search(query: String) async throws {
        _ = try await recordsForRequest()
        prepareNavigation()
        navigationRequest = SiriNavigationRequest(
            destination: .search(query.trimmingCharacters(in: .whitespacesAndNewlines))
        )
    }

    /// Presentation owners register separately so closing one form cannot unblock another.
    func setPresentationBlocker(id: UUID, isBlocked: Bool) {
        if isBlocked {
            presentationBlockers.insert(id)
        } else {
            presentationBlockers.remove(id)
        }
        hasPresentationBlockers = !presentationBlockers.isEmpty
    }

    func acknowledgeNavigation(id: UUID) {
        guard navigationRequest?.id == id else { return }
        navigationRequest = nil
    }

    /// Serialize deletion and insertion so an old in-flight write cannot outlive a newer purge.
    func scheduleIndexRefresh() {
        guard indexUpdatesEnabled else { return }
        indexGeneration &+= 1
        guard indexTask == nil else { return }
        indexTask = Task { [weak self] in
            await self?.reconcileIndex()
        }
    }

    /// Used by tests and lifecycle handoffs that need the current index work to finish.
    func waitForIndexRefresh() async {
        await indexTask?.value
    }

    private func recordsForRequest() async throws -> [SiriInventoryRecord] {
        do {
            return try await authorizedRecords()
        } catch {
            scheduleIndexRefresh()
            throw error
        }
    }

    private func authorizedRecords() async throws -> [SiriInventoryRecord] {
        guard protectedDataAvailable() else { throw SiriInventoryError.deviceLocked }
        let access = await accessProvider()
        try Task.checkCancellation()
        guard protectedDataAvailable() else { throw SiriInventoryError.deviceLocked }
        guard access == .pro else { throw SiriInventoryError.subscriptionRequired }
        do {
            // Resolve only after entitlement awaits, so concurrent mutations are included.
            return try recordLoader().sorted { left, right in
                let titleOrder = left.title.localizedStandardCompare(right.title)
                if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
                let pathOrder = left.fullPath.localizedStandardCompare(right.fullPath)
                if pathOrder != .orderedSame { return pathOrder == .orderedAscending }
                return left.id.uuidString < right.id.uuidString
            }
        } catch {
            throw SiriInventoryError.storageUnavailable
        }
    }

    private func reconcileIndex() async {
        while true {
            let generation = indexGeneration
            do {
                // Deleting first removes stale paths, deleted records, and revoked access.
                // A failed snapshot must leave the index empty, never republish old values.
                try await indexWriter.removeAll()
                guard generation == indexGeneration else { continue }
                let records: [SiriInventoryRecord]
                do {
                    records = try await authorizedRecords()
                } catch {
                    records = []
                }
                guard generation == indexGeneration else { continue }
                if !records.isEmpty {
                    try await indexWriter.index(records)
                }
            } catch {
                // Retry on the next inventory/entitlement/foreground event. Never spin on a
                // locked device or a temporarily unavailable Spotlight service.
                DebugLogger.error("Siri inventory index update failed: \(error)")
            }
            if generation == indexGeneration { break }
        }
        indexTask = nil
    }
}
