import Foundation
import Observation

protocol EmojiRecentsStoring {
    func load() -> [String]
    func record(_ emoji: String)
}

final class EmojiRecentsStore: EmojiRecentsStoring {
    private let userDefaults: UserDefaults
    private let key: String
    private let maxCount: Int

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "recentlySelectedEmojis",
        maxCount: Int = 20
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.maxCount = maxCount
    }

    func load() -> [String] {
        let stored = userDefaults.stringArray(forKey: key) ?? []
        var seen = Set<String>()
        return stored
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
            .prefix(maxCount)
            .map { $0 }
    }

    func record(_ emoji: String) {
        guard !emoji.isEmpty else { return }
        var values = load()
        values.removeAll { $0 == emoji }
        values.insert(emoji, at: 0)
        if values.count > maxCount {
            values = Array(values.prefix(maxCount))
        }
        userDefaults.set(values, forKey: key)
    }
}

@Observable
final class EmojiSelectionViewModel {
    var selectedEmoji: String?
    var searchText: String = ""
    private(set) var recentEmojis: [String]

    private let recentsStore: EmojiRecentsStoring

    init(
        selectedEmoji: String?,
        recentsStore: EmojiRecentsStoring = EmojiRecentsStore()
    ) {
        self.selectedEmoji = selectedEmoji
        self.recentsStore = recentsStore
        self.recentEmojis = recentsStore.load()
    }

    var filteredCategories: [EmojiPicker.EmojiCategory] {
        EmojiPicker.filteredCategories(matching: searchText)
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func select(emoji: String) {
        selectedEmoji = emoji
        recentsStore.record(emoji)
        recentEmojis = recentsStore.load()
    }
}
