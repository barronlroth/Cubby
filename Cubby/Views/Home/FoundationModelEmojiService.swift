import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

protocol EmojiSuggesting {
    func suggestEmoji(for title: String, deadline: Duration) async throws -> String
}

enum SuggestionError: Error { case unavailable, timeout, invalidResponse, generationFailed(String) }

private extension Character { var isEmojiLike: Bool { unicodeScalars.contains { $0.properties.isEmoji } } }

actor FoundationModelEmojiService: EmojiSuggesting {
    private(set) var isAvailable: Bool = false
    private var didLogAvailability = false

    #if canImport(FoundationModels)
    private var sessionBox: Any?
    #endif

    init() {}

    static var isSupported: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    func prepareIfNeeded() async {
        #if canImport(FoundationModels)
        if self.sessionBox != nil { return }
        if #available(iOS 26.0, *) {
            // Check availability once
            let availability: String
            switch SystemLanguageModel.default.availability {
            case .available:
                isAvailable = true
                availability = "available"
            case .unavailable(let reason):
                isAvailable = false
                availability = "unavailable(\(reason))"
            @unknown default:
                isAvailable = false
                availability = "unavailable(unknown)"
            }
            if !didLogAvailability {
                DebugLogger.info("[EmojiAI] Foundation model \(availability)")
                didLogAvailability = true
            }

            guard isAvailable else { return }

            // Create a reusable session with concise instructions
            let instructions = """
            You return exactly one Unicode emoji character that best matches the meaning of the given item title. Return only the emoji character with no words.
            """
            if #available(iOS 26.0, *) {
                self.sessionBox = LanguageModelSession(instructions: instructions)
            }
        } else {
            isAvailable = false
            if !didLogAvailability {
                DebugLogger.warning("[EmojiAI] Foundation model unavailable (OS too old)")
                didLogAvailability = true
            }
        }
        #else
        // FoundationModels framework not linked in this build
        isAvailable = false
        if !didLogAvailability {
            DebugLogger.warning("[EmojiAI] Foundation model unavailable (framework missing)")
            didLogAvailability = true
        }
        #endif
    }

    #if canImport(FoundationModels)
    private func generateEmoji(using trimmed: String) async throws -> String {
        if #available(iOS 26.0, *) {
            guard let session = self.sessionBox as? LanguageModelSession else { throw SuggestionError.unavailable }
            let prompt = "Title: \(trimmed)\nReturn one emoji."
            let response = try await session.respond(to: prompt)
            return response.content
        } else {
            throw SuggestionError.unavailable
        }
    }
    #endif

    func suggestEmoji(for title: String, deadline: Duration) async throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SuggestionError.invalidResponse }

        await prepareIfNeeded()
        guard isAvailable else { throw SuggestionError.unavailable }

        let start = Date()
        do {
            let result: String = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask { [trimmed] in
                    #if canImport(FoundationModels)
                    if #available(iOS 26.0, *) {
                        return try await self.generateEmoji(using: trimmed)
                    } else {
                        throw SuggestionError.unavailable
                    }
                    #else
                    throw SuggestionError.unavailable
                    #endif
                }
                group.addTask {
                    try await Task.sleep(for: deadline)
                    throw SuggestionError.timeout
                }
                let value = try await group.next()!
                group.cancelAll()
                return value
            }
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            if let emojiChar = sanitize(result) {
                DebugLogger.info("[EmojiAI] Suggestion success emoji=\(emojiChar) latencyMs=\(elapsed)")
                return emojiChar
            } else {
                DebugLogger.warning("[EmojiAI] Invalid emoji response: \(result)")
                throw SuggestionError.invalidResponse
            }
        } catch SuggestionError.timeout {
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            DebugLogger.warning("[EmojiAI] Suggestion timeout elapsedMs=\(elapsed)")
            throw SuggestionError.timeout
        } catch {
            DebugLogger.error("[EmojiAI] Suggestion failed error=\(error)")
            throw SuggestionError.generationFailed(String(describing: error))
        }
    }

    private func sanitize(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let clusters = Array(trimmed)
        if clusters.count == 1, let first = clusters.first, first.isEmojiLike {
            return String(first)
        }
        if let firstEmoji = clusters.first(where: { $0.isEmojiLike }) {
            return String(firstEmoji)
        }
        return nil
    }
}

