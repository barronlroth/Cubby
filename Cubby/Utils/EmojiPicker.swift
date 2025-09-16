import Foundation

enum EmojiPicker {
    // Curated emoji list for stable visual identity
    private static let emojis: [String] = [
        "📦", "📚", "🔦", "🎨", "🎸", "🗝️", "🧸", "🎥", "🖌️", "🧳", "💎", "🪛", "🔧", "🧰", "🪚",
        "🧼", "🧽", "🧴", "🪣", "🧯", "🪑", "🛏️", "🧺", "🧵", "🪡", "🧦", "👟", "👕", "🧥", "🎒",
        "🍳", "🍽️", "🍶", "🥤", "🍾", "🧊", "🥫", "🍪", "🍵", "☕️", "🧂", "🪥", "🧻", "🧴", "🪒",
        "🎧", "💻", "📷", "📺", "🕹️", "⛑️", "🪜", "🧯", "🧹", "🪠", "🧲", "🔩"
    ]

    static func emoji(for id: UUID) -> String {
        let idx = abs(id.uuidString.hashValue) % emojis.count
        return emojis[idx]
    }
}

