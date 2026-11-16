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
/// Long transcripts are read passage by passage; the location the speaker was in at the
/// end of one passage is carried into the next. Transcript text is private inventory
/// data, so it is never logged.
actor FoundationModelInventoryParser: InventoryTranscriptParsing {
    /// Locations listed in each prompt. Larger homes still match by path after parsing.
    static let promptLocationLimit = 100

    private let chunker: TranscriptChunker

    init(chunker: TranscriptChunker = TranscriptChunker()) {
        self.chunker = chunker
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
            var carriedLocation = ""
            var failedPassages = 0
            await progress(BulkAddParseProgress(completedPassages: 0, totalPassages: chunks.count))

            for chunk in chunks {
                try Task.checkCancellation()
                do {
                    let result = try await readPassage(
                        context: chunk.context,
                        text: chunk.text,
                        part: chunk.index + 1,
                        of: chunks.count,
                        carriedLocation: carriedLocation,
                        homeName: homeName,
                        tree: tree,
                        allowSplit: true
                    )
                    candidates += result.rows.map { Self.candidate(from: $0, tree: tree, carriedLocation: carriedLocation) }
                    let ending = BulkAddText.clean(result.endingLocation)
                    if !ending.isEmpty { carriedLocation = Self.resolvedPathText(ending, tree: tree) }
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
    and things the speaker says they threw away, lost, or don't have.
    When the speaker moves into a room or opens a container, the items that follow are stored there \
    until they move again. Use an ID from the known locations when the place matches one. Otherwise \
    write the new place as a path from the room down, like "Garage > Shelf 2 > Red bin".
    Write item names as short Title Case nouns without the location. Put a quantity above one in \
    parentheses, like "Headlamps (2)".
    """

    /// Converts a model row into a candidate, falling back to the carried location
    /// when the model leaves the place blank.
    static func candidate(
        name: String,
        emoji: String,
        locationID: String,
        newLocationPath: String,
        tree: BulkAddLocationTree,
        carriedLocation: String
    ) -> BulkAddCandidate {
        let destination: BulkAddDestination?
        if let entry = tree.entry(shortID: locationID) {
            destination = .existing(entry.id)
        } else if !BulkAddText.pathComponents(newLocationPath).isEmpty {
            destination = tree.destination(forPath: BulkAddText.pathComponents(newLocationPath))
        } else {
            destination = tree.destination(forPath: BulkAddText.pathComponents(carriedLocation))
        }
        return BulkAddCandidate(
            name: name,
            emoji: FoundationModelEmojiService.validatedEmoji(emoji),
            destination: destination
        )
    }

    /// The model may answer the ending location with an ID; carry it as a readable path.
    static func resolvedPathText(_ value: String, tree: BulkAddLocationTree) -> String {
        tree.entry(shortID: value)?.displayPath ?? value
    }

    static func prompt(
        context: String,
        text: String,
        part: Int,
        of total: Int,
        carriedLocation: String,
        homeName: String,
        tree: BulkAddLocationTree
    ) -> String {
        var sections: [String] = []
        if tree.isEmpty {
            sections.append("Known locations in \(homeName): none yet.")
        } else {
            sections.append("Known locations in \(homeName):\n\(tree.promptLines(limit: promptLocationLimit))")
        }
        if !carriedLocation.isEmpty {
            sections.append("At the start of this passage the speaker is in: \(carriedLocation)")
        }
        if !context.isEmpty {
            sections.append("Already processed, for context only. Do not list items from it:\n\"\"\"\n\(context)\n\"\"\"")
        }
        sections.append("Passage \(part) of \(total):\n\"\"\"\n\(text)\n\"\"\"")
        sections.append("List the items in this passage and where each one is kept.")
        return sections.joined(separator: "\n\n")
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct GeneratedInventoryPassage {
    @Guide(description: "Each item mentioned in the passage, in order.", .maximumCount(40))
    var items: [GeneratedInventoryRow]

    @Guide(description: "Where the speaker is at the end of the passage: a known location ID like L3, or a path like Garage > Shelf 2. Empty if unknown.")
    var endingLocation: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedInventoryRow {
    @Guide(description: "Short Title Case item name, with a quantity above one in parentheses, like Headlamps (2).")
    var name: String

    @Guide(description: "One emoji that matches the item.")
    var emoji: String

    @Guide(description: "ID of the known location where the item is kept, like L3. Empty when no known location fits.")
    var locationID: String

    @Guide(description: "When locationID is empty, the new location path from the room down, like Garage > Shelf 2 > Red bin. Otherwise empty.")
    var newLocationPath: String
}

@available(iOS 26.0, *)
private extension FoundationModelInventoryParser {
    struct PassageResult {
        var rows: [GeneratedInventoryRow]
        var endingLocation: String
    }

    static func candidate(
        from row: GeneratedInventoryRow,
        tree: BulkAddLocationTree,
        carriedLocation: String
    ) -> BulkAddCandidate {
        candidate(
            name: row.name,
            emoji: row.emoji,
            locationID: row.locationID,
            newLocationPath: row.newLocationPath,
            tree: tree,
            carriedLocation: carriedLocation
        )
    }

    func readPassage(
        context: String,
        text: String,
        part: Int,
        of total: Int,
        carriedLocation: String,
        homeName: String,
        tree: BulkAddLocationTree,
        allowSplit: Bool
    ) async throws -> PassageResult {
        // Each passage gets a fresh session so earlier passages never consume its context.
        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = Self.prompt(
            context: context,
            text: text,
            part: part,
            of: total,
            carriedLocation: carriedLocation,
            homeName: homeName,
            tree: tree
        )
        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedInventoryPassage.self,
                options: GenerationOptions(temperature: 0.2)
            )
            return PassageResult(rows: response.content.items, endingLocation: response.content.endingLocation)
        } catch let error as LanguageModelSession.GenerationError {
            guard allowSplit, case .exceededContextWindowSize = error else { throw error }
            // A dense passage or a large location list: read it as two halves instead.
            let words = text.split(whereSeparator: { $0.isWhitespace })
            guard words.count > 20 else { throw error }
            let middle = words.count / 2
            let firstHalf = words[..<middle].joined(separator: " ")
            let secondHalf = words[middle...].joined(separator: " ")
            let first = try await readPassage(
                context: "", text: firstHalf, part: part, of: total,
                carriedLocation: carriedLocation, homeName: homeName, tree: tree, allowSplit: false
            )
            let firstEnding = BulkAddText.clean(first.endingLocation)
            let second = try await readPassage(
                context: "", text: secondHalf, part: part, of: total,
                carriedLocation: firstEnding.isEmpty ? carriedLocation : Self.resolvedPathText(firstEnding, tree: tree),
                homeName: homeName, tree: tree, allowSplit: false
            )
            return PassageResult(
                rows: first.rows + second.rows,
                endingLocation: second.endingLocation.isEmpty ? first.endingLocation : second.endingLocation
            )
        }
    }
}
#endif
