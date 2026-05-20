import Foundation

enum EmojiPicker {
    // Curated emoji list for stable visual identity
    static let emojis: [String] = [
        "📦", "📚", "🔦", "🎨", "🎸", "🗝️", "🧸", "🎥", "🖌️", "🧳", "💎", "🪛", "🔧", "🧰", "🪚",
        "🧼", "🧽", "🧴", "🪣", "🧯", "🪑", "🛏️", "🧺", "🧵", "🪡", "🧦", "👟", "👕", "🧥", "🎒",
        "🍳", "🍽️", "🍶", "🥤", "🍾", "🧊", "🥫", "🍪", "🍵", "☕️", "🧂", "🪥", "🧻", "🧴", "🪒",
        "🎧", "💻", "📷", "📺", "🕹️", "⛑️", "🪜", "🧯", "🧹", "🪠", "🧲", "🔩"
    ]

    static func emoji(for id: UUID) -> String {
        let idx = abs(id.uuidString.hashValue) % emojis.count
        return emojis[idx]
    }

    static func firstEmoji(in text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, first.isEmojiLike else { return nil }
        return String(first)
    }
}

private extension Character {
    var isEmojiLike: Bool {
        unicodeScalars.contains { $0.properties.isEmoji }
    }
}
