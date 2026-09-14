import Foundation
import Testing
@testable import Cubby

@Suite("Siri Inventory Service", .timeLimit(.minutes(1)))
@MainActor
struct SiriInventoryServiceTests {
    private func record(
        id: UUID = UUID(),
        title: String = "Passport",
        home: String = "Juniper House",
        path: String = "Entry Closet > Top Shelf",
        description: String? = "Blue cover",
        tags: [String] = ["travel"]
    ) -> SiriInventoryRecord {
        SiriInventoryRecord(
            id: id, title: title, homeID: UUID(), homeName: home,
            locationPath: path, itemDescription: description, tags: tags, emoji: "📘"
        )
    }

    @Test("Search matches every word across saved fields, including diacritics")
    func multiwordSearch() async throws {
        let coffee = record(title: "Café grinder", home: "Beach House", path: "Kitchen > High Shelf", tags: ["coffee"])
        let unrelated = record(title: "Spare keys")
        let service = SiriInventoryService(
            recordLoader: { [coffee, unrelated] },
            accessProvider: { .pro },
            indexWriter: RecordingSiriIndex()
        )

        #expect(try await service.entities(matching: "CAFE coffee beach shelf").map(\.id) == [coffee.id])
        #expect(try await service.entities(matching: "blue grinder").map(\.id) == [coffee.id])
        #expect(try await service.entities(matching: "coffee missing").isEmpty)
        #expect(try await service.entities(matching: " \n ").count == 2)
    }

    @Test("Duplicate item titles remain distinct and resolve by stable IDs")
    func duplicateTitles() async throws {
        let beach = record(title: "Keys", home: "Beach House")
        let city = record(title: "Keys", home: "City Apartment")
        let service = SiriInventoryService(
            recordLoader: { [city, beach] },
            accessProvider: { .pro },
            indexWriter: RecordingSiriIndex()
        )
        #expect(try await service.entities(matching: "Keys").map(\.id) == [beach.id, city.id])
        #expect(try await service.entities(for: [city.id, UUID(), city.id]).map(\.id) == [city.id])
    }

