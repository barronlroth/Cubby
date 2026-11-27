import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Whether the on-device model can read a ramble. Manual entry and JSON work either way.
enum BulkAddAIAvailability: Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupported

    var isAvailable: Bool { self == .available }

    var message: String {
        switch self {
        case .available:
            "Cubby reads your list on this iPhone. Nothing is sent anywhere."
        case .deviceNotEligible:
            "This iPhone doesn't support Apple Intelligence, so Cubby can't sort a ramble. Put one item on each line and choose locations on the next screen."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in Settings to let Cubby sort a ramble. Until then, put one item on each line and choose locations on the next screen."
        case .modelNotReady:
            "Apple Intelligence is still downloading. Try again later, or put one item on each line and choose locations on the next screen."
        case .unsupported:
            "Apple Intelligence isn't available here. Put one item on each line and choose locations on the next screen."
        }
    }
}

enum BulkAddParserError: LocalizedError, Equatable {
    case unavailable(BulkAddAIAvailability)
    case nothingFound
    case modelFailed

    var errorDescription: String? {
        switch self {
        case .unavailable(let availability):
            availability.message
        case .nothingFound:
            "Cubby didn't find any items in that text. Try naming each thing and where it is."
        case .modelFailed:
            "Apple Intelligence couldn't read that text. Try a shorter passage, or put one item on each line."
        }
    }
}

struct BulkAddParseProgress: Equatable {
    let completedPassages: Int
    let totalPassages: Int
}

protocol InventoryTranscriptParsing: Sendable {
    func availability() async -> BulkAddAIAvailability
    func parse(
        transcript: String,
        homeName: String,
        tree: BulkAddLocationTree,
        progress: @escaping @Sendable (BulkAddParseProgress) async -> Void
    ) async throws -> [BulkAddCandidate]
}

