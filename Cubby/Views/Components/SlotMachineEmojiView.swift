import SwiftUI

struct SlotMachineEmojiView: View {
    let item: InventoryItem
    let fontSize: CGFloat
    
    @State private var currentEmoji: String
    @State private var scale: CGFloat = 1.0
    @State private var wasSpinning = false
    
    // Animation Constants
    private let spinDuration: UInt64 = 80_000_000 // 0.08s
    private let scaleUp: CGFloat = 1.4
    private let scaleNormal: CGFloat = 1.0
    private let springResponse: Double = 0.3
    private let springDamping: Double = 0.6
    
    // A curated list of emojis for the slot machine effect
    private let slotEmojis = ["🍎", "🚀", "🎸", "📚", "⚽️", "🍕", "🎨", "🎮", "✈️", "💡", "📷", "🧸", "🔑", "📦", "💎"]
    
    init(item: InventoryItem, fontSize: CGFloat = 24) {
        self.item = item
        self.fontSize = fontSize
        _currentEmoji = State(initialValue: item.emoji ?? "📦")
    }
    
    var body: some View {
        Text(currentEmoji)
            .font(.system(size: fontSize))
            .scaleEffect(scale)
            .blur(radius: item.isPendingAiEmoji ? 0.5 : 0)
            .task(id: item.isPendingAiEmoji) {
                if item.isPendingAiEmoji {
                    wasSpinning = true
                    while !Task.isCancelled {
                        currentEmoji = slotEmojis.randomElement() ?? "📦"
                        try? await Task.sleep(nanoseconds: spinDuration)
                    }
                } else {
                    if wasSpinning {
                        wasSpinning = false
                        stopSpinning()
                    } else {
                        currentEmoji = item.emoji ?? "📦"
                    }
                }
            }
            .onChange(of: item.emoji) { _, newEmoji in
                if !item.isPendingAiEmoji {
                    currentEmoji = newEmoji ?? "📦"
                }
            }
    }
    
    private func stopSpinning() {
        // Set final emoji
        currentEmoji = item.emoji ?? "📦"
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Lock-in animation
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            scale = scaleUp
        }
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping).delay(0.1)) {
            scale = scaleNormal
        }
    }
}
