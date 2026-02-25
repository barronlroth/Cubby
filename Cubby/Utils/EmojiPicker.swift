import Foundation

enum EmojiPicker {
    struct EmojiOption: Identifiable, Hashable, Sendable {
        let emoji: String
        let keywords: [String]

        var id: String { emoji }

        func matches(_ query: String) -> Bool {
            let normalized = query.normalizedEmojiQuery
            guard !normalized.isEmpty else { return true }
            if emoji.contains(normalized) {
                return true
            }
            return keywords.contains { $0.localizedCaseInsensitiveContains(normalized) }
        }
    }

    struct EmojiCategory: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let systemImage: String
        let emojis: [EmojiOption]

        func matches(_ query: String) -> Bool {
            title.localizedCaseInsensitiveContains(query) || id.localizedCaseInsensitiveContains(query)
        }

        func filtered(for query: String) -> EmojiCategory? {
            let normalized = query.normalizedEmojiQuery
            guard !normalized.isEmpty else { return self }

            if matches(normalized) {
                return self
            }

            let filteredEmojis = emojis.filter { $0.matches(normalized) }
            guard !filteredEmojis.isEmpty else {
                return nil
            }

            return EmojiCategory(
                id: id,
                title: title,
                systemImage: systemImage,
                emojis: filteredEmojis
            )
        }
    }

    static let categories: [EmojiCategory] = [
        EmojiCategory(
            id: "home",
            title: "Home",
            systemImage: "house.fill",
            emojis: [
                option("📦", "box", "storage", "moving", "package"),
                option("🛋️", "sofa", "couch", "living room"),
                option("🛏️", "bed", "bedroom", "sleep"),
                option("🪑", "chair", "seat"),
                option("🪴", "plant", "indoor", "green"),
                option("🧺", "basket", "bin", "organize"),
                option("🖼️", "frame", "picture", "art"),
                option("🪞", "mirror"),
                option("🔑", "keys", "lock"),
                option("🕯️", "candle"),
                option("🧸", "toy", "kids", "plush"),
                option("🚪", "door", "entry")
            ]
        ),
        EmojiCategory(
            id: "kitchen",
            title: "Kitchen",
            systemImage: "fork.knife",
            emojis: [
                option("🍳", "pan", "cook", "frying"),
                option("🍽️", "plate", "dish"),
                option("🔪", "knife", "chef"),
                option("🥣", "bowl", "soup"),
                option("🥤", "cup", "drink"),
                option("🍶", "bottle", "pour"),
                option("☕️", "coffee", "mug"),
                option("🫖", "tea", "teapot"),
                option("🧂", "salt", "seasoning"),
                option("🧊", "ice", "freezer"),
                option("🥫", "can", "canned", "food"),
                option("🍪", "cookie", "snack")
            ]
        ),
        EmojiCategory(
            id: "tools",
            title: "Tools",
            systemImage: "wrench.and.screwdriver.fill",
            emojis: [
                option("🔨", "hammer", "nail"),
                option("🔧", "wrench", "spanner"),
                option("🪛", "screwdriver", "screws"),
                option("🧰", "toolbox", "tools", "repair"),
                option("🪚", "saw", "wood"),
                option("🪜", "ladder"),
                option("📏", "ruler", "measure"),
                option("🗜️", "clamp", "vise"),
                option("🔩", "bolt", "hardware"),
                option("🧲", "magnet"),
                option("🧯", "fire extinguisher", "safety"),
                option("⛑️", "helmet", "safety")
            ]
        ),
        EmojiCategory(
            id: "electronics",
            title: "Electronics",
            systemImage: "desktopcomputer",
            emojis: [
                option("💻", "laptop", "computer", "macbook"),
                option("🖥️", "desktop", "monitor"),
                option("📱", "phone", "smartphone", "mobile"),
                option("⌚️", "watch", "smartwatch"),
                option("🎧", "headphones", "audio", "music"),
                option("🎮", "gaming", "controller", "console"),
                option("📷", "camera", "photo"),
                option("📺", "television", "tv", "screen"),
                option("🔋", "battery", "power"),
                option("🔌", "plug", "charger"),
                option("🖨️", "printer"),
                option("🖱️", "mouse")
            ]
        ),
        EmojiCategory(
            id: "clothing",
            title: "Clothing",
            systemImage: "tshirt.fill",
            emojis: [
                option("👕", "shirt", "top"),
                option("👖", "jeans", "pants"),
                option("🧥", "jacket", "coat"),
                option("🧦", "socks"),
                option("👟", "sneakers", "shoes"),
                option("👞", "dress shoes", "shoe"),
                option("👗", "dress"),
                option("🧢", "cap", "hat"),
                option("🧤", "gloves"),
                option("🎒", "backpack", "bag"),
                option("🧳", "luggage", "suitcase"),
                option("🪡", "sewing", "needle")
            ]
        ),
        EmojiCategory(
            id: "sports",
            title: "Sports",
            systemImage: "sportscourt.fill",
            emojis: [
                option("⚽️", "soccer", "football"),
                option("🏀", "basketball"),
                option("🏈", "football", "nfl"),
                option("🎾", "tennis"),
                option("🏓", "ping pong", "table tennis"),
                option("🏸", "badminton"),
                option("🥊", "boxing", "gloves"),
                option("🏋️", "weights", "gym"),
                option("🚴", "bike", "cycling"),
                option("🎿", "ski", "snow"),
                option("🏄", "surfboard", "surf"),
                option("⛳️", "golf", "clubs")
            ]
        ),
        EmojiCategory(
            id: "office",
            title: "Office",
            systemImage: "briefcase.fill",
            emojis: [
                option("📚", "books", "library"),
                option("📓", "notebook"),
                option("📒", "journal"),
                option("✏️", "pencil"),
                option("🖊️", "pen"),
                option("📎", "paperclip"),
                option("📌", "pin"),
                option("🗂️", "folders"),
                option("🗃️", "cabinet"),
                option("🧾", "receipt", "document"),
                option("💼", "briefcase"),
                option("🗄️", "file cabinet")
            ]
        ),
        EmojiCategory(
            id: "outdoors",
            title: "Outdoors",
            systemImage: "leaf.fill",
            emojis: [
                option("🏕️", "camping", "tent"),
                option("⛺️", "tent", "camp"),
                option("🧭", "compass"),
                option("🗺️", "map"),
                option("🔦", "flashlight", "torch"),
                option("🚗", "car"),
                option("🚙", "suv"),
                option("🛶", "canoe"),
                option("🧗", "climbing"),
                option("🎣", "fishing"),
                option("🪢", "rope"),
                option("🧴", "sunscreen", "lotion")
            ]
        ),
        EmojiCategory(
            id: "cleaning",
            title: "Cleaning",
            systemImage: "sparkles",
            emojis: [
                option("🧹", "broom", "sweep"),
                option("🧽", "sponge"),
                option("🪣", "bucket"),
                option("🧴", "spray", "bottle", "cleaner"),
                option("🧼", "soap"),
                option("🧻", "paper towels", "toilet paper"),
                option("🪠", "plunger"),
                option("🧤", "rubber gloves"),
                option("🧺", "laundry basket"),
                option("🪥", "toothbrush"),
                option("🪒", "razor"),
                option("🫧", "bubbles", "wash")
            ]
        )
    ]

    static let allEmojis: [String] = {
        var seen = Set<String>()
        return categories
            .flatMap(\.emojis)
            .compactMap { option in
                guard seen.insert(option.emoji).inserted else { return nil }
                return option.emoji
            }
    }()

    private static let allEmojiSet = Set(allEmojis)

    static func emoji(for id: UUID) -> String {
        guard !allEmojis.isEmpty else { return "📦" }
        let idx = abs(id.uuidString.hashValue) % allEmojis.count
        return allEmojis[idx]
    }

    static func filteredCategories(matching query: String) -> [EmojiCategory] {
        categories.compactMap { $0.filtered(for: query) }
    }

    static func contains(_ emoji: String) -> Bool {
        allEmojiSet.contains(emoji)
    }

    private static func option(_ emoji: String, _ keywords: String...) -> EmojiOption {
        EmojiOption(emoji: emoji, keywords: keywords)
    }
}

private extension String {
    var normalizedEmojiQuery: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
