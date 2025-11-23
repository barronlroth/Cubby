import SwiftUI

struct SlotMachineEmojiView: View {
    let item: InventoryItem
    let fontSize: CGFloat
    
    @State private var currentEmoji: String
    @State private var timer: Timer?
    @State private var isSpinning = false
    @State private var scale: CGFloat = 1.0
    
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
            .blur(radius: isSpinning ? 0.5 : 0)
            .onAppear {
                if item.isPendingAiEmoji {
                    startSpinning()
                } else {
                    currentEmoji = item.emoji ?? "📦"
                }
            }
            .onChange(of: item.isPendingAiEmoji) { oldValue, newValue in
                if newValue {
                    startSpinning()
                } else {
                    stopSpinning()
                }
            }
            // Also watch for emoji changes in case the flag updates after the emoji
            .onChange(of: item.emoji) { _, newEmoji in
                if !item.isPendingAiEmoji {
                    currentEmoji = newEmoji ?? "📦"
                }
            }
    }
    
    private func startSpinning() {
        guard !isSpinning else { return }
        isSpinning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            currentEmoji = slotEmojis.randomElement() ?? "📦"
        }
    }
    
    private func stopSpinning() {
        guard isSpinning else { return }
        isSpinning = false
        timer?.invalidate()
        timer = nil
        
        // Set final emoji
        currentEmoji = item.emoji ?? "📦"
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Lock-in animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.4
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
            scale = 1.0
        }
    }
}
