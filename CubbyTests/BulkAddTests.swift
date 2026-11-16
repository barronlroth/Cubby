import Foundation
import Testing
@testable import Cubby

// MARK: Fixtures

private enum SampleRambles {
    static let garage = """
    Okay so I'm in the garage now. On shelf two there's the red bin, and in the red bin I've got \
    two headlamps, the camping stove, and um a bag of tent stakes. Next to it on the same shelf is \
    the jumper cables. Then on the top shelf, uh, the Christmas lights, like three boxes of them.
    """

    static let kitchen = """
    Kitchen. Junk drawer has the batteries, AA and AAA, a tape measure, and the spare house keys. \
    Under the sink, the fire extinguisher. In the pantry on the left side there's the stand mixer. \
    Actually no, I gave the bread machine away so skip that one.
    """

    /// A long walk-around: about 2,000 words across several rooms.
    static var walkAround: String {
        let rooms = [
            "Now I'm walking into the hall closet. On the top shelf there's the winter hats and the spare light bulbs.",
            "Moving on to the office. The desk drawer has the label maker, the stapler, and the passport folder.",
            "In the guest bedroom closet there's the vacuum and two sleeping bags on the floor.",
            "Back out to the garage. The tool wall has the cordless drill, the socket set, and the stud finder.",
            "Then the basement storage room. The blue tote has the Halloween decorations and the extra extension cords."
        ]
        var sentences: [String] = []
        var index = 0
        while sentences.joined(separator: " ").split(separator: " ").count < 2_000 {
            sentences.append(rooms[index % rooms.count])
            sentences.append("Um, let me think, yeah, and I think that's about it for this spot, okay.")
            index += 1
        }
        return sentences.joined(separator: " ")
    }
}

private func location(
    _ name: String,
    id: UUID = UUID(),
    home: UUID,
    parent: UUID? = nil,
    path: String
) -> AppStorageLocation {
    AppStorageLocation(
        id: id, name: name, createdAt: .distantPast, modifiedAt: .distantPast,
        depth: path.components(separatedBy: " > ").count - 1, homeID: home, homeName: "Home",
        parentLocationID: parent, fullPath: path, childLocationIDs: [], itemCount: 0
    )
}

private func item(_ title: String, home: UUID, location: AppStorageLocation) -> AppInventoryItem {
    AppInventoryItem(
        id: UUID(), title: title, itemDescription: nil, photoFileName: nil, emoji: "📦",
        isPendingAiEmoji: false, createdAt: .distantPast, modifiedAt: .distantPast, tags: [],
        homeID: home, homeName: "Home", storageLocationID: location.id,
        storageLocationName: location.name, storageLocationPath: location.fullPath
    )
}

/// Garage > Shelf 2 > Red bin, Garage > Top Shelf, Kitchen > Top Shelf, and Unsorted.
struct BulkAddHomeFixture {
    let homeID = UUID()
    let unsorted: AppStorageLocation
    let garage: AppStorageLocation
    let shelf2: AppStorageLocation
    let redBin: AppStorageLocation
    let garageTop: AppStorageLocation
    let kitchen: AppStorageLocation
    let kitchenTop: AppStorageLocation

    init() {
        unsorted = location("Unsorted", home: homeID, path: "Unsorted")
        garage = location("Garage", home: homeID, path: "Garage")
        shelf2 = location("Shelf 2", home: homeID, parent: garage.id, path: "Garage > Shelf 2")
        redBin = location("Red bin", home: homeID, parent: shelf2.id, path: "Garage > Shelf 2 > Red bin")
        garageTop = location("Top Shelf", home: homeID, parent: garage.id, path: "Garage > Top Shelf")
        kitchen = location("Kitchen", home: homeID, path: "Kitchen")
        kitchenTop = location("Top Shelf", home: homeID, parent: kitchen.id, path: "Kitchen > Top Shelf")
    }

    var locations: [AppStorageLocation] { [unsorted, garage, shelf2, redBin, garageTop, kitchen, kitchenTop] }
    var tree: BulkAddLocationTree { BulkAddLocationTree(homeID: homeID, locations: locations) }
}

// MARK: Chunking

