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

    static let numberWords: [String: String] = [
        "one": "1", "two": "2", "three": "3", "four": "4", "five": "5", "six": "6",
        "seven": "7", "eight": "8", "nine": "9", "ten": "10", "eleven": "11", "twelve": "12"
    ]
    /// Ordinals name places ("second shelf") but are never item counts ("First Aid Kit").
    static let ordinalWords: [String: String] = [
        "first": "1", "second": "2", "third": "3", "fourth": "4", "fifth": "5"
    ]
    private static let fillerWords: Set<String> = ["the", "a", "an", "my", "our", "this", "that", "his", "her", "their"]
    private static let lowercaseTitleWords: Set<String> = ["of", "and", "in", "on", "the", "a", "an", "for", "with", "to"]

    /// How a spoken place compares to a saved one: "under the bed" matches "Under Bed",
    /// "shelf two" matches "Shelf 2", and case, punctuation, and articles are ignored.
    static func spokenKey(_ segment: String) -> String {
        var words = normalized(segment)
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { numberWords[String($0)] ?? ordinalWords[String($0)] ?? String($0) }
            .filter { !fillerWords.contains($0) }
        while words.count > 1, let first = words.first, leadingPlaceWords.contains(first) {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }

    /// "in the red bin" and "on top shelf" name the same place as "Red Bin" and "Top Shelf".
    private static let leadingPlaceWords: Set<String> = ["in", "inside", "on", "at", "into"]

    /// Spoken position details that are not storage locations of their own: "on the floor",
    /// "on the left side", "by the stairs", "next to the desk", "with the decorations".
    /// They are dropped from the path so the item lands in the place that contains them.
    static func isPositionDetail(_ segment: String) -> Bool {
        let words = normalized(segment).lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !fillerWords.contains($0) }
        guard let first = words.first else { return true }
        let relational: Set<String> = ["by", "near", "beside", "next", "behind", "with", "against", "around", "down", "over", "up", "there", "here", "somewhere"]
        if relational.contains(first) { return true }
        // "Hook by the door", "shelf above the washer": a spot described relative to something else.
        if words.dropFirst().contains(where: { ["by", "near", "beside", "next", "above", "below", "against"].contains($0) }) {
            return true
        }
        let rest = words.drop(while: { leadingPlaceWords.contains($0) })
        if let lead = rest.first, ["floor", "ground", "left", "right", "corner"].contains(lead) { return true }
        let detailOnly: Set<String> = ["floor", "ground", "left", "right", "side", "corner", "back", "front", "middle", "bottom", "top", "there", "here", "it",
                                       "upstairs", "downstairs", "hook", "hooks", "wall", "walls"]
        return !rest.isEmpty && rest.allSatisfy { detailOnly.contains($0) }
    }

    /// Places named relative to the room ("under the sink") belong inside the current room.
    static func isRelativeToRoom(_ segment: String) -> Bool {
        let first = normalized(segment).lowercased().split(separator: " ").first.map(String.init) ?? ""
        return ["under", "beneath", "above", "inside", "behind"].contains(first)
    }

    /// Display form for a new location the speaker named: "the red bin" becomes "Red Bin",
    /// "shelf two" becomes "Shelf 2". Names the speaker already capitalized are kept.
    static func displaySegment(_ segment: String) -> String {
        var words = clean(segment).split(separator: " ").map(String.init)
        while let first = words.first, words.count > 1,
              fillerWords.contains(first.lowercased()) || leadingPlaceWords.contains(first.lowercased()) {
            words.removeFirst()
        }
        if words.count > 1 {
            words = words.enumerated()
                .filter { $0.offset == 0 || !["the", "a", "an", "my", "our"].contains($0.element.lowercased()) }
                .map(\.element)
        }
        let hasCapital = words.contains { $0.first?.isUppercase == true }
        return words.enumerated().map { index, word in
            if let digit = numberWords[word.lowercased()] { return digit }
            if hasCapital { return word }
            if index > 0, lowercaseTitleWords.contains(word) { return word }
            return word.prefix(1).uppercased() + word.dropFirst()
        }.joined(separator: " ")
    }

    /// "Camping stove" becomes "Camping Stove". Words with their own capitals ("iPhone",
    /// "AA") are kept, and short joining words stay lowercase.
    static func titleCased(_ name: String) -> String {
        var text = clean(name)
        // The model sometimes answers in all caps; keep short acronyms like "TV" or "HDMI".
        if !text.contains(where: \.isLowercase), text.split(separator: " ").contains(where: { $0.count > 4 }) {
            text = text.lowercased()
        }
        return text.split(separator: " ").enumerated().map { index, word in
            let text = String(word)
            if text.contains(where: \.isUppercase) && !(text.first?.isUppercase == true && text.dropFirst().allSatisfy { !$0.isUppercase }) {
                return text
            }
            if index > 0, lowercaseTitleWords.contains(text.lowercased()) { return text.lowercased() }
            return text.prefix(1).uppercased() + text.dropFirst()
        }.joined(separator: " ")
    }

    /// "Headlamps" with a quantity of 2 becomes "Headlamps (2)".
    static func title(name: String, quantity: Int) -> String {
        let cleaned = clean(name)
        guard quantity > 1, !cleaned.hasSuffix(")") else { return cleaned }
        return "\(cleaned) (\(quantity))"
    }

    /// Item identity for dedupe: "Sleeping Bag (2)" and "sleeping bags (2)" are the same item.
    static func itemKey(_ name: String) -> String {
        normalized(name).lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { word -> String in
                var text = String(word)
                if text.count > 3, text.hasSuffix("s"), !text.hasSuffix("ss") { text.removeLast() }
                return text
            }
            .joined(separator: " ")
    }

    static func wordsContain(_ container: String, _ part: String) -> Bool {
        guard !part.isEmpty else { return false }
        let containerWords = container.split(separator: " ")
        let partWords = part.split(separator: " ")
        guard partWords.count <= containerWords.count else { return false }
        return (0...(containerWords.count - partWords.count)).contains { start in
            Array(containerWords[start..<(start + partWords.count)]) == partWords
        }
    }
}

