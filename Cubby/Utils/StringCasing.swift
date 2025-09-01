import Foundation

extension String {
    /// Returns a Title Cased version of the string using common English rules.
    /// - Keeps first and last words capitalized
    /// - Keeps "small words" lowercased (e.g., "a", "an", "the", "of") unless first/last
    /// - Preserves existing acronyms (ALL CAPS) and mixed-case words (e.g., "iPhone")
    /// - Title-cases hyphenated words segment-by-segment
    func titleCased() -> String {
        let smallWords: Set<String> = [
            "a", "an", "and", "as", "at", "but", "by", "for", "from",
            "in", "into", "nor", "of", "on", "onto", "or", "over",
            "per", "the", "to", "via", "vs", "vs.", "with", "up",
            "down", "off", "upon"
        ]

        // Normalize whitespace
        let parts = self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return "" }

        func hasMixedCase(_ s: String) -> Bool {
            // true if contains any lowercase and uppercase letter
            let hasLower = s.rangeOfCharacter(from: .lowercaseLetters) != nil
            let hasUpper = s.rangeOfCharacter(from: .uppercaseLetters) != nil
            return hasLower && hasUpper
        }

        func isAllCapsWord(_ s: String) -> Bool {
            // Consider it an acronym if there is at least one letter and all letters are uppercase
            let letters = s.unicodeScalars.filter { CharacterSet.letters.contains($0) }
            guard !letters.isEmpty else { return false }
            return s == s.uppercased()
        }

        func splitEdgePunctuation(_ token: String) -> (leading: String, core: String, trailing: String) {
            var scalars = Array(token.unicodeScalars)
            var start = 0
            var end = scalars.count - 1
            let allowedInCore = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'"))
            while start < scalars.count, !allowedInCore.contains(scalars[start]) { start += 1 }
            while end >= 0, !allowedInCore.contains(scalars[end]) { end -= 1 }
            if start > end { return (token, "", "") }
            let leading = String(UnicodeScalarView(scalars[0..<start]))
            let core = String(UnicodeScalarView(scalars[start...end]))
            let trailing = String(UnicodeScalarView(scalars[(end+1)..<scalars.count]))
            return (leading, core, trailing)
        }

        func titleCaseCore(_ core: String, forceCapitalize: Bool) -> String {
            // Preserve existing mixed-case words (e.g., iPhone) and acronyms
            if hasMixedCase(core) || isAllCapsWord(core) { return core }
            guard let first = core.first else { return core }
            let firstStr = String(first).uppercased()
            let rest = core.dropFirst().lowercased()
            return firstStr + rest
        }

        var result: [String] = []
        for (i, rawWord) in parts.enumerated() {
            let isFirst = (i == 0)
            let isLast = (i == parts.count - 1)
            let needsCapitalization = isFirst || isLast

            // Handle hyphenated tokens segment-by-segment
            let hyphenSegments = rawWord.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
            var processedSegments: [String] = []
            for seg in hyphenSegments {
                if seg.isEmpty { processedSegments.append(seg); continue }
                let (leading, core, trailing) = splitEdgePunctuation(seg)
                if core.isEmpty { processedSegments.append(seg); continue }

                let lowerCore = core.lowercased()
                let isSmall = smallWords.contains(lowerCore)
                let cased: String
                if isSmall && !needsCapitalization {
                    cased = lowerCore
                } else {
                    cased = titleCaseCore(core, forceCapitalize: needsCapitalization)
                }
                processedSegments.append(leading + cased + trailing)
            }
            result.append(processedSegments.joined(separator: "-"))
        }

        return result.joined(separator: " ")
    }
}