@Suite("Bulk add: transcript chunking")
struct TranscriptChunkerTests {
    @Test("A short ramble is one passage with no context")
    func shortRambleIsOnePassage() {
        let chunks = TranscriptChunker().chunks(for: SampleRambles.garage)
        #expect(chunks.count == 1)
        #expect(chunks.first?.context == "")
        #expect(chunks.first?.text.hasPrefix("Okay so I'm in the garage") == true)
    }

    @Test("Empty text has no passages")
    func emptyText() {
        #expect(TranscriptChunker().chunks(for: "  \n ").isEmpty)
    }

    @Test("A 2,000-word walk-around splits into passages that cover every word once")
    func longRambleCoversEveryWord() {
        let transcript = SampleRambles.walkAround
        let words = transcript.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let chunker = TranscriptChunker(maximumWords: 220, overlapWords: 40)
        let chunks = chunker.chunks(for: transcript)

        #expect(words.count >= 2_000)
        #expect(chunks.count >= 9)
        #expect(chunks.map(\.index) == Array(chunks.indices))
        let rejoined = chunks.flatMap { $0.text.split(separator: " ").map(String.init) }
        #expect(rejoined == words)
        for chunk in chunks {
            #expect(chunk.text.split(separator: " ").count <= 220)
        }
    }

    @Test("Each passage carries the tail of the previous one as context")
    func contextIsPreviousTail() {
        let chunks = TranscriptChunker(maximumWords: 220, overlapWords: 40).chunks(for: SampleRambles.walkAround)
        for (previous, next) in zip(chunks, chunks.dropFirst()) {
            let previousWords = previous.text.split(separator: " ")
            let contextWords = next.context.split(separator: " ")
            #expect(contextWords.count == min(40, previousWords.count))
            #expect(Array(previousWords.suffix(contextWords.count)) == contextWords)
        }
    }

    @Test("Passages end at a sentence boundary when one is near")
    func passagesEndAtSentences() {
        let chunks = TranscriptChunker(maximumWords: 220, overlapWords: 40).chunks(for: SampleRambles.walkAround)
        for chunk in chunks.dropLast() {
            #expect(chunk.text.last == "." || chunk.text.last == "?" || chunk.text.last == "!")
        }
    }

    @Test("Text without punctuation still splits at the word limit")
    func unpunctuatedText() {
        let transcript = Array(repeating: "headlamp", count: 500).joined(separator: " ")
        let chunks = TranscriptChunker(maximumWords: 100, overlapWords: 10).chunks(for: transcript)
        #expect(chunks.count == 5)
        #expect(chunks.allSatisfy { $0.text.split(separator: " ").count == 100 })
    }
}

// MARK: Location matching

@Suite("Bulk add: location matching")
struct BulkAddLocationTreeTests {
    let fixture = BulkAddHomeFixture()

    @Test("Builds full paths with short IDs from the home's locations only")
    func buildsPaths() {
        let otherHome = location("Attic", home: UUID(), path: "Attic")
        let tree = BulkAddLocationTree(homeID: fixture.homeID, locations: fixture.locations + [otherHome])
        #expect(tree.entries.count == 7)
        #expect(tree.entries.map(\.displayPath).contains("Garage > Shelf 2 > Red bin"))
        #expect(!tree.entries.map(\.displayPath).contains("Attic"))
        #expect(tree.entries.map(\.shortID) == (1...7).map { "L\($0)" })
        let redBin = tree.entries.first { $0.id == fixture.redBin.id }
        #expect(tree.entry(shortID: " l\(redBin!.shortID.dropFirst()) ")?.id == fixture.redBin.id)
        #expect(tree.unsorted?.id == fixture.unsorted.id)
    }

    @Test("Full paths match regardless of case, spacing, or separator")
    func exactMatch() {
        let tree = fixture.tree
        #expect(tree.match(path: ["garage", "shelf  2", "RED BIN"])?.id == fixture.redBin.id)
        #expect(tree.match(path: BulkAddText.pathComponents("Garage / Shelf 2 / Red bin"))?.id == fixture.redBin.id)
        #expect(tree.match(path: BulkAddText.pathComponents("Garage › Shelf 2"))?.id == fixture.shelf2.id)
    }

