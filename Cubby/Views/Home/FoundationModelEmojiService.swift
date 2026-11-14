import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

protocol EmojiSuggesting {
    func suggestEmoji(for title: String) async throws -> String
}

enum SuggestionError: Error { case unavailable, invalidResponse }

actor FoundationModelEmojiService: EmojiSuggesting {
    static var isSupported: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }

    func suggestEmoji(for title: String) async throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SuggestionError.invalidResponse }
        try Task.checkCancellation()
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                throw SuggestionError.unavailable
            }
            // Independent titles must not share conversation history or in-flight requests.
            let session = LanguageModelSession(instructions: Self.instructions)
            let start = ContinuousClock.now
            let response = try await session.respond(to: "Title: \(trimmed)\nReturn one emoji.")
            try Task.checkCancellation()
            guard let emoji = Self.validatedEmoji(response.content) else {
                // Model output can contain private inventory text; never log it.
                throw SuggestionError.invalidResponse
            }
            DebugLogger.info("[EmojiAI] Suggestion succeeded duration=\(start.duration(to: .now))")
            return emoji
        }
        #endif
        throw SuggestionError.unavailable
    }

    static let instructions = "You return exactly one Unicode emoji character that best matches the meaning of the given item title. Return only the emoji character with no words."

    /// Accept one complete emoji grapheme, not prose or bare keycap bases such as '1'.
    static func validatedEmoji(_ text: String) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count == 1, let character = text.first else { return nil }
        let scalars = Array(character.unicodeScalars)
        guard let first = scalars.first, first.properties.isEmoji,
              !first.properties.isEmojiModifier else { return nil }
        if (0x1F1E6...0x1F1FF).contains(first.value) {
            return scalars.count == 2 && scalars.allSatisfy { (0x1F1E6...0x1F1FF).contains($0.value) } ? text : nil
        }
        if first.value < 128 {
            return scalars.last?.value == 0x20E3 &&
                scalars.dropFirst().dropLast().allSatisfy { $0.value == 0xFE0F } ? text : nil
        }
        guard scalars.allSatisfy({
            $0.properties.isEmoji || $0.value == 0xFE0F || $0.value == 0x200D ||
                (0xE0020...0xE007F).contains($0.value)
        }), scalars.last?.value != 0x200D else { return nil }
        return text
    }
}
