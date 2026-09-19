import Foundation
import Testing
@testable import Cubby

@Suite("Emoji Tests")
struct EmojiTests {
    @MainActor
    private func makeRepository() throws -> CoreDataAppRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmojiTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(storeDirectory: directory, cloudKitEnabled: false)
        return CoreDataAppRepository(
            persistenceController: controller,
            shareService: nil
        )
    }

    @MainActor
    private func makeAppStoreGraph() throws -> (appStore: AppStore, location: AppStorageLocation) {
        let repository = try makeRepository()
        let home = try repository.createHome(name: "Emoji Home")
        let location = try #require(try repository.listLocations().first { $0.homeID == home.id })
        let appStore = AppStore(repository: repository, notificationCenter: NotificationCenter())
        return (appStore, location)
    }

    @Test("Fallback emoji is stable for the same UUID")
    func testFallbackEmojiIsStableForUUID() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        let emoji = EmojiPicker.emoji(for: id)

        #expect(EmojiPicker.emoji(for: id) == emoji)
        #expect(EmojiPicker.emojis.contains(emoji))
    }

    @Test("First emoji parser stores only a leading emoji-like character")
    func testFirstEmojiParser() {
        #expect(EmojiPicker.firstEmoji(in: "  🧭 compass") == "🧭")
        #expect(EmojiPicker.firstEmoji(in: "🔦📦") == "🔦")
        #expect(EmojiPicker.firstEmoji(in: "compass 🧭") == nil)
        #expect(EmojiPicker.firstEmoji(in: nil) == nil)
    }

    @Test("AppStore uses fallback emoji when no manual emoji is selected")
    @MainActor
    func testAppStoreUsesFallbackEmojiForNewItemWithoutManualEmoji() async throws {
        let (appStore, location) = try makeAppStoreGraph()
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-000000000456")!

        let item = try await appStore.createItem(
            title: "Fallback Item",
            itemDescription: nil,
            storageLocationID: location.id,
            tags: [],
            selectedImage: nil,
            emoji: nil,
            itemID: itemID
        )

        #expect(item.emoji == EmojiPicker.emoji(for: itemID))
    }

    @Test("Manual emoji create and edit persist only the selected emoji")
    @MainActor
    func testManualEmojiCreateAndEdit() async throws {
        let (appStore, location) = try makeAppStoreGraph()
        let item = try await appStore.createItem(
            title: "Manual Emoji Item",
            itemDescription: nil,
            storageLocationID: location.id,
            tags: [],
            selectedImage: nil,
            emoji: "  🧭 compass"
        )

        #expect(item.emoji == "🧭")
        #expect(item.isPendingAiEmoji == false)

        let updated = try await appStore.updateItem(
            id: item.id,
            title: item.title,
            itemDescription: item.itemDescription,
            tags: item.tagsSet,
            selectedPhoto: nil,
            removePhoto: false,
            emoji: "🔦 flashlight",
            isPendingAiEmoji: false
        )

        #expect(updated.emoji == "🔦")
        #expect(updated.isPendingAiEmoji == false)
    }

    @Test("AI emoji coordinator applies suggestion and clears pending state")
    @MainActor
    func testEmojiCoordinatorAppliesSuggestion() async throws {
        let repository = try makeRepository()
        let item = try makePendingEmojiItem(in: repository)
        let coordinator = EmojiAssignmentCoordinator(suggester: StubEmojiSuggester(result: .success("🔦")))

        coordinator.postSaveEmojiEnhancement(
            for: item.id,
            title: item.title,
            repository: repository
        )

        let updated = try await waitForItem(repository: repository, id: item.id) {
            $0.emoji == "🔦" && $0.isPendingAiEmoji == false
        }
        #expect(updated.emoji == "🔦")
        #expect(updated.isPendingAiEmoji == false)
    }

    @Test("AI emoji coordinator clears pending state when unavailable")
    @MainActor
    func testEmojiCoordinatorClearsPendingWhenUnavailable() async throws {
        let repository = try makeRepository()
        let item = try makePendingEmojiItem(in: repository)
        let coordinator = EmojiAssignmentCoordinator(suggester: StubEmojiSuggester(result: .failure(SuggestionError.unavailable)))

        coordinator.postSaveEmojiEnhancement(
            for: item.id,
            title: item.title,
            repository: repository
        )

        let updated = try await waitForItem(repository: repository, id: item.id) {
            $0.emoji == item.emoji && $0.isPendingAiEmoji == false
        }
        #expect(updated.emoji == item.emoji)
        #expect(updated.isPendingAiEmoji == false)
    }

    @Test("Model output must be one complete emoji", arguments: ["🐶", " 🍽️ ", "👩🏽‍🔧", "🇺🇸", "1️⃣", "#️⃣", "☀️", "👨‍👩‍👧‍👦"])
    func validModelOutput(_ input: String) {
        #expect(FoundationModelEmojiService.validatedEmoji(input) == input.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test("Reject prose, multiple emoji, digits and incomplete sequences", arguments: ["", "1", "#", "*", "1. 🐶", "Dog 🐶", "🐶🐱", "🏽", "🇺", "hello", "🐶\u{200D}"])
    func invalidModelOutput(_ input: String) {
        #expect(FoundationModelEmojiService.validatedEmoji(input) == nil)
    }

    @Test("Late results preserve a manual choice or renamed item", arguments: [true, false])
    @MainActor
    func lateResultsPreserveEdits(manualChoice: Bool) async throws {
        let repository = try makeRepository()
        let item = try makePendingEmojiItem(in: repository)
        let gate = GatedEmojiSuggester()
        let coordinator = EmojiAssignmentCoordinator(suggester: gate)
        coordinator.postSaveEmojiEnhancement(for: item.id, title: item.title, repository: repository)
        try await waitUntil { await gate.callCount == 1 }
        _ = try repository.updateItem(id: item.id, draft: AppItemUpdateDraft(
            title: manualChoice ? item.title : "Passport", itemDescription: nil, tags: [],
            emoji: manualChoice ? "🧭" : item.emoji, isPendingAiEmoji: !manualChoice,
            photoFileName: nil, removePhoto: false))
        await gate.complete("🔦")
        try await waitUntil { coordinator.isIdle }
        let updated = try #require(try repository.item(id: item.id))
        #expect(updated.emoji == (manualChoice ? "🧭" : item.emoji))
        #expect(!updated.isPendingAiEmoji)
    }

    @Test("Requests are serialized even when submitted together")
    @MainActor
    func serialRequests() async throws {
        let repository = try makeRepository()
        let first = try makePendingEmojiItem(in: repository)
        let second = try makePendingEmojiItem(in: repository)
        let gate = GatedEmojiSuggester()
        let coordinator = EmojiAssignmentCoordinator(suggester: gate)
        coordinator.postSaveEmojiEnhancement(for: first.id, title: first.title, repository: repository)
        coordinator.postSaveEmojiEnhancement(for: second.id, title: second.title, repository: repository)
        try await waitUntil { await gate.callCount == 1 }
        await gate.complete("🔦")
        try await waitUntil { await gate.callCount == 2 }
        #expect(await gate.maximumConcurrent == 1)
        await gate.complete("🧭")
        try await waitUntil { coordinator.isIdle }
        #expect(try repository.item(id: first.id)?.emoji == "🔦")
        #expect(try repository.item(id: second.id)?.emoji == "🧭")
    }

    @Test("Deadline clears active and queued spinners even when cancellation is ignored")
    @MainActor
    func independentDeadline() async throws {
        let repository = try makeRepository()
        let first = try makePendingEmojiItem(in: repository)
        let queued = try makePendingEmojiItem(in: repository)
        let gate = GatedEmojiSuggester()
        let coordinator = EmojiAssignmentCoordinator(suggester: gate, deadline: .milliseconds(100))
        coordinator.postSaveEmojiEnhancement(for: first.id, title: first.title, repository: repository)
        coordinator.postSaveEmojiEnhancement(for: queued.id, title: queued.title, repository: repository)
        try await waitUntil { await gate.callCount == 1 }
        _ = try await waitForItem(repository: repository, id: first.id) { !$0.isPendingAiEmoji }
        _ = try await waitForItem(repository: repository, id: queued.id) { !$0.isPendingAiEmoji }
        #expect(!coordinator.isIdle) // Still owns the uncooperative model task.
        await gate.complete("🐶")
        try await waitUntil { coordinator.isIdle }
        #expect(await gate.callCount == 1) // Expired queued work never starts.
        #expect(try repository.item(id: first.id)?.emoji == first.emoji)
        #expect(try repository.item(id: queued.id)?.emoji == queued.emoji)
    }

    @Test("Recovery clears abandoned flags without changing fallback or live requests")
    @MainActor
    func recoverAbandoned() async throws {
        let repository = try makeRepository()
        let abandoned = try makePendingEmojiItem(in: repository)
        let live = try makePendingEmojiItem(in: repository)
        let gate = GatedEmojiSuggester()
        let coordinator = EmojiAssignmentCoordinator(suggester: gate)
        coordinator.postSaveEmojiEnhancement(for: live.id, title: live.title, repository: repository)
        coordinator.recoverAbandonedRequests(in: repository)
        #expect(try repository.item(id: abandoned.id)?.isPendingAiEmoji == false)
        #expect(try repository.item(id: abandoned.id)?.emoji == abandoned.emoji)
        #expect(try repository.item(id: live.id)?.isPendingAiEmoji == true)
        try await waitUntil { await gate.callCount == 1 }
        await gate.complete("🔦")
        try await waitUntil { coordinator.isIdle }
    }

    @Test("Invalid suggestion keeps the preassigned fallback")
    @MainActor
    func invalidSuggestionFallback() async throws {
        let repository = try makeRepository()
        let item = try makePendingEmojiItem(in: repository)
        let coordinator = EmojiAssignmentCoordinator(suggester: StubEmojiSuggester(result: .success("1. 🐶")))
        coordinator.postSaveEmojiEnhancement(for: item.id, title: item.title, repository: repository)
        let updated = try await waitForItem(repository: repository, id: item.id) { !$0.isPendingAiEmoji }
        #expect(updated.emoji == item.emoji)
    }

    @Test("Suggestion completion respects current shared-home permissions")
    @MainActor
    func readOnlyCompletion() throws {
        let owner = try makeRepository()
        let item = try makePendingEmojiItem(in: owner)
        let readOnly = CoreDataAppRepository(
            persistenceController: owner.persistenceController,
            shareService: DebugMockHomeSharingService(mode: .readOnlyParticipant))
        try readOnly.completeEmojiSuggestion(id: item.id, expectedTitle: item.title,
                                             expectedEmoji: item.emoji, emoji: "🔦")
        let unchanged = try #require(try owner.item(id: item.id))
        #expect(unchanged.emoji == item.emoji)
        #expect(unchanged.isPendingAiEmoji)
    }

    @MainActor
    private func waitUntil(_ predicate: () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while ContinuousClock.now < deadline {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await predicate())
    }

    @MainActor
    private func makePendingEmojiItem(in repository: CoreDataAppRepository) throws -> AppInventoryItem {
        let home = try repository.createHome(name: "AI Emoji Home")
        let location = try #require(try repository.listLocations().first { $0.homeID == home.id })
        let itemID = UUID()
        return try repository.createItem(
            AppItemDraft(
                id: itemID,
                title: "Flashlight",
                itemDescription: nil,
                storageLocationID: location.id,
                tags: [],
                emoji: EmojiPicker.emoji(for: itemID),
                isPendingAiEmoji: true,
                photoFileName: nil
            )
        )
    }

    @MainActor
    private func waitForItem(
        repository: CoreDataAppRepository,
        id: UUID,
        timeout: TimeInterval = 2,
        predicate: (AppInventoryItem) -> Bool
    ) async throws -> AppInventoryItem {
        let deadline = Date().addingTimeInterval(timeout)
        var lastItem: AppInventoryItem?
        while Date() < deadline {
            if let item = try repository.item(id: id) {
                lastItem = item
                if predicate(item) {
                    return item
                }
            }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        let item = try #require(lastItem)
        #expect(predicate(item))
        return item
    }
}

private actor StubEmojiSuggester: EmojiSuggesting {
    let result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func suggestEmoji(for title: String) async throws -> String {
        switch result {
        case let .success(emoji):
            return emoji
        case let .failure(error):
            throw error
        }
    }
}

// Intentionally ignores task cancellation until the test releases its continuation.
private actor GatedEmojiSuggester: EmojiSuggesting {
    private var continuations: [CheckedContinuation<String, Never>] = []
    private(set) var callCount = 0
    private(set) var maximumConcurrent = 0
    func suggestEmoji(for title: String) async throws -> String {
        callCount += 1
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
            maximumConcurrent = max(maximumConcurrent, continuations.count)
        }
    }
    func complete(_ value: String) { continuations.removeFirst().resume(returning: value) }
}