    @Test("A partial path matches only when exactly one location ends with it")
    func suffixMatch() {
        let tree = fixture.tree
        #expect(tree.match(path: ["Red Bin"])?.id == fixture.redBin.id)
        #expect(tree.match(path: ["Shelf 2", "Red bin"])?.id == fixture.redBin.id)
        // Garage > Top Shelf and Kitchen > Top Shelf are both "Top Shelf".
        #expect(tree.match(path: ["Top Shelf"]) == nil)
        #expect(tree.destination(forPath: ["Top Shelf"]) == .new(["Top Shelf"]))
        #expect(tree.match(path: []) == nil)
    }

    @Test("A new container under a known location keeps the known parent")
    func newChildOfKnownLocation() {
        let tree = fixture.tree
        #expect(tree.destination(forPath: ["Garage", "Shelf 2", "Blue bin"]) == .new(["Garage", "Shelf 2", "Blue bin"]))
        #expect(tree.destination(forPath: ["garage", "Pegboard"]) == .new(["Garage", "Pegboard"]))
        #expect(tree.destination(forPath: ["Attic", "Box 3"]) == .new(["Attic", "Box 3"]))
    }
}

// MARK: Merging and dedupe

@Suite("Bulk add: merging")
struct BulkAddMergerTests {
    let fixture = BulkAddHomeFixture()

    @Test("Repeats of the same item in the same place collapse, keeping the first emoji")
    func collapsesRepeats() {
        let merged = BulkAddMerger().merge([
            BulkAddCandidate(name: "Headlamps (2)", emoji: nil, destination: .existing(fixture.redBin.id)),
            BulkAddCandidate(name: "headlamps  (2)", emoji: "🔦", destination: .existing(fixture.redBin.id)),
            BulkAddCandidate(name: "Camping Stove", emoji: "🔥", destination: .existing(fixture.redBin.id)),
            BulkAddCandidate(name: "Camping stove", emoji: "🏕️", destination: .existing(fixture.redBin.id))
        ])
        #expect(merged.map(\.name) == ["Headlamps (2)", "Camping Stove"])
        #expect(merged.map(\.emoji) == ["🔦", "🔥"])
    }

    @Test("The same name in different places is two items")
    func differentPlacesStay() {
        let merged = BulkAddMerger().merge([
            BulkAddCandidate(name: "Flashlight", emoji: nil, destination: .existing(fixture.redBin.id)),
            BulkAddCandidate(name: "Flashlight", emoji: nil, destination: .new(["Kitchen", "Junk Drawer"]))
        ])
        #expect(merged.count == 2)
    }

    @Test("An unplaced mention merges into the placed one, in either order")
    func placedWinsOverUnplaced() {
        let placedLater = BulkAddMerger().merge([
            BulkAddCandidate(name: "Jumper Cables", emoji: "🔌", destination: nil),
            BulkAddCandidate(name: "jumper cables", emoji: nil, destination: .existing(fixture.shelf2.id))
        ])
        #expect(placedLater == [BulkAddCandidate(name: "jumper cables", emoji: "🔌", destination: .existing(fixture.shelf2.id))])

        let placedFirst = BulkAddMerger().merge([
            BulkAddCandidate(name: "Jumper Cables", emoji: nil, destination: .existing(fixture.shelf2.id)),
            BulkAddCandidate(name: "Jumper cables", emoji: "🔌", destination: nil)
        ])
        #expect(placedFirst == [BulkAddCandidate(name: "Jumper Cables", emoji: "🔌", destination: .existing(fixture.shelf2.id))])
    }

    @Test("Blank names are dropped and whitespace is cleaned")
    func cleansNames() {
        let merged = BulkAddMerger().merge([
            BulkAddCandidate(name: "   ", emoji: nil, destination: nil),
            BulkAddCandidate(name: "  Tent   Stakes ", emoji: nil, destination: nil)
        ])
        #expect(merged.map(\.name) == ["Tent Stakes"])
    }