    @Test("Location answers read the latest saved location and reject deleted items")
    func movedAndDeletedItems() async throws {
        let original = record()
        var records = [original]
        let service = SiriInventoryService(
            recordLoader: { records },
            accessProvider: { .pro },
            indexWriter: RecordingSiriIndex()
        )
        #expect(try await service.locateItem(id: original.id).fullPath == "Juniper House > Entry Closet > Top Shelf")
        records = [record(id: original.id, path: "Bedroom > Bedside Drawer")]
        #expect(try await service.locateItem(id: original.id).fullPath == "Juniper House > Bedroom > Bedside Drawer")
        records = []
        #expect(try await service.entities(for: [original.id]).isEmpty)
        await #expect(throws: SiriInventoryError.itemUnavailable) {
            try await service.locateItem(id: original.id)
        }
        await service.waitForIndexRefresh()
    }

    @Test("Unresolved and denied subscriptions never read or return inventory")
    func entitlementRequired() async throws {
        var entitlement = ProEntitlementState.resolving
        var readCount = 0
        let item = record()
        let service = SiriInventoryService(
            recordLoader: { readCount += 1; return [item] },
            accessProvider: { entitlement },
            indexWriter: RecordingSiriIndex()
        )
        for state in [ProEntitlementState.resolving, .notPro] {
            entitlement = state
            await #expect(throws: SiriInventoryError.subscriptionRequired) {
                try await service.entities(matching: "Passport")
            }
            await service.waitForIndexRefresh()
        }
        #expect(readCount == 0)
        entitlement = .pro
        #expect(try await service.entities(matching: "Passport").map(\.id) == [item.id])
    }

    @Test("Locking before or during entitlement resolution prevents all inventory reads")
    func protectedDataRequired() async throws {
        var isUnlocked = false
        var readCount = 0
        var accessCount = 0
        var accessReply: CheckedContinuation<ProEntitlementState, Never>?
        let (accessStarts, signalAccessStart) = AsyncStream<Void>.makeStream()
        let item = record()
        let service = SiriInventoryService(
            recordLoader: { readCount += 1; return [item] },
            accessProvider: {
                accessCount += 1
                return await withCheckedContinuation { continuation in
                    accessReply = continuation
                    signalAccessStart.yield(())
                }
            },
            protectedDataAvailable: { isUnlocked },
            indexWriter: RecordingSiriIndex()
        )

        await #expect(throws: SiriInventoryError.deviceLocked) {
            try await service.entities(matching: "Passport")
        }
        await service.waitForIndexRefresh()
        #expect(accessCount == 0)
        #expect(readCount == 0)

        isUnlocked = true
        let request = Task { try await service.entities(matching: "Passport") }
        for await _ in accessStarts { break }
        isUnlocked = false
        let reply = try #require(accessReply)
        reply.resume(returning: .pro)
        signalAccessStart.finish()
        await #expect(throws: SiriInventoryError.deviceLocked) {
            try await request.value
        }
        await service.waitForIndexRefresh()
        #expect(accessCount == 1)
        #expect(readCount == 0)
    }

    @Test("A failed storage read does not reuse a previous successful result or index")
    func storageFailure() async throws {
        enum StorageFailure: Error { case unreadable }
        let item = record()
        var shouldFail = false
        let index = RecordingSiriIndex()
        let service = SiriInventoryService(
            recordLoader: {
                if shouldFail { throw StorageFailure.unreadable }
                return [item]
            },
            accessProvider: { .pro },
            indexWriter: index
        )
        service.scheduleIndexRefresh()
        await service.waitForIndexRefresh()
        #expect(index.records == [item])
        #expect(try await service.locateItem(id: item.id) == item)

        shouldFail = true
        await #expect(throws: SiriInventoryError.storageUnavailable) {
            try await service.locateItem(id: item.id)
        }
        await service.waitForIndexRefresh()
        #expect(index.records.isEmpty)
    }

    @Test("Navigation requires fresh access and old acknowledgments preserve newer requests")
    func navigationRequests() async throws {
        let item = record()
        var records = [item]
        var entitlement = ProEntitlementState.pro
        var preparationCount = 0
        let service = SiriInventoryService(
            recordLoader: { records },
            accessProvider: { entitlement },
            prepareNavigation: { preparationCount += 1 },
            indexWriter: RecordingSiriIndex()
        )
        try await service.openItem(id: item.id)
        let first = try #require(service.navigationRequest)
        #expect(first.destination == .item(item.id))
        try await service.search(query: "  travel keys \n")
        let second = try #require(service.navigationRequest)
        #expect(second.destination == .search("travel keys"))
        #expect(first.id != second.id)
        service.acknowledgeNavigation(id: first.id)
        #expect(service.navigationRequest == second)
        service.acknowledgeNavigation(id: second.id)
        #expect(service.navigationRequest == nil)
        #expect(preparationCount == 2)

        records = []
        await #expect(throws: SiriInventoryError.itemUnavailable) {
            try await service.openItem(id: item.id)
        }
        #expect(service.navigationRequest == nil)
        entitlement = .notPro
        await #expect(throws: SiriInventoryError.subscriptionRequired) {
            try await service.search(query: "travel")
        }
        #expect(service.navigationRequest == nil)
        #expect(preparationCount == 2)
        await service.waitForIndexRefresh()
    }

    @Test("Independent presentation blockers preserve each other and pending navigation")
    func independentPresentationBlockers() async throws {
        let service = SiriInventoryService(
            recordLoader: { [] },
            accessProvider: { .pro },
            indexWriter: RecordingSiriIndex()
        )
        try await service.search(query: "Passport")
        let pending = try #require(service.navigationRequest)
        let firstOwner = UUID()
        let secondOwner = UUID()

        service.setPresentationBlocker(id: firstOwner, isBlocked: true)
        service.setPresentationBlocker(id: secondOwner, isBlocked: true)
        #expect(service.hasPresentationBlockers)
        #expect(service.navigationRequest == pending)
        service.setPresentationBlocker(id: firstOwner, isBlocked: false)
        #expect(service.hasPresentationBlockers)
        // Repeated cleanup from the first owner cannot remove the second owner's blocker.
        service.setPresentationBlocker(id: firstOwner, isBlocked: false)
        #expect(service.hasPresentationBlockers)
        #expect(service.navigationRequest == pending)
        service.setPresentationBlocker(id: secondOwner, isBlocked: false)
        #expect(!service.hasPresentationBlockers)
        #expect(service.navigationRequest == pending)
    }

    @Test("Reconciliation replaces changed records and purges them after access loss")
    func indexChangesAndRevocation() async throws {
        let original = record()
        var records = [original]
        var entitlement = ProEntitlementState.pro
        let index = RecordingSiriIndex()
        let service = SiriInventoryService(
            recordLoader: { records },
            accessProvider: { entitlement },
            indexWriter: index
        )
        service.scheduleIndexRefresh()
        await service.waitForIndexRefresh()
        #expect(index.records == [original])

        let moved = record(id: original.id, path: "Office > Filing Cabinet")
        records = [moved]
        service.scheduleIndexRefresh()
        await service.waitForIndexRefresh()
        #expect(index.records == [moved])

        entitlement = .notPro
        service.scheduleIndexRefresh()
        await service.waitForIndexRefresh()
        #expect(index.records.isEmpty)
        #expect(index.events == [.removed, .insertionStarted, .inserted, .removed, .insertionStarted, .inserted, .removed])
    }

    @Test("An in-flight insertion finishes before the purge caused by access loss")
    func insertionRaceWithAccessLoss() async throws {
        let item = record()
        var entitlement = ProEntitlementState.pro
        let index = RecordingSiriIndex()
        index.suspendNextInsertion = true
        let service = SiriInventoryService(
            recordLoader: { [item] },
            accessProvider: { entitlement },
            indexWriter: index
        )

        service.scheduleIndexRefresh()
        await index.waitForSuspendedInsertion()
        entitlement = .notPro
        service.scheduleIndexRefresh()
        index.resumeInsertion()
        await service.waitForIndexRefresh()

        #expect(index.records.isEmpty)
        #expect(index.events == [.removed, .insertionStarted, .inserted, .removed])
    }
}

@MainActor
private final class RecordingSiriIndex: SiriInventoryIndexWriting {
    enum Event: Equatable { case removed, insertionStarted, inserted }

    private(set) var records: [SiriInventoryRecord] = []
    private(set) var events: [Event] = []
    var suspendNextInsertion = false
    private var insertionContinuation: CheckedContinuation<Void, Never>?
    private var insertionWaiters: [CheckedContinuation<Void, Never>] = []

    func removeAll() async throws {
        events.append(.removed)
        records = []
    }

    func index(_ records: [SiriInventoryRecord]) async throws {
        events.append(.insertionStarted)
        if suspendNextInsertion {
            suspendNextInsertion = false
            await withCheckedContinuation { continuation in
                insertionContinuation = continuation
                let waiters = insertionWaiters
                insertionWaiters = []
                waiters.forEach { $0.resume() }
            }
        }
        self.records = records
        events.append(.inserted)
    }

    func waitForSuspendedInsertion() async {
        guard insertionContinuation == nil else { return }
        await withCheckedContinuation { insertionWaiters.append($0) }
    }

    func resumeInsertion() {
        let continuation = insertionContinuation
        insertionContinuation = nil
        continuation?.resume()
    }
}
