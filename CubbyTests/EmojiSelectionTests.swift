import Foundation
import Testing
@testable import Cubby

@Suite("Emoji Selection Tests")
struct EmojiSelectionTests {
    @Test("Curated categories include core groups")
    func categoriesIncludeCoreGroups() {
        let categoryIDs = Set(EmojiPicker.categories.map(\.id))

        #expect(categoryIDs.contains("home"))
        #expect(categoryIDs.contains("kitchen"))
        #expect(categoryIDs.contains("tools"))
        #expect(categoryIDs.contains("electronics"))
        #expect(categoryIDs.contains("clothing"))
        #expect(categoryIDs.contains("sports"))
        #expect(EmojiPicker.categories.allSatisfy { !$0.emojis.isEmpty })
    }

    @Test("Search filters emojis by keyword")
    func searchFiltersByKeyword() {
        let filtered = EmojiPicker.filteredCategories(matching: "HAMMER")
        let emojiSet = Set(filtered.flatMap(\.emojis).map(\.emoji))

        #expect(emojiSet.contains("🔨"))
        #expect(!emojiSet.contains("🍳"))
    }

    @Test("Category-name search keeps full matching category")
    func categoryNameSearchKeepsCategory() {
        let filtered = EmojiPicker.filteredCategories(matching: "kitchen")
        let kitchen = filtered.first(where: { $0.id == "kitchen" })

        #expect(kitchen != nil)
        #expect(kitchen?.emojis.contains(where: { $0.emoji == "🍳" }) == true)
        #expect(kitchen?.emojis.contains(where: { $0.emoji == "🍽️" }) == true)
    }

    @Test("Recents persist and cap at twenty entries")
    func recentsPersistAndCapAtTwentyEntries() throws {
        let suiteName = "EmojiSelectionTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create test defaults suite.")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let key = "emoji.recents.tests"
        let emojis = Array(EmojiPicker.allEmojis.prefix(24))
        #expect(emojis.count == 24)

        let store = EmojiRecentsStore(userDefaults: defaults, key: key, maxCount: 20)
        emojis.forEach { store.record($0) }

        let reloaded = EmojiRecentsStore(userDefaults: defaults, key: key, maxCount: 20)
        let persisted = reloaded.load()

        #expect(persisted.count == 20)
        #expect(persisted.first == emojis.last)
        #expect(persisted.last == emojis[4])

        reloaded.record(emojis[10])
        let deduped = reloaded.load()
        #expect(deduped.first == emojis[10])
        #expect(deduped.count == 20)
    }

    @Test("Selection updates selected value and recents order")
    func selectionUpdatesSelectedValueAndRecentsOrder() {
        let store = InMemoryEmojiRecentsStore(initial: ["📦", "🔧"])
        let viewModel = EmojiSelectionViewModel(selectedEmoji: nil, recentsStore: store)

        #expect(viewModel.recentEmojis == ["📦", "🔧"])

        viewModel.select(emoji: "🍳")
        #expect(viewModel.selectedEmoji == "🍳")
        #expect(viewModel.recentEmojis.prefix(3).elementsEqual(["🍳", "📦", "🔧"]))

        viewModel.select(emoji: "🔧")
        #expect(viewModel.selectedEmoji == "🔧")
        #expect(viewModel.recentEmojis.prefix(3).elementsEqual(["🔧", "🍳", "📦"]))
    }
}

private final class InMemoryEmojiRecentsStore: EmojiRecentsStoring {
    private var values: [String]

    init(initial: [String]) {
        self.values = initial
    }

    func load() -> [String] {
        values
    }

    func record(_ emoji: String) {
        values.removeAll { $0 == emoji }
        values.insert(emoji, at: 0)
        if values.count > 20 {
            values = Array(values.prefix(20))
        }
    }
}
