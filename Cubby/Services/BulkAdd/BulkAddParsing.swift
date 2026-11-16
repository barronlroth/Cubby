import Foundation

/// Where a parsed row should be saved: an existing location in the target home,
/// or a new location path that is created only when the review is saved.
enum BulkAddDestination: Hashable {
    case existing(UUID)
    case new([String])
}

/// One item produced by the parser, the JSON path, or the plain-list fallback.
/// Candidates are deduplicated before they become editable review rows.
struct BulkAddCandidate: Equatable {
    var name: String
    var emoji: String?
    var destination: BulkAddDestination?
}

enum BulkAddText {
    /// Trims and collapses whitespace so "  Red   bin " and "Red bin" compare equal.
    static func clean(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func normalized(_ value: String) -> String {
        clean(value).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// Splits "Garage > Shelf 2 > Red bin" (or "/" and "›" separated) into clean segments.
    static func pathComponents(_ value: String) -> [String] {
        value
            .split(whereSeparator: { $0 == ">" || $0 == "›" || $0 == "/" })
            .map { clean(String($0)) }
            .filter { !$0.isEmpty }
    }

    static func pathKey(_ path: [String]) -> String {
        path.map(normalized).joined(separator: "\u{1F}")
    }
}

/// The target home's locations as full paths, each with a short ID the model can echo back.
/// Short IDs ("L1", "L2", ...) keep the prompt small; UUIDs never leave the device anyway,
/// but 36-character tokens would crowd the model's context window.
struct BulkAddLocationTree: Equatable {
    struct Entry: Equatable, Identifiable {
        let id: UUID
        let shortID: String
        let path: [String]

        var displayPath: String { path.joined(separator: " > ") }
    }

    let entries: [Entry]
    private let entriesByPathKey: [String: Entry]

    init(entries: [Entry]) {
        self.entries = entries
        var index: [String: Entry] = [:]
        for entry in entries where index[BulkAddText.pathKey(entry.path)] == nil {
            index[BulkAddText.pathKey(entry.path)] = entry
        }
        entriesByPathKey = index
    }

    init(homeID: UUID, locations: [AppStorageLocation]) {
        let homeLocations = locations.filter { $0.homeID == homeID }
        let byID = Dictionary(homeLocations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        func path(for location: AppStorageLocation) -> [String] {
            var components: [String] = []
            var current: AppStorageLocation? = location
            var visited = Set<UUID>()
            while let node = current, visited.insert(node.id).inserted {
                components.insert(BulkAddText.clean(node.name), at: 0)
                current = node.parentLocationID.flatMap { byID[$0] }
            }
            return components
        }

        let sorted = homeLocations
            .map { (location: $0, path: path(for: $0)) }
            .sorted { lhs, rhs in
                lhs.path.joined(separator: " > ")
                    .localizedStandardCompare(rhs.path.joined(separator: " > ")) == .orderedAscending
            }
        self.init(
            entries: sorted.enumerated().map { offset, value in
                Entry(id: value.location.id, shortID: "L\(offset + 1)", path: value.path)
            }
        )
    }

    var isEmpty: Bool { entries.isEmpty }

    func entry(id: UUID) -> Entry? {
        entries.first { $0.id == id }
    }

    func entry(shortID: String) -> Entry? {
        let trimmed = BulkAddText.clean(shortID).uppercased()
        return entries.first { $0.shortID == trimmed }
    }

    /// The home's default "Unsorted" location, used when the transcript gives no place.
    var unsorted: Entry? {
        entries.first { $0.path.count == 1 && BulkAddText.normalized($0.path[0]) == "unsorted" }
    }

    /// Exact full-path match first. A partial path ("Red bin", "Shelf 2 > Red bin") matches
    /// only when exactly one location ends with it, so ambiguous names become new rows
    /// the user can re-point instead of silently landing in the wrong room.
    func match(path: [String]) -> Entry? {
        let cleaned = path.map(BulkAddText.clean).filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }
        if let exact = entriesByPathKey[BulkAddText.pathKey(cleaned)] {
            return exact
        }
        let suffix = cleaned.map(BulkAddText.normalized)
        let matches = entries.filter { entry in
            guard entry.path.count > suffix.count else { return false }
            return Array(entry.path.suffix(suffix.count)).map(BulkAddText.normalized) == suffix
        }
        return matches.count == 1 ? matches[0] : nil
    }

    /// Resolves free text to an existing location when possible, otherwise to a new path.
    func destination(forPath path: [String]) -> BulkAddDestination? {
        let cleaned = path.map(BulkAddText.clean).filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }
        if let entry = match(path: cleaned) {
            return .existing(entry.id)
        }
        // Keep the known parent when the model names a new bin inside an existing shelf.
        for prefixLength in stride(from: cleaned.count - 1, through: 1, by: -1) {
            if let parent = entriesByPathKey[BulkAddText.pathKey(Array(cleaned.prefix(prefixLength)))] {
                return .new(parent.path + cleaned.dropFirst(prefixLength))
            }
        }
        return .new(cleaned)
    }

    func displayPath(for destination: BulkAddDestination) -> String {
        switch destination {
        case .existing(let id):
            entry(id: id)?.displayPath ?? "Unknown location"
        case .new(let path):
            path.joined(separator: " > ")
        }
    }

    func pathComponents(for destination: BulkAddDestination) -> [String]? {
        switch destination {
        case .existing(let id):
            entry(id: id)?.path
        case .new(let path):
            path
        }
    }

    /// Compact prompt text: one "L3: Garage > Shelf 2 > Red bin" line per location.
    func promptLines(limit: Int) -> String {
        entries.prefix(limit)
            .map { "\($0.shortID): \($0.displayPath)" }
            .joined(separator: "\n")
    }
}

/// Splits a long ramble into passages that fit the on-device context window.
/// Each passage's `text` is new; `context` repeats the words just before it so the model
/// can resolve "in here" or "next to that" across the cut. The prompt marks the context
/// as already processed, and the merger removes any item the model lists twice anyway.
/// Passages end on a sentence boundary when one is close, so items are rarely split.
struct TranscriptChunker {
    struct Chunk: Equatable {
        let index: Int
        let context: String
        let text: String
    }

