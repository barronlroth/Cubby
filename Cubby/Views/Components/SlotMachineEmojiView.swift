import SwiftUI

struct SlotMachineEmojiView: View {
    let emoji: String?
    let isPendingAiEmoji: Bool
    let fallbackSeed: UUID
    var fontSize: CGFloat = 24

    @Environment(\.cubbyReduceMotion) private var reduceMotion
    @State private var startedAt: Date?
    @State private var stoppedAt: Date?
    @State private var stopPosition: Double = 0

    // Reel geometry and timing are local to this continuous-motion effect.
    private let settlingDuration = 0.6
    private let slotEmojis = ["🍎", "🚀", "🎸", "📚", "⚽️", "🍕", "🎨", "🎮", "✈️", "💡", "📷", "🧸", "🔑", "📦", "💎"]
    private var cellHeight: CGFloat { fontSize * 1.5 }
    private var finalEmoji: String { emoji ?? EmojiPicker.emoji(for: fallbackSeed) }
    private var destination: Double { ceil(stopPosition) + 2 }

    var body: some View {
        TimelineView(.animation(paused: startedAt == nil || reduceMotion)) { timeline in
            ZStack {
                if startedAt != nil && !reduceMotion {
                    let position = reelPosition(at: timeline.date)
                    let center = Int(floor(position))
                    ForEach((center - 1)...(center + 1), id: \.self) { index in
                        Text(stoppedAt != nil && index == Int(destination)
                             ? finalEmoji
                             : slotEmojis[((index % slotEmojis.count) + slotEmojis.count) % slotEmojis.count])
                            .offset(y: CGFloat(position - Double(index)) * cellHeight)
                    }
                } else {
                    Text(finalEmoji)
                }
            }
            .font(.system(size: fontSize))
            .frame(width: cellHeight, height: cellHeight)
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPendingAiEmoji ? "Choosing emoji" : finalEmoji)
        .task(id: SlotMachineTaskState(isPendingAiEmoji: isPendingAiEmoji, reduceMotion: reduceMotion)) {
            guard CubbyDesign.Motion.allowsContinuousMotion(reduceMotion: reduceMotion) else {
                startedAt = nil
                stoppedAt = nil
                return
            }
            if isPendingAiEmoji {
                stoppedAt = nil
                startedAt = Date()
            } else if startedAt != nil {
                let now = Date()
                stopPosition = reelPosition(at: now)
                stoppedAt = now
                do {
                    try await Task.sleep(for: .seconds(settlingDuration))
                } catch { return }
                guard !Task.isCancelled else { return }
                startedAt = nil
                stoppedAt = nil
            }
        }
    }

    private func reelPosition(at date: Date) -> Double {
        if let stoppedAt {
            let progress = min(1, max(0, date.timeIntervalSince(stoppedAt) / settlingDuration))
            let eased = 1 - pow(1 - progress, 3)
            return stopPosition + (destination - stopPosition) * eased
        }
        guard let startedAt else { return 0 }
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        // Accelerate over the first half second, then maintain seven cells/second.
        return elapsed < 0.5 ? 7 * elapsed * elapsed : 7 * elapsed - 1.75
    }
}

private struct SlotMachineTaskState: Hashable {
    let isPendingAiEmoji: Bool
    let reduceMotion: Bool
}

#Preview("Pending reel") {
    SlotMachineEmojiView(emoji: "🐶", isPendingAiEmoji: true, fallbackSeed: UUID())
        .padding()
}

#Preview("Reduced motion") {
    SlotMachineEmojiView(emoji: "🐶", isPendingAiEmoji: true, fallbackSeed: UUID())
        .environment(\.cubbyReduceMotionValidationOverride, true)
        .padding()
}