    @Test("Model rows resolve short IDs, new paths, and fall back to the carried room")
    func modelRowConversion() {
        let tree = fixture.tree
        let redBinID = tree.entries.first { $0.id == fixture.redBin.id }!.shortID
        let byID = FoundationModelInventoryParser.candidate(
            name: "Headlamps (2)", emoji: "🔦", locationID: redBinID, newLocationPath: "",
            tree: tree, carriedLocation: ""
        )
        #expect(byID == BulkAddCandidate(name: "Headlamps (2)", emoji: "🔦", destination: .existing(fixture.redBin.id)))

        let byPath = FoundationModelInventoryParser.candidate(
            name: "Tent Stakes", emoji: "not an emoji", locationID: "L99", newLocationPath: "Garage > Shelf 2 > Blue bin",
            tree: tree, carriedLocation: ""
        )
        #expect(byPath == BulkAddCandidate(name: "Tent Stakes", emoji: nil, destination: .new(["Garage", "Shelf 2", "Blue bin"])))

        let carried = FoundationModelInventoryParser.candidate(
            name: "Jumper Cables", emoji: "", locationID: "", newLocationPath: "",
            tree: tree, carriedLocation: "Garage > Shelf 2"
        )
        #expect(carried.destination == .existing(fixture.shelf2.id))

        let nowhere = FoundationModelInventoryParser.candidate(
            name: "Kite", emoji: "🪁", locationID: "", newLocationPath: "",
            tree: tree, carriedLocation: ""
        )
        #expect(nowhere.destination == nil)
    }

    @Test("The prompt lists known locations, the carried room, and marks context as processed")
    func promptContents() {
        let tree = fixture.tree
        let prompt = FoundationModelInventoryParser.prompt(
            context: "earlier words", text: SampleRambles.garage, part: 2, of: 3,
            carriedLocation: "Garage > Shelf 2", homeName: "Juniper House", tree: tree
        )
        #expect(prompt.contains("Known locations in Juniper House:"))
        #expect(prompt.contains(": Garage > Shelf 2 > Red bin"))
        #expect(prompt.contains("the speaker is in: Garage > Shelf 2"))
        #expect(prompt.contains("Do not list items from it:\n\"\"\"\nearlier words"))
        #expect(prompt.contains("Passage 2 of 3:"))
        #expect(FoundationModelInventoryParser.resolvedPathText(tree.entries[0].shortID, tree: tree) == tree.entries[0].displayPath)
    }
}

// MARK: JSON and plain-list input

@Suite("Bulk add: JSON and plain-list input")
struct BulkAddInputTests {
    let fixture = BulkAddHomeFixture()

    @Test("A JSON array skips the model and matches locations")
    func jsonArray() throws {
        let json = """
        [
          {"name": "Headlamps (2)", "emoji": "🔦", "location": "Garage > Shelf 2 > Red bin"},
          {"name": "Label Maker", "location": ["Office", "Desk Drawer"]},
          {"title": "Passport", "locationPath": ["Office", "Desk Drawer"], "emoji": "nope"},
          {"name": "Kite"}
        ]
        """
        #expect(BulkAddInputInterpreter.route(for: json, availability: .available) == .json)
        #expect(BulkAddInputInterpreter.route(for: json, availability: .deviceNotEligible) == .json)

        let candidates = try BulkAddJSONInput.parse(json, tree: fixture.tree)
        #expect(candidates == [
            BulkAddCandidate(name: "Headlamps (2)", emoji: "🔦", destination: .existing(fixture.redBin.id)),
            BulkAddCandidate(name: "Label Maker", emoji: nil, destination: .new(["Office", "Desk Drawer"])),
            BulkAddCandidate(name: "Passport", emoji: nil, destination: .new(["Office", "Desk Drawer"])),
            BulkAddCandidate(name: "Kite", emoji: nil, destination: nil)
        ])
    }

    @Test("An {items: [...]} wrapper is accepted")
    func jsonWrapper() throws {
        let candidates = try BulkAddJSONInput.parse(
            #"{"items": [{"name": "Stud Finder", "location": "garage"}]}"#,
            tree: fixture.tree
        )
        #expect(candidates == [BulkAddCandidate(name: "Stud Finder", emoji: nil, destination: .existing(fixture.garage.id))])
    }

    @Test("Malformed JSON and nameless items are errors, not model input")
    func jsonErrors() {
        #expect(throws: BulkAddJSONInput.ParseError.notJSON) {
            try BulkAddJSONInput.parse("[{\"name\": \"Kite\",}", tree: fixture.tree)
        }
        #expect(throws: BulkAddJSONInput.ParseError.invalidItem(index: 1)) {
            try BulkAddJSONInput.parse(#"[{"name": "Kite"}, {"name": "  "}]"#, tree: fixture.tree)
        }
    }

    @Test("Without Apple Intelligence, a ramble is read one item per line")
    func plainListFallback() {
        #expect(BulkAddInputInterpreter.route(for: SampleRambles.kitchen, availability: .available) == .model)
        #expect(BulkAddInputInterpreter.route(for: SampleRambles.kitchen, availability: .appleIntelligenceNotEnabled) == .plainList)
        let candidates = BulkAddPlainListInput.parse("- Headlamps (2)\n\n• Camping Stove\n3. Tent Stakes\n4) Jumper Cables\n  Kite  ")
        #expect(candidates.map(\.name) == ["Headlamps (2)", "Camping Stove", "Tent Stakes", "Jumper Cables", "Kite"])
        #expect(candidates.allSatisfy { $0.destination == nil })
    }

    @Test("Unavailable states explain how to keep going by hand")
    func availabilityMessages() {
        for state in [BulkAddAIAvailability.deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady, .unsupported] {
            #expect(!state.isAvailable)
            #expect(state.message.contains("one item on each line"))
        }
    }
}