    var maximumWords = 220
    var overlapWords = 40

    func chunks(for transcript: String) -> [Chunk] {
        let words = transcript.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return [] }
        let windowSize = max(maximumWords, 1)
        let overlap = min(max(overlapWords, 0), windowSize / 2)

        var chunks: [Chunk] = []
        var start = 0
        while start < words.count {
            var end = min(start + windowSize, words.count)
            if end < words.count {
                // Prefer a sentence end within the last quarter of the window.
                let earliest = start + max(windowSize * 3 / 4, 1)
                if earliest < end,
                   let boundary = (earliest..<end).last(where: { Self.endsSentence(words[$0]) }) {
                    end = boundary + 1
                }
            }
            chunks.append(
                Chunk(
                    index: chunks.count,
                    context: words[max(start - overlap, 0)..<start].joined(separator: " "),
                    text: words[start..<end].joined(separator: " ")
                )
            )
            start = end
        }
        return chunks
    }

    private static func endsSentence(_ word: String) -> Bool {
        guard let last = word.last else { return false }
        return last == "." || last == "!" || last == "?" || last == ";"
    }
}

/// Collapses repeats from chunk overlap and from the speaker mentioning an item twice.
struct BulkAddMerger {
    func merge(_ candidates: [BulkAddCandidate]) -> [BulkAddCandidate] {
        var merged: [BulkAddCandidate] = []
        var indexByKey: [String: Int] = [:]

        for candidate in candidates {
            let name = BulkAddText.clean(candidate.name)
            guard !name.isEmpty else { continue }
            var cleaned = candidate
            cleaned.name = name

            let key = Self.key(name: name, destination: cleaned.destination)
            if let existingIndex = indexByKey[key] {
                if merged[existingIndex].emoji == nil {
                    merged[existingIndex].emoji = cleaned.emoji
                }
                continue
            }

            // The same item seen once without a place and once with one: keep the placed version.
            let unplacedKey = Self.key(name: name, destination: nil)
            if cleaned.destination != nil, let unplacedIndex = indexByKey[unplacedKey] {
                if cleaned.emoji == nil { cleaned.emoji = merged[unplacedIndex].emoji }
                merged[unplacedIndex] = cleaned
                indexByKey[unplacedKey] = nil
                indexByKey[key] = unplacedIndex
                continue
            }
            if cleaned.destination == nil,
               let placedIndex = merged.firstIndex(where: {
                   $0.destination != nil && BulkAddText.normalized($0.name) == BulkAddText.normalized(name)
               }) {
                if merged[placedIndex].emoji == nil { merged[placedIndex].emoji = cleaned.emoji }
                continue
            }

            indexByKey[key] = merged.count
            merged.append(cleaned)
        }
        return merged
    }

