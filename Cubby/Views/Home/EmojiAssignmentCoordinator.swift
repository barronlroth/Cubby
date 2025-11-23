import Foundation
import SwiftData

actor EmojiAssignmentCoordinator {
    static let shared = EmojiAssignmentCoordinator(suggester: FoundationModelEmojiService())

    private let suggester: EmojiSuggesting
    private var inflight: Set<PersistentIdentifier> = []

    init(suggester: EmojiSuggesting) {
        self.suggester = suggester
    }

    func postSaveEmojiEnhancement(for itemID: PersistentIdentifier, title: String, modelContext: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DebugLogger.info("[EmojiAI] Skipping AI suggestion for empty title itemID=\(itemID)")
            return
        }
        guard inflight.insert(itemID).inserted else { return }

        Task(priority: .background) { [weak self] in
            guard let self else { return }
            await self.runEnhancement(for: itemID, title: trimmed, modelContext: modelContext)
            await self.finish(itemID)
        }
    }

    private func finish(_ id: PersistentIdentifier) {
        inflight.remove(id)
    }

    private func runEnhancement(for itemID: PersistentIdentifier, title: String, modelContext: ModelContext) async {
        do {
            // Prepare suggester and check availability
            try await Task.sleep(nanoseconds: 0) // yield
            // FoundationModelEmojiService handles its own availability logging on first use
            let deadline: Duration = .seconds(15)
            let emoji = try await suggester.suggestEmoji(for: title, deadline: deadline)
            await applyEmoji(emoji, to: itemID, in: modelContext)
        } catch SuggestionError.unavailable {
            DebugLogger.warning("[EmojiAI] Foundation model unavailable")
        } catch SuggestionError.timeout {
            DebugLogger.warning("[EmojiAI] Suggestion timeout itemID=\(itemID)")
        } catch {
            DebugLogger.error("[EmojiAI] Suggestion failed itemID=\(itemID) error=\(error)")
        }
    }

    @MainActor
    private func applyEmoji(_ emoji: String, to itemID: PersistentIdentifier, in context: ModelContext) {
        // Attempt to resolve model by persistent identifier
        if let anyModel = try? context.model(for: itemID), let item = anyModel as? InventoryItem {
            if item.emoji != emoji {
                item.emoji = emoji
                item.isPendingAiEmoji = false
                do {
                    try context.save()
                    DebugLogger.info("[EmojiAI] Updated item emoji itemID=\(itemID) source=foundationModel")
                } catch {
                    DebugLogger.error("[EmojiAI] Failed to persist emoji update itemID=\(itemID) error=\(error)")
                }
            }
        } else {
            DebugLogger.warning("[EmojiAI] Item not found for emoji update itemID=\(itemID)")
        }
    }
}