// MARK: Review

@Suite("Bulk add: review and duplicates")
struct BulkAddReviewStateTests {
    let fixture = BulkAddHomeFixture()

    private func review(_ candidates: [BulkAddCandidate], items: [AppInventoryItem] = []) -> BulkAddReviewState {
        BulkAddReviewState(candidates: candidates, homeID: fixture.homeID, locations: fixture.locations, items: items)
    }

    @Test("An item with the same name in the same location is flagged and unchecked")
    func duplicateDetection() {
        let existing = item("Headlamps (2)", home: fixture.homeID, location: fixture.redBin)
        let state = review([
            BulkAddCandidate(name: "headlamps (2)", emoji: "🔦", destination: .existing(fixture.redBin.id)),
            BulkAddCandidate(name: "Headlamps (2)", emoji: "🔦", destination: .existing(fixture.shelf2.id)),
            BulkAddCandidate(name: "Camping Stove", emoji: nil, destination: .existing(fixture.redBin.id))
        ], items: [existing])

        #expect(state.rows.map(\.isChecked) == [false, true, true])
        #expect(state.rows.map { state.isAlreadyInCubby($0) } == [true, false, false])
        #expect(state.checkedCount == 2)
    }

    @Test("Items in another home are not duplicates")
    func otherHomeIsNotDuplicate() {
        let otherHome = UUID()
        let otherBin = location("Red bin", home: otherHome, path: "Red bin")
        let state = review(
            [BulkAddCandidate(name: "Headlamps", emoji: nil, destination: .existing(fixture.redBin.id))],
            items: [item("Headlamps", home: otherHome, location: otherBin)]
        )
        #expect(state.rows.first?.isChecked == true)
    }

    @Test("Unplaced rows go to Unsorted; sections list existing places before new ones")
    func sectionsAndDefaults() {
        let state = review([
            BulkAddCandidate(name: "Kite", emoji: nil, destination: nil),
            BulkAddCandidate(name: "Label Maker", emoji: nil, destination: .new(["Office", "Desk Drawer"])),
            BulkAddCandidate(name: "Headlamps", emoji: nil, destination: .existing(fixture.redBin.id))
        ])
        #expect(state.rows.first?.destination == .existing(fixture.unsorted.id))
        #expect(state.sections.map(\.title) == ["Garage > Shelf 2 > Red bin", "Unsorted", "Office > Desk Drawer"])
        #expect(state.sections.map(\.isNew) == [false, false, true])
        #expect(state.proposedNewPaths == [["Office", "Desk Drawer"]])
    }

    @Test("Moving onto an existing copy unchecks the row; re-pointing a New section moves all its rows")
    func editingDestinations() {
        let existing = item("Tent Stakes", home: fixture.homeID, location: fixture.redBin)
        var state = review([
            BulkAddCandidate(name: "Tent Stakes", emoji: nil, destination: .new(["Garage", "Blue bin"])),
            BulkAddCandidate(name: "Bungee Cords", emoji: nil, destination: .new(["Garage", "Blue bin"]))
        ], items: [existing])
        #expect(state.rows.allSatisfy { $0.isChecked })

        state.moveSection(.new(["Garage", "Blue bin"]), to: .existing(fixture.redBin.id))
        #expect(state.rows.allSatisfy { $0.destination == .existing(fixture.redBin.id) })
        #expect(state.rows.map(\.isChecked) == [false, true])
        #expect(state.proposedNewPaths.isEmpty)

        // A typed path that already exists becomes the existing location.
        let id = state.rows[1].id
        state.setDestination(.new(["garage", "SHELF 2"]), for: id)
        #expect(state.row(id: id)?.destination == .existing(fixture.shelf2.id))
    }

