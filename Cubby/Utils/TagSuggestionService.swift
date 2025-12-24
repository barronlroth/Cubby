import Foundation

enum TagSuggestionService {
    static func suggestions(
        for userInput: String,
        existingTags: some Sequence<String>,
        limit: Int = 5
    ) -> [String] {
        let formatted = userInput.formatAsTag()
        guard !formatted.isEmpty else { return [] }

        let uniqueTags = Set(existingTags.map { $0.formatAsTag() })

        let matches = Array(uniqueTags)
            .filter { $0 != formatted && $0.localizedStandardContains(formatted) }
            .sorted()

        let limited: ArraySlice<String> = matches.prefix(limit)
        return Array(limited)
    }
}
