import SwiftUI

struct SlotMachineEmojiView: View {
    let emoji: String?
    let isPendingAiEmoji: Bool
    let fallbackSeed: UUID
    let fontSize: CGFloat
    
    @State private var currentEmoji: String
    @State private var scale: CGFloat = 1.0
    @State private var wasSpinning = false
    
    // Animation Constants
    private let initialSpinDelay: UInt64 = 160_000_000 // 0.16s
    private let minimumSpinDelay: UInt64 = 40_000_000 // 0.04s
    private let accelerationFactor: Double = 0.85
    private let decelerationFactor: Double = 1.25
    private let decelerationSteps = 6
    private let scaleUp: CGFloat = 1.4
    private let scaleNormal: CGFloat = 1.0
    private let springResponse: Double = 0.3
    private let springDamping: Double = 0.6
    @State private var spinFeedbackGenerator: UIImpactFeedbackGenerator?
    @State private var lockFeedbackGenerator: UIImpactFeedbackGenerator?
    
    // A curated list of emojis for the slot machine effect
    private let slotEmojis = ["🍎", "🚀", "🎸", "📚", "⚽️", "🍕", "🎨", "🎮", "✈️", "💡", "📷", "🧸", "🔑", "📦", "💎"]
    
    init(
        emoji: String?,
        isPendingAiEmoji: Bool,
        fallbackSeed: UUID,
        fontSize: CGFloat = 24
    ) {
        self.emoji = emoji
        self.isPendingAiEmoji = isPendingAiEmoji
        self.fallbackSeed = fallbackSeed
        self.fontSize = fontSize
        _currentEmoji = State(initialValue: emoji ?? EmojiPicker.emoji(for: fallbackSeed))
    }
    
    var body: some View {
        Text(currentEmoji)
            .font(.system(size: fontSize))
            .scaleEffect(scale)
            .blur(radius: isPendingAiEmoji ? 0.5 : 0)
            .task(id: isPendingAiEmoji) {
                if isPendingAiEmoji {
                    wasSpinning = true
                    await spinWithAcceleration()
                } else {
                    if wasSpinning {
                        wasSpinning = false
                        await stopSpinningWithDeceleration()
                    } else {
                        currentEmoji = emoji ?? EmojiPicker.emoji(for: fallbackSeed)
                    }
                }
            }
            .onChange(of: emoji) { _, newEmoji in
                if !isPendingAiEmoji {
                    currentEmoji = newEmoji ?? EmojiPicker.emoji(for: fallbackSeed)
                }
            }
    }
    
    private func spinWithAcceleration() async {
        await MainActor.run {
            spinHaptics().prepare()
        }
        
        var currentDelay = initialSpinDelay
        while !Task.isCancelled {
            await MainActor.run {
                currentEmoji = slotEmojis.randomElement() ?? "📦"
                spinHaptics().impactOccurred(intensity: 0.25)
            }

            do {
                try await Task.sleep(nanoseconds: currentDelay)
            } catch {
                break
            }
            currentDelay = max(minimumSpinDelay, UInt64(Double(currentDelay) * accelerationFactor))
        }
    }
    
    private func stopSpinningWithDeceleration() async {
        await MainActor.run {
            spinHaptics().prepare()
        }
        
        var currentDelay = minimumSpinDelay
        for _ in 0..<decelerationSteps {
            if Task.isCancelled { return }
            await MainActor.run {
                currentEmoji = slotEmojis.randomElement() ?? "📦"
                spinHaptics().impactOccurred(intensity: 0.35)
            }
            
            do {
                try await Task.sleep(nanoseconds: currentDelay)
            } catch {
                return
            }
            currentDelay = min(initialSpinDelay, UInt64(Double(currentDelay) * decelerationFactor))
        }

        if Task.isCancelled { return }
        
        await MainActor.run {
            // Set final emoji
            currentEmoji = emoji ?? EmojiPicker.emoji(for: fallbackSeed)
            
            // Lock-in haptic feedback
            lockHaptics().impactOccurred()
            
            // Lock-in animation
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                scale = scaleUp
            }
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping).delay(0.1)) {
                scale = scaleNormal
            }
        }
    }

    @MainActor
    private func spinHaptics() -> UIImpactFeedbackGenerator {
        if let generator = spinFeedbackGenerator {
            return generator
        }
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        spinFeedbackGenerator = generator
        return generator
    }

    @MainActor
    private func lockHaptics() -> UIImpactFeedbackGenerator {
        if let generator = lockFeedbackGenerator {
            return generator
        }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        lockFeedbackGenerator = generator
        return generator
    }
}
