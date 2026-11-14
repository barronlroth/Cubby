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
    private let settlingDuration = 0.42
    private let spinSpeed = 22.0 // Cells per second, independent of display refresh rate.
    private let accelerationDuration = 0.12
    private let slotEmojis = ["🍎", "🚀", "🎸", "📚", "⚽️", "🍕", "🎨", "🎮", "✈️", "💡", "📷", "🧸", "🔑", "📦", "💎"]
    private var cellHeight: CGFloat { fontSize * 1.5 }
    private var viewportSize: CGFloat { fontSize * 2 }
    private var finalEmoji: String { emoji ?? EmojiPicker.emoji(for: fallbackSeed) }
    // Cubic deceleration starts close to the running speed and lands on a whole cell.
    private var destination: Double { ceil(stopPosition + spinSpeed * settlingDuration / 3) }

    var body: some View {
        TimelineView(.animation(paused: startedAt == nil || reduceMotion)) { timeline in
            ZStack {
                if startedAt != nil && !reduceMotion {
                    let position = reelPosition(at: timeline.date)
                    let center = Int(floor(position))
                    ForEach((center - 1)...(center + 1), id: \.self) { index in
                        let distance = position - Double(index)
                        Text(stoppedAt != nil && index == Int(destination)
                             ? finalEmoji
                             : slotEmojis[((index % slotEmojis.count) + slotEmojis.count) % slotEmojis.count])
                            // Compress the top/bottom of the drum without blurring glyphs.
                            .scaleEffect(x: 1, y: max(0.55, 1 - abs(distance) * 0.35))
                            .offset(y: CGFloat(distance) * cellHeight)
                    }
                } else {
                    Text(finalEmoji)
                }
            }
            .font(.system(size: fontSize))
            .frame(width: viewportSize, height: viewportSize)
            .mask {
                // Fade alpha rather than cutting glyphs against an inner square.
                // White supplies mask opacity only; this adds no visible surface color.
                Circle().fill(
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.24),
                        .init(color: .white, location: 0.76),
                        .init(color: .clear, location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                )
            }
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
        // A quick spin-up, then a fast mechanical reel; no extra wait for a minimum spin.
        return elapsed < accelerationDuration
            ? spinSpeed * elapsed * elapsed / (2 * accelerationDuration)
            : spinSpeed * (elapsed - accelerationDuration / 2)
    }
}

private struct SlotMachineTaskState: Hashable {
    let isPendingAiEmoji: Bool
    let reduceMotion: Bool
}

#Preview("Pending reel") {
    @Previewable @State var pending = true
    @Previewable @State var seed = UUID()
    VStack(spacing: 24) {
        ForEach([24.0, 56.0], id: \.self) { size in
            SlotMachineEmojiView(emoji: "🐶", isPendingAiEmoji: pending, fallbackSeed: seed, fontSize: size)
                .background(CubbyDesign.Palette.itemIconBackground, in: Circle())
        }
        Toggle("Choosing emoji", isOn: $pending)
    }
    .padding()
}

#Preview("Reduced motion") {
    SlotMachineEmojiView(emoji: "🐶", isPendingAiEmoji: true, fallbackSeed: UUID())
        .environment(\.cubbyReduceMotionValidationOverride, true)
        .padding()
}
