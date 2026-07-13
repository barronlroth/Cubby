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
        let controller = try PersistenceController(storeDirectory: directory)
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

        await coordinator.postSaveEmojiEnhancement(
            for: item.id,
            title: item.title,
            persistenceController: repository.persistenceController
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

        await coordinator.postSaveEmojiEnhancement(
            for: item.id,
            title: item.title,
            persistenceController: repository.persistenceController
        )

        let updated = try await waitForItem(repository: repository, id: item.id) {
            $0.emoji == item.emoji && $0.isPendingAiEmoji == false
        }
        #expect(updated.emoji == item.emoji)
        #expect(updated.isPendingAiEmoji == false)
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
        return try #require(lastItem)
    }
}

private actor StubEmojiSuggester: EmojiSuggesting {
    let result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func suggestEmoji(for title: String, deadline: Duration) async throws -> String {
        switch result {
        case let .success(emoji):
            return emoji
        case let .failure(error):
            throw error
        }
    }
}
