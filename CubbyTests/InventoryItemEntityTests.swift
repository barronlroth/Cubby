import Foundation
import Testing
@testable import Cubby

@Suite("Inventory Item Entity")
struct InventoryItemEntityTests {
    private func record(id: UUID = UUID(), emoji: String?) -> SiriInventoryRecord {
        SiriInventoryRecord(
            id: id, title: "Passport", homeID: UUID(), homeName: "Juniper House",
            locationPath: "Entry Closet > Top Shelf", itemDescription: nil, tags: [], emoji: emoji
        )
    }

    @Test("System results use the item's saved emoji")
    func savedEmoji() {
        #expect(InventoryItemEntity(record: record(emoji: "📘")).emoji == "📘")
    }

    @Test("Missing or blank emoji fall back to the same stable emoji in-app rows show")
    func fallbackEmoji() {
        let id = UUID()
        #expect(InventoryItemEntity(record: record(id: id, emoji: nil)).emoji == EmojiPicker.emoji(for: id))
        #expect(InventoryItemEntity(record: record(id: id, emoji: "  ")).emoji == EmojiPicker.emoji(for: id))
    }

    @Test("Emoji renders to image data for result icons and Spotlight thumbnails")
    func emojiImageData() throws {
        let data = try #require(InventoryItemEmojiImage.pngData(for: "📘"))
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        let entity = InventoryItemEntity(record: record(emoji: "📘"))
        #expect(entity.attributeSet.thumbnailData == data)
    }
}