    @Test("Rows can be renamed, re-emojied, unchecked, deleted, and added")
    func rowEditing() {
        var state = review([BulkAddCandidate(name: "Stove", emoji: nil, destination: .existing(fixture.redBin.id))])
        let id = state.rows[0].id
        state.setName("Camping Stove", for: id)
        state.setEmoji("🔥", for: id)
        #expect(state.row(id: id)?.name == "Camping Stove")
        #expect(state.row(id: id)?.emoji == "🔥")
        state.setChecked(false, for: id)
        #expect(state.checkedCount == 0)

        let added = state.addRow(name: "Lantern")
        #expect(state.row(id: added)?.destination == .existing(fixture.unsorted.id))
        #expect(state.checkedCount == 1)
        // Blank hand-added rows are not counted or saved.
        state.addRow()
        #expect(state.checkedCount == 1)
        state.deleteRow(id: id)
        #expect(state.rows.count == 2)
    }

    @Test("Switching homes keeps places by path and re-checks duplicates there")
    func switchHome() {
        let otherHomeID = UUID()
        let otherGarage = location("Garage", home: otherHomeID, path: "Garage")
        let otherUnsorted = location("Unsorted", home: otherHomeID, path: "Unsorted")
        let otherItems = [item("Stud Finder", home: otherHomeID, location: otherGarage)]
        var state = review([
            BulkAddCandidate(name: "Stud Finder", emoji: nil, destination: .existing(fixture.garage.id)),
            BulkAddCandidate(name: "Headlamps", emoji: nil, destination: .existing(fixture.redBin.id)),
            BulkAddCandidate(name: "Kite", emoji: nil, destination: nil)
        ])

        state.switchHome(
            to: otherHomeID,
            locations: fixture.locations + [otherGarage, otherUnsorted],
            items: otherItems
        )
        #expect(state.homeID == otherHomeID)
        #expect(state.rows[0].destination == .existing(otherGarage.id))
        #expect(state.rows[0].isChecked == false)
        #expect(state.rows[1].destination == .new(["Garage", "Shelf 2", "Red bin"]))
        #expect(state.rows[2].destination == .existing(otherUnsorted.id))
    }

    @Test("The import document saves checked rows once and leaves existing copies untouched")
    func importDocument() {
        let existing = item("Headlamps", home: fixture.homeID, location: fixture.redBin)
        var state = review([
            BulkAddCandidate(name: "Headlamps", emoji: "🔦", destination: .existing(fixture.redBin.id)),
            BulkAddCandidate(name: "Stove", emoji: "🔥", destination: .existing(fixture.redBin.id)),
            BulkAddCandidate(name: "Label Maker", emoji: nil, destination: .new(["Office", "Desk Drawer"])),
            BulkAddCandidate(name: "Kite", emoji: nil, destination: nil)
        ], items: [existing])
        state.setChecked(false, for: state.rows[3].id)
        // A second row renamed to collide with the first is saved once.
        let extra = state.addRow(name: "stove ", destination: .existing(fixture.redBin.id))
        #expect(state.row(id: extra) != nil)
        // A re-checked duplicate is passed without an emoji.
        state.setChecked(true, for: state.rows[0].id)

        let document = state.makeImportDocument()
        #expect(document.items == [
            InventoryImportItem(title: "Headlamps", locationPath: ["Garage", "Shelf 2", "Red bin"], emoji: nil),
            InventoryImportItem(title: "Stove", locationPath: ["Garage", "Shelf 2", "Red bin"], emoji: "🔥"),
            InventoryImportItem(title: "Label Maker", locationPath: ["Office", "Desk Drawer"], emoji: nil)
        ])
    }
}

// MARK: Saving through AppStore

