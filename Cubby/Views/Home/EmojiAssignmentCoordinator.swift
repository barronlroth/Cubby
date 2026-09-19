import Foundation

/// Owns queued work and its visible deadline. At most one model task is active,
/// including a cancelled task whose model has not acknowledged cancellation yet.
@MainActor
final class EmojiAssignmentCoordinator {
    static let shared = EmojiAssignmentCoordinator(suggester: FoundationModelEmojiService())

    private struct Request {
        let token: UUID
        let title: String
        let initialEmoji: String?
        let repository: CoreDataAppRepository
        let timeout: Task<Void, Never>
    }

    private let suggester: EmojiSuggesting
    private let deadline: Duration
    private var requests: [UUID: Request] = [:]
    private var queue: [UUID] = []
    private var active: (id: UUID, token: UUID, task: Task<Void, Never>)?
    var isIdle: Bool { active == nil && requests.isEmpty }

    init(suggester: EmojiSuggesting, deadline: Duration = .seconds(15)) {
        self.suggester = suggester
        self.deadline = deadline
    }

    func postSaveEmojiEnhancement(for itemID: UUID, title: String, repository: CoreDataAppRepository) {
        guard requests[itemID] == nil,
              let item = try? repository.item(id: itemID), item.isPendingAiEmoji else { return }
        let token = UUID()
        let timeout = Task { [weak self, deadline] in
            do { try await Task.sleep(for: deadline) } catch { return }
            guard let self, self.requests[itemID]?.token == token else { return }
            self.finish(itemID, token: token, emoji: nil)
            if self.active?.token == token { self.active?.task.cancel() }
            DebugLogger.warning("[EmojiAI] Request deadline reached; kept fallback")
        }
        requests[itemID] = Request(token: token, title: title, initialEmoji: item.emoji,
                                   repository: repository, timeout: timeout)
        queue.append(itemID)
        startNext()
    }

    /// Clear pending rows left by an earlier process, but never clear live requests.
    func recoverAbandonedRequests(in repository: CoreDataAppRepository) {
        do {
            for item in try repository.listItems() where item.isPendingAiEmoji && requests[item.id] == nil {
                try repository.completeEmojiSuggestion(id: item.id, expectedTitle: item.title,
                                                       expectedEmoji: item.emoji, emoji: nil)
            }
        } catch {
            DebugLogger.error("[EmojiAI] Could not recover pending state")
        }
    }

    private func startNext() {
        guard active == nil else { return }
        while !queue.isEmpty {
            let id = queue.removeFirst()
            guard let request = requests[id] else { continue }
            let task = Task { [suggester] in
                var emoji: String?
                do {
                    try Task.checkCancellation()
                    let result = try await suggester.suggestEmoji(for: request.title)
                    try Task.checkCancellation()
                    emoji = FoundationModelEmojiService.validatedEmoji(result)
                } catch {
                    // Do not log raw model errors: they may contain private prompt text.
                    DebugLogger.warning("[EmojiAI] Request failed or cancelled; kept fallback")
                }
                self.finish(id, token: request.token, emoji: emoji)
                self.active = nil
                self.startNext()
            }
            active = (id, request.token, task)
            return
        }
    }

    private func finish(_ id: UUID, token: UUID, emoji: String?) {
        guard let request = requests[id], request.token == token else { return }
        requests.removeValue(forKey: id)
        queue.removeAll { $0 == id }
        request.timeout.cancel()
        do {
            try request.repository.completeEmojiSuggestion(id: id, expectedTitle: request.title,
                                                           expectedEmoji: request.initialEmoji, emoji: emoji)
        } catch {
            DebugLogger.error("[EmojiAI] Could not save emoji completion")
        }
    }
}
