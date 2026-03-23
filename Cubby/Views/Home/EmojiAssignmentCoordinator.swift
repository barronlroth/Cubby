import Foundation
import CoreData

actor EmojiAssignmentCoordinator {
    static let shared = EmojiAssignmentCoordinator(suggester: FoundationModelEmojiService())

    private let suggester: EmojiSuggesting
    private var inflight: Set<UUID> = []

    init(suggester: EmojiSuggesting) {
        self.suggester = suggester
    }

    func postSaveEmojiEnhancement(
        for itemID: UUID,
        title: String,
        persistenceController: PersistenceController
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DebugLogger.info("[EmojiAI] Skipping AI suggestion for empty title itemID=\(itemID)")
            return
        }
        guard inflight.insert(itemID).inserted else { return }

        Task(priority: .background) { [weak self] in
            guard let self else { return }
            await self.runEnhancement(
                for: itemID,
                title: trimmed,
                persistenceController: persistenceController
            )
            await self.finish(itemID)
        }
    }

    private func finish(_ id: UUID) {
        inflight.remove(id)
    }

    private func runEnhancement(
        for itemID: UUID,
        title: String,
        persistenceController: PersistenceController
    ) async {
        do {
            // Prepare suggester and check availability
            try await Task.sleep(nanoseconds: 0) // yield
            // FoundationModelEmojiService handles its own availability logging on first use
            let deadline: Duration = .seconds(15)
            let emoji = try await suggester.suggestEmoji(for: title, deadline: deadline)
            await applyEmoji(emoji, to: itemID, in: persistenceController)
        } catch SuggestionError.unavailable {
            DebugLogger.warning("[EmojiAI] Foundation model unavailable")
            await clearPendingFlag(for: itemID, in: persistenceController)
        } catch SuggestionError.timeout {
            DebugLogger.warning("[EmojiAI] Suggestion timeout itemID=\(itemID)")
            await clearPendingFlag(for: itemID, in: persistenceController)
        } catch {
            DebugLogger.error("[EmojiAI] Suggestion failed itemID=\(itemID) error=\(error)")
            await clearPendingFlag(for: itemID, in: persistenceController)
        }
    }
    
    @MainActor
    private func clearPendingFlag(for itemID: UUID, in persistenceController: PersistenceController) {
        guard let item = fetchItem(id: itemID, in: persistenceController.persistentContainer.viewContext) else {
            return
        }

        if managedObjectBoolValue(item, forKey: "isPendingAiEmoji") {
            item.setValue(false, forKey: "isPendingAiEmoji")
            try? persistenceController.persistentContainer.viewContext.save()
        }
    }

    @MainActor
    private func applyEmoji(_ emoji: String, to itemID: UUID, in persistenceController: PersistenceController) {
        guard let item = fetchItem(id: itemID, in: persistenceController.persistentContainer.viewContext) else {
            DebugLogger.warning("[EmojiAI] Item not found for emoji update itemID=\(itemID)")
            return
        }

        var shouldSave = false

        if item.value(forKey: "emoji") as? String != emoji {
            item.setValue(emoji, forKey: "emoji")
            shouldSave = true
        }

        if managedObjectBoolValue(item, forKey: "isPendingAiEmoji") {
            item.setValue(false, forKey: "isPendingAiEmoji")
            shouldSave = true
        }

        if shouldSave {
            do {
                try persistenceController.persistentContainer.viewContext.save()
                DebugLogger.info("[EmojiAI] Updated item emoji itemID=\(itemID) source=foundationModel")
            } catch {
                DebugLogger.error("[EmojiAI] Failed to persist emoji update itemID=\(itemID) error=\(error)")
            }
        }
    }

    @MainActor
    private func fetchItem(id: UUID, in context: NSManagedObjectContext) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDInventoryItem")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}

private func managedObjectBoolValue(_ object: NSManagedObject, forKey key: String) -> Bool {
    if let bool = object.value(forKey: key) as? Bool {
        return bool
    }
    if let number = object.value(forKey: key) as? NSNumber {
        return number.boolValue
    }
    return false
}