/// The target home's locations as full paths. Matching spoken places to these is done
/// here, deterministically; the language model only reports what the speaker said.
struct BulkAddLocationTree: Equatable {
    struct Entry: Equatable, Identifiable {
        let id: UUID
        let path: [String]

        var displayPath: String { path.joined(separator: " > ") }
        var keys: [String] { path.map(BulkAddText.spokenKey) }
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

        self.init(
            entries: homeLocations
                .map { Entry(id: $0.id, path: path(for: $0)) }
                .sorted { $0.displayPath.localizedStandardCompare($1.displayPath) == .orderedAscending }
        )
    }

    var isEmpty: Bool { entries.isEmpty }

    func entry(id: UUID) -> Entry? {
        entries.first { $0.id == id }
    }

    /// The home's default "Unsorted" location, used when the transcript gives no place.
    var unsorted: Entry? {
        entries.first { $0.path.count == 1 && BulkAddText.normalized($0.path[0]) == "unsorted" }
    }

    /// Matches a spoken place to a saved location:
    /// 1. the same full path, ignoring case, articles, and "two" vs "2";
    /// 2. otherwise the only location whose own name matches the last spoken part, when every
    ///    other spoken part fits one of its parents ("Bedroom > under the bed" fits
    ///    "Master Bedroom > Under Bed");
    /// 3. a lone room name may match the only top-level room containing it ("Bedroom").
    /// Anything ambiguous or unknown returns nil, so it becomes a New location to re-point.
    func match(path: [String]) -> Entry? {
        let spoken = path.map(BulkAddText.spokenKey).filter { !$0.isEmpty }
        guard let last = spoken.last else { return nil }
        if let exact = entries.first(where: { $0.keys == spoken }) {
            return exact
        }

        let ancestors = Array(spoken.dropLast())
        let candidates = entries.filter { entry in
            entry.keys.last == last && ancestors.allSatisfy { part in
                entry.keys.dropLast().contains { Self.fits($0, part) }
            }
        }
        if candidates.count == 1 { return candidates[0] }
        if candidates.count > 1 {
            // Prefer the candidate whose parents the speaker named exactly.
            let exactParents = candidates.filter { entry in
                ancestors.allSatisfy { entry.keys.dropLast().contains($0) }
            }
            return exactParents.count == 1 && !ancestors.isEmpty ? exactParents[0] : nil
        }

        if spoken.count == 1 {
            let rooms = entries.filter { $0.path.count == 1 && Self.fits($0.keys[0], last) }
            if rooms.count == 1 { return rooms[0] }
        }
        return nil
    }

    private static func fits(_ saved: String, _ spoken: String) -> Bool {
        saved == spoken || BulkAddText.wordsContain(saved, spoken) || BulkAddText.wordsContain(spoken, saved)
    }

    /// Resolves a spoken place to an existing location, or to a New path that keeps the
    /// deepest existing parent it can find ("Garage > Shelf 2 > blue bin" under a saved
    /// "Garage > Shelf 2" becomes New "Garage > Shelf 2 > Blue Bin").
    func destination(forPath path: [String]) -> BulkAddDestination? {
        var cleaned = path.map(BulkAddText.clean).filter { !BulkAddText.spokenKey($0).isEmpty }
        guard !cleaned.isEmpty else { return nil }
        // "Basement > Garage > Top Shelf": a saved room named after another place starts the path.
        let roomKeys = Set(entries.filter { $0.path.count == 1 }.map { $0.keys[0] })
        if match(path: cleaned) == nil,
           let restart = cleaned.indices.dropFirst().last(where: { roomKeys.contains(BulkAddText.spokenKey(cleaned[$0])) }) {
            cleaned = Array(cleaned[restart...])
        }
        if let entry = match(path: cleaned) {
            return .existing(entry.id)
        }
        for prefixLength in stride(from: cleaned.count - 1, through: 1, by: -1) {
            if let parent = match(path: Array(cleaned.prefix(prefixLength))) {
                return .new(parent.path + cleaned.dropFirst(prefixLength).map(BulkAddText.displaySegment))
            }
        }
        return .new(cleaned.map(BulkAddText.displaySegment))
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

    /// Prompt vocabulary: one saved path per line, so the model spells known places the
    /// same way. It is told to report what was said, not to pick from this list.
    func promptLines(limit: Int) -> String {
        entries.prefix(limit)
            .filter { $0.id != unsorted?.id }
            .map { "- \($0.displayPath)" }
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
        return "\(BulkAddText.itemKey(name))|\(place)"
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