    static func key(name: String, destination: BulkAddDestination?) -> String {
        let place: String
        switch destination {
        case .existing(let id):
            place = "id:\(id.uuidString)"
        case .new(let path):
            place = "new:\(BulkAddText.pathKey(path))"
        case nil:
            place = "none"
        }
        return "\(BulkAddText.normalized(name))|\(place)"
    }
}

/// Deterministic input: text that is already a JSON array of `{name, emoji?, location}`.
/// It skips the model entirely. `title` and `locationPath` (Cubby's import keys) are accepted
/// too, and `location` may be "A > B" or ["A", "B"].
enum BulkAddJSONInput {
    enum ParseError: Error, Equatable {
        case notJSON
        case invalidItem(index: Int)
    }

    private struct Row: Decodable {
        let name: String
        let emoji: String?
        let location: [String]?

        private enum CodingKeys: String, CodingKey {
            case name, title, emoji, location, locationPath
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let name = try container.decodeIfPresent(String.self, forKey: .name) {
                self.name = name
            } else {
                self.name = try container.decode(String.self, forKey: .title)
            }
            emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
            let locationKey: CodingKeys = container.contains(.location) ? .location : .locationPath
            if let text = try? container.decodeIfPresent(String.self, forKey: locationKey) {
                location = BulkAddText.pathComponents(text)
            } else {
                location = try container.decodeIfPresent([String].self, forKey: locationKey)
            }
        }
    }

    private struct Wrapper: Decodable {
        let items: [Row]
    }

    /// True when the text looks like JSON, so the caller reports a JSON error
    /// rather than sending malformed JSON to the language model.
    static func looksLikeJSON(_ text: String) -> Bool {
        guard let first = text.first(where: { !$0.isWhitespace }) else { return false }
        return first == "[" || first == "{"
    }

    static func parse(_ text: String, tree: BulkAddLocationTree) throws -> [BulkAddCandidate] {
        let data = Data(text.utf8)
        let decoder = JSONDecoder()
        let rows: [Row]
        if let array = try? decoder.decode([Row].self, from: data) {
            rows = array
        } else if let wrapper = try? decoder.decode(Wrapper.self, from: data) {
            rows = wrapper.items
        } else {
            throw ParseError.notJSON
        }

        return try rows.enumerated().map { index, row in
            let name = BulkAddText.clean(row.name)
            guard !name.isEmpty else { throw ParseError.invalidItem(index: index) }
            return BulkAddCandidate(
                name: name,
                emoji: FoundationModelEmojiService.validatedEmoji(row.emoji ?? ""),
                destination: row.location.flatMap(tree.destination(forPath:))
            )
        }
    }
}

/// Used when Apple Intelligence is unavailable: one item per line, placed in review.
enum BulkAddPlainListInput {
    static func parse(_ text: String) -> [BulkAddCandidate] {
        text
            .split(whereSeparator: \.isNewline)
            .map { line -> String in
                var value = BulkAddText.clean(String(line))
                // Drop list markers such as "-", "*", "•", "1." and "2)".
                if let marker = value.firstMatch(of: /^(?:[-*•]|\d+[.)])\s+/) {
                    value.removeSubrange(marker.range)
                }
                return value
            }
            .filter { !$0.isEmpty }
            .map { BulkAddCandidate(name: $0, emoji: nil, destination: nil) }
    }
}