@Suite("Bulk add: saving")
@MainActor
struct BulkAddSaveTests {
    private func makeStore() throws -> (AppStore, AppHome) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BulkAddTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repository = CoreDataAppRepository(persistenceController: try PersistenceController(storeDirectory: directory), shareService: nil)
        let home = try repository.createHome(name: "Juniper House")
        let store = AppStore(repository: repository, notificationCenter: NotificationCenter())
        return (store, home)
    }

    @Test("Save creates new locations only for checked rows and adds items through the import batch")
    func savesCheckedRows() async throws {
        let (store, home) = try makeStore()
        let garage = try store.createLocation(name: "Garage", homeID: home.id, parentLocationID: nil)
        _ = try await store.createItem(
            title: "Stud Finder", itemDescription: nil, storageLocationID: garage.id,
            tags: [], selectedImage: nil, emoji: "📏"
        )

        let candidates = try BulkAddJSONInput.parse(
            """
            [
              {"name": "Stud Finder", "emoji": "🧲", "location": "Garage"},
              {"name": "Socket Set", "emoji": "🔧", "location": "Garage > Tool Wall"},
              {"name": "Cordless Drill", "location": "Garage > Tool Wall"},
              {"name": "Kite", "location": "Attic"}
            ]
            """,
            tree: BulkAddLocationTree(homeID: home.id, locations: store.locations)
        )
        var state = BulkAddReviewState(candidates: candidates, homeID: home.id, locations: store.locations, items: store.items)
        #expect(state.rows.map(\.isChecked) == [false, true, true, true])
        state.setChecked(false, for: state.rows[3].id)

        let plan = state.makePlan(homes: store.homes, locations: store.locations, items: store.items)
        #expect(plan.blockingErrors.isEmpty)
        let result = try store.commitInventoryImportPlan(plan)

        #expect(result.createdLocationIDs.count == 1)
        #expect(result.createdItemIDs.count == 2)
        let homeItems = store.items(in: home.id)
        #expect(Set(homeItems.map(\.title)) == ["Stud Finder", "Socket Set", "Cordless Drill"])
        #expect(homeItems.first { $0.title == "Stud Finder" }?.emoji == "📏")
        #expect(homeItems.first { $0.title == "Socket Set" }?.storageLocationPath == "Garage > Tool Wall")
        #expect(homeItems.first { $0.title == "Socket Set" }?.emoji == "🔧")
        #expect(!store.locations.contains { $0.fullPath == "Attic" })
    }

    @Test("A read-only shared home is not saved to")
    func readOnlyHomeBlocksPlan() {
        let homeID = UUID()
        let home = AppHome(
            id: homeID, name: "Shared", createdAt: .distantPast, modifiedAt: .distantPast,
            isShared: true, isOwnedByCurrentUser: false,
            permission: SharePermission(role: .readOnlyParticipant), participantSummary: nil
        )
        let state = BulkAddReviewState(
            candidates: [BulkAddCandidate(name: "Kite", emoji: nil, destination: .new(["Attic"]))],
            homeID: homeID, locations: [], items: []
        )
        let plan = state.makePlan(homes: [home], locations: [], items: [])
        #expect(plan.blockingErrors.map(\.kind) == [.selectedHomeReadOnly])
    }
}

// MARK: Shortcuts entry

@Suite("Bulk add: Add Items to Cubby action", .timeLimit(.minutes(1)))
@MainActor
struct BulkAddIntentNavigationTests {
    @Test("The action queues the review only with access, and never saves")
    func queuesReview() async throws {
        var entitlement = ProEntitlementState.pro
        let service = SiriInventoryService(
            recordLoader: { [] },
            accessProvider: { entitlement },
            indexWriter: RecordingBulkAddSiriIndex()
        )
        try await service.addItems(text: SampleRambles.garage)
        #expect(service.navigationRequest?.destination == .addItems(SampleRambles.garage))

        service.acknowledgeNavigation(id: try #require(service.navigationRequest).id)
        entitlement = .notPro
        await #expect(throws: SiriInventoryError.subscriptionRequired) {
            try await service.addItems(text: "Kite")
        }
        #expect(service.navigationRequest == nil)
        await service.waitForIndexRefresh()
    }
}

private final class RecordingBulkAddSiriIndex: SiriInventoryIndexWriting {
    func removeAll() async throws {}
    func index(_ records: [SiriInventoryRecord]) async throws {}
}
