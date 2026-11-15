import Foundation
import UIKit

/// Renders an item's emoji as a small PNG for system surfaces that only accept image data,
/// such as Siri, Shortcuts, and Spotlight result icons.
enum InventoryItemEmojiImage {
    /// The emoji Cubby shows for an item, matching in-app rows when none is saved.
    static func emoji(_ saved: String?, for id: UUID) -> String {
        if let saved = saved?.trimmingCharacters(in: .whitespacesAndNewlines), !saved.isEmpty {
            return saved
        }
        return EmojiPicker.emoji(for: id)
    }

    private static let cache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 256
        return cache
    }()

    static func pngData(for emoji: String) -> Data? {
        if let cached = cache.object(forKey: emoji as NSString) {
            return cached as Data
        }
        let side: CGFloat = 120
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: side * 0.8)]
        let text = emoji as NSString
        let data = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).pngData { _ in
            let size = text.size(withAttributes: attributes)
            let origin = CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2)
            text.draw(at: origin, withAttributes: attributes)
        }
        cache.setObject(data as NSData, forKey: emoji as NSString)
        return data
    }
}