/// Turns a spoken walk-through into item rows with the on-device Foundation Model.
///
/// The model only transcribes structure: each item's name, how many, and where the speaker
/// said it is, in the speaker's words. Matching that place to saved locations, creating New
/// paths, and formatting "Headlamps (2)" happen in code (`BulkAddLocationTree`), because the
/// small on-device model forces items into whatever saved location it was shown.
/// Long transcripts are read passage by passage, carrying the current place forward.
/// Transcript text is private inventory data, so it is never logged.
actor FoundationModelInventoryParser: InventoryTranscriptParsing {
    /// Saved paths listed as spelling hints in each prompt.
    static let promptLocationLimit = 60

    private let chunker: TranscriptChunker
    private let includesVocabulary: Bool

    init(chunker: TranscriptChunker = TranscriptChunker(), includesVocabulary: Bool = true) {
        self.chunker = chunker
        self.includesVocabulary = includesVocabulary
    }

    func availability() async -> BulkAddAIAvailability {
        Self.currentAvailability()
    }

    static func currentAvailability() -> BulkAddAIAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceNotEnabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            case .unavailable:
                return .unsupported
            }
        }
        #endif
        return .unsupported
    }

    func parse(
        transcript: String,
        homeName: String,
        tree: BulkAddLocationTree,
        progress: @escaping @Sendable (BulkAddParseProgress) async -> Void
    ) async throws -> [BulkAddCandidate] {
        let availability = Self.currentAvailability()
        guard availability.isAvailable else { throw BulkAddParserError.unavailable(availability) }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let chunks = chunker.chunks(for: transcript)
            guard !chunks.isEmpty else { throw BulkAddParserError.nothingFound }
            let start = ContinuousClock.now
            var candidates: [BulkAddCandidate] = []
            var carriedPlace: [String] = []
            var failedPassages = 0
            await progress(BulkAddParseProgress(completedPassages: 0, totalPassages: chunks.count))

            for chunk in chunks {
                try Task.checkCancellation()
                do {
                    let result = try await readPassage(
                        context: chunk.context,
                        text: chunk.text,
                        carriedPlace: carriedPlace,
                        tree: tree,
                        allowSplit: true
                    )
                    for row in Self.withoutContainerRows(result.rows) {
                        let candidate = Self.candidate(
                            name: row.name, quantity: row.quantity, emoji: row.emoji,
                            place: row.place, tree: tree, carriedPlace: carriedPlace
                        )
                        candidates.append(candidate)
                        if let placed = candidate.destination.flatMap(tree.pathComponents(for:)),
                           !Self.cleanPlace(row.place).isEmpty {
                            carriedPlace = placed
                        }
                    }
                    let ending = Self.cleanPlace(result.endingPlace)
                    if !ending.isEmpty, let resolved = tree.destination(forPath: ending).flatMap(tree.pathComponents(for:)) {
                        carriedPlace = resolved
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    failedPassages += 1
                    // A refused or malformed passage should not discard the rest of the walk-through.
                    DebugLogger.warning("[BulkAddAI] Passage failed type=\(type(of: error))")
                }
                await progress(BulkAddParseProgress(completedPassages: chunk.index + 1, totalPassages: chunks.count))
            }

            DebugLogger.info(
                "[BulkAddAI] Parsed passages=\(chunks.count) failed=\(failedPassages) rows=\(candidates.count) duration=\(start.duration(to: .now))"
            )
            if candidates.isEmpty {
                throw failedPassages == chunks.count ? BulkAddParserError.modelFailed : BulkAddParserError.nothingFound
            }
            return BulkAddMerger().merge(candidates)
        }
        #endif
        throw BulkAddParserError.unavailable(.unsupported)
    }

    static let instructions = """
    You turn a spoken walk-through of a home into an inventory list.
    List each physical belonging the speaker says is kept somewhere. Skip filler, plans, opinions, \
    and things the speaker says they threw away, lost, gave away, or don't have. When the speaker \
    corrects themselves, use the correction.
    For each item, write where it is exactly as the speaker described it, from the room down to \
    the smallest container, one part per entry. "In the garage on shelf two, the red bin has \
    headlamps" means Garage, Shelf 2, Red bin. Do not move an item to a different place than the \
    one the speaker said, even if a saved place sounds similar.
    When the speaker moves to a new room or container, the items that follow are there until \
    they move again. Items listed together share the same place: "the red bin has headlamps, \
    the stove and the cables" puts all three in Garage, Shelf 2, Red bin.
    A bin, box, tote, drawer, or bag that holds other things is part of the place, not an item. \
    Leave out details like "on the floor" or "on the left side".
    """

    /// Converts a model row into a candidate. A row with no place uses the place carried from
    /// earlier in the walk-through; quantity is written into the title in code.
    static func candidate(
        name: String,
        quantity: Int,
        emoji: String,
        place: [String],
        tree: BulkAddLocationTree,
        carriedPlace: [String]
    ) -> BulkAddCandidate {
        let itemKey = BulkAddText.itemKey(stripQuantity(name))
        // Drop a trailing part that just repeats the item ("Under Bed > Guitar" for the guitar case).
        var ownPlace = cleanPlace(place)
        while let last = ownPlace.last, ownPlace.count > 1, tree.match(path: ownPlace) == nil {
            let key = BulkAddText.itemKey(last)
            guard key == itemKey || (!key.contains(" ") && BulkAddText.wordsContain(itemKey, key)) else { break }
            ownPlace.removeLast()
        }
        let spokenPlace = anchoredPlace(
            ownPlace.map(BulkAddText.titleCased),
            carriedPlace: carriedPlace,
            tree: tree
        )
        let destination = tree.destination(forPath: spokenPlace.isEmpty ? carriedPlace : spokenPlace)
        return BulkAddCandidate(
            name: BulkAddText.title(name: BulkAddText.titleCased(stripQuantity(name)), quantity: quantity),
            emoji: FoundationModelEmojiService.validatedEmoji(emoji),
            destination: destination
        )
    }

    /// A container the speaker described ("the blue tote with the decorations") is a place for
    /// the other rows, not an item of its own. Drop rows whose name is another row's place.
    static func withoutContainerRows(_ rows: [PassageRow]) -> [PassageRow] {
        let placeKeys = Set(rows.flatMap { row in cleanPlace(row.place).map(BulkAddText.itemKey) })
        return rows.filter { !placeKeys.contains(BulkAddText.itemKey(stripQuantity($0.name))) }
    }

    /// The model sometimes returns one string like "Garage > Shelf 2" in a single entry.
    static func cleanPlace(_ place: [String]) -> [String] {
        place.flatMap(BulkAddText.pathComponents)
            .filter { !BulkAddText.spokenKey($0).isEmpty }
            .filter { !["unknown", "none", "n/a", "unsorted"].contains(BulkAddText.spokenKey($0)) }
            .filter { !BulkAddText.isPositionDetail($0) }
    }

    /// "Under the sink" said while in the kitchen means Kitchen > Under Sink. When no part of
    /// the spoken place is a saved location and it starts with a room-relative word, it is
    /// placed inside the room the speaker is in.
    static func anchoredPlace(_ spoken: [String], carriedPlace: [String], tree: BulkAddLocationTree) -> [String] {
        guard let first = spoken.first, let room = carriedPlace.first,
              BulkAddText.isRelativeToRoom(first),
              (1...spoken.count).allSatisfy({ tree.match(path: Array(spoken.prefix($0))) == nil }) else {
            return spoken
        }
        return [room] + spoken
    }

    /// Drops a leading count the model left in the name ("2 headlamps", "two headlamps").
    static func stripQuantity(_ name: String) -> String {
        var words = BulkAddText.clean(name).split(separator: " ").map(String.init)
        if words.count > 1, let first = words.first,
           Int(first) != nil || BulkAddText.numberWords[first.lowercased()] != nil {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }

    static func prompt(
        context: String,
        text: String,
        carriedPlace: [String],
        tree: BulkAddLocationTree,
        includesVocabulary: Bool
    ) -> String {
        var sections: [String] = []
        let vocabulary = tree.promptLines(limit: promptLocationLimit)
        if includesVocabulary, !vocabulary.isEmpty {
            sections.append(
                "Places already saved in this home, for spelling only. Use one only if the speaker clearly means it:\n\(vocabulary)"
            )
        }
        if !carriedPlace.isEmpty {
            sections.append("Before this passage the speaker was in: \(carriedPlace.joined(separator: " > "))")
        }
        if !context.isEmpty {
            sections.append("Earlier words, for context only. Do not list items from them:\n\"\"\"\n\(context)\n\"\"\"")
        }
        sections.append("Passage:\n\"\"\"\n\(text)\n\"\"\"")
        sections.append("List the items in this passage and where the speaker said each one is.")
        return sections.joined(separator: "\n\n")
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct GeneratedInventoryPassage {
    @Guide(description: "Each item mentioned in the passage, in order.", .maximumCount(40))
    var items: [GeneratedInventoryRow]

    @Guide(description: "Where the speaker is at the end of the passage, from the room down, one part per entry. Empty if unknown.")
    var endingPlace: [String]
}

@available(iOS 26.0, *)
@Generable
struct GeneratedInventoryRow {
    @Guide(description: "The item's name only, in Title Case, without a number or location. Example: Headlamps")
    var name: String

    @Guide(description: "How many the speaker said there are. 1 if not said.", .range(1...999))
    var quantity: Int

    @Guide(description: "One emoji that matches the item.")
    var emoji: String

    @Guide(description: "Where the speaker said the item is, from the room down to the container, one part per entry. Example: [\"Garage\", \"Shelf 2\", \"Red bin\"]. Empty if the speaker did not say.")
    var place: [String]
}

@available(iOS 26.0, *)
extension FoundationModelInventoryParser {
    struct PassageRow: Sendable {
        var name: String
        var quantity: Int
        var emoji: String
        var place: [String]
    }

    struct PassageResult: Sendable {
        var rows: [PassageRow]
        var endingPlace: [String]
    }

    func readPassage(
        context: String,
        text: String,
        carriedPlace: [String],
        tree: BulkAddLocationTree,
        allowSplit: Bool,
        attempt: Int = 1
    ) async throws -> PassageResult {
        // Each passage gets a fresh session so earlier passages never consume its context.
        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = Self.prompt(
            context: context,
            text: text,
            carriedPlace: carriedPlace,
            tree: tree,
            includesVocabulary: includesVocabulary
        )
        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedInventoryPassage.self,
                options: GenerationOptions(sampling: .greedy)
            )
            return PassageResult(
                rows: response.content.items.map {
                    PassageRow(name: $0.name, quantity: $0.quantity, emoji: $0.emoji, place: $0.place)
                },
                endingPlace: response.content.endingPlace
            )
        } catch {
            if Self.isRateLimited(error), attempt < 4 {
                // Several passages in a row can hit the on-device model's rate limit; back off.
                try await Task.sleep(for: .seconds(2 * attempt))
                return try await readPassage(
                    context: context, text: text, carriedPlace: carriedPlace,
                    tree: tree, allowSplit: allowSplit, attempt: attempt + 1
                )
            }
            guard allowSplit, Self.exceededContext(error) else { throw error }
            // A dense passage: read it as two halves instead.
            let words = text.split(whereSeparator: { $0.isWhitespace })
            guard words.count > 20 else { throw error }
            let middle = words.count / 2
            let first = try await readPassage(
                context: "", text: words[..<middle].joined(separator: " "),
                carriedPlace: carriedPlace, tree: tree, allowSplit: false
            )
            let firstEnding = Self.cleanPlace(first.endingPlace)
            let second = try await readPassage(
                context: "", text: words[middle...].joined(separator: " "),
                carriedPlace: firstEnding.isEmpty ? carriedPlace : firstEnding, tree: tree, allowSplit: false
            )
            return PassageResult(
                rows: first.rows + second.rows,
                endingPlace: second.endingPlace.isEmpty ? first.endingPlace : second.endingPlace
            )
        }
    }

    static func isRateLimited(_ error: Error) -> Bool {
        if let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .rateLimited, .concurrentRequests: return true
            default: break
            }
        }
        if #available(iOS 27.0, *), let error = error as? LanguageModelError, case .rateLimited = error {
            return true
        }
        return false
    }

    static func exceededContext(_ error: Error) -> Bool {
        if let error = error as? LanguageModelSession.GenerationError, case .exceededContextWindowSize = error {
            return true
        }
        if #available(iOS 27.0, *), let error = error as? LanguageModelError, case .contextSizeExceeded = error {
            return true
        }
        return false
    }
}
#endif
