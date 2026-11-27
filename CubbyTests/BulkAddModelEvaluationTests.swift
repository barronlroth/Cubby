import Foundation
import Testing
@testable import Cubby

/// Runs the real on-device Foundation Model over sample rambles and prints item → location.
/// Opt-in only: set CUBBY_MODEL_EVAL=1 (xcodebuild: TEST_RUNNER_CUBBY_MODEL_EVAL=1) on a device
/// with Apple Intelligence. Simulators and CI skip it. Run it under the Cubby Dev scheme with
/// -configuration DebugDev so the host app is com.barronroth.Cubby.dev, never production.
@Suite(
    "Bulk add: on-device model evaluation",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUBBY_MODEL_EVAL"] == "1"),
    .enabled(if: FoundationModelInventoryParser.currentAvailability().isAvailable)
)
struct BulkAddModelEvaluationTests {
    struct Expectation {
        let item: String
        let location: String
    }

    struct Case {
        let name: String
        let tree: String
        let ramble: String
        let expected: [Expectation]
    }

    static let barronRamble = "In the garage on shelf two, the red bin has two headlamps, the camping stove and the jumper cables. Under the bed there's the guitar case."

    static let cases: [Case] = [
        Case(name: "barron-repro", tree: "repro", ramble: barronRamble, expected: [
            Expectation(item: "Headlamps (2)", location: "Garage > Shelf 2 > Red Bin"),
            Expectation(item: "Camping Stove", location: "Garage > Shelf 2 > Red Bin"),
            Expectation(item: "Jumper Cables", location: "Garage > Shelf 2 > Red Bin"),
            Expectation(item: "Guitar Case", location: "Master Bedroom > Under Bed")
        ]),
        Case(name: "barron-seeded", tree: "seeded", ramble: barronRamble, expected: [
            Expectation(item: "Headlamps (2)", location: "Garage > Shelf 2 > Red bin"),
            Expectation(item: "Camping Stove", location: "Garage > Shelf 2 > Red bin"),
            Expectation(item: "Jumper Cables", location: "Garage > Shelf 2 > Red bin"),
            Expectation(item: "Guitar Case", location: "Bedroom > Under Bed")
        ]),
        Case(name: "kitchen-seeded", tree: "seeded", ramble: SampleWalkAround.kitchen, expected: [
            Expectation(item: "Batteries", location: "Kitchen > Junk Drawer"),
            Expectation(item: "Tape Measure", location: "Kitchen > Junk Drawer"),
            Expectation(item: "Fire Extinguisher", location: "Kitchen > Under Sink"),
            Expectation(item: "Stand Mixer", location: "Kitchen > Pantry")
        ]),
        Case(name: "long-walkaround-seeded", tree: "seeded", ramble: SampleWalkAround.long, expected: SampleWalkAround.longExpected),
        Case(name: "long-walkaround-repro", tree: "repro", ramble: SampleWalkAround.long, expected: [])
    ]

    static func tree(_ name: String) -> BulkAddLocationTree {
        let homeID = UUID()
        var locations: [AppStorageLocation] = []
        func add(_ path: String) {
            let parts = path.components(separatedBy: " > ")
            let parent = locations.first { $0.fullPath == parts.dropLast().joined(separator: " > ") && parts.count > 1 }
            locations.append(AppStorageLocation(
                id: UUID(), name: parts.last!, createdAt: .distantPast, modifiedAt: .distantPast,
                depth: parts.count - 1, homeID: homeID, homeName: "Eval", parentLocationID: parent?.id,
                fullPath: path, childLocationIDs: [], itemCount: 0
            ))
        }
        let paths = name == "repro"
            ? ["Unsorted", "Master Bedroom", "Master Bedroom > Under Bed"]
            : ["Unsorted", "Garage", "Garage > Shelf 2", "Garage > Shelf 2 > Red bin", "Garage > Tool Wall",
               "Garage > Top Shelf", "Bedroom", "Bedroom > Under Bed", "Bedroom > Closet", "Kitchen",
               "Kitchen > Junk Drawer", "Kitchen > Pantry"]
        paths.forEach(add)
        return BulkAddLocationTree(homeID: homeID, locations: locations)
    }

    @Test("Sample rambles", arguments: [true])
    func evaluate(includesVocabulary: Bool) async throws {
        var totalExpected = 0
        var totalCorrect = 0
        for testCase in Self.cases {
            let tree = Self.tree(testCase.tree)
            let parser = FoundationModelInventoryParser(includesVocabulary: includesVocabulary)
            let start = ContinuousClock.now
            let rows = try await parser.parse(transcript: testCase.ramble, homeName: "Home", tree: tree) { _ in }
            print("EVAL|\(includesVocabulary ? "vocab" : "novocab")|\(testCase.name)|rows=\(rows.count)|\(start.duration(to: .now))")
            for row in rows {
                let place = row.destination.map { tree.displayPath(for: $0) } ?? "(none)"
                let isNew: Bool
                if case .new = row.destination { isNew = true } else { isNew = false }
                print("EVAL|  \(row.name) → \(place)\(isNew ? " [New]" : "")")
            }
            for expectation in testCase.expected {
                totalExpected += 1
                let match = rows.first { BulkAddText.normalized($0.name) == BulkAddText.normalized(expectation.item) }
                    ?? rows.first { BulkAddText.wordsContain(BulkAddText.spokenKey($0.name), BulkAddText.spokenKey(expectation.item))
                        || BulkAddText.wordsContain(BulkAddText.spokenKey(expectation.item), BulkAddText.spokenKey($0.name)) }
                let place = match?.destination.map { tree.displayPath(for: $0) }
                let ok = place.map { BulkAddText.normalized($0) == BulkAddText.normalized(expectation.location) } ?? false
                if ok { totalCorrect += 1 }
                print("EVAL|  expect \(expectation.item) @ \(expectation.location): \(ok ? "OK" : "MISS (got \(match?.name ?? "-") @ \(place ?? "-"))")")
            }
        }
        print("EVAL|\(includesVocabulary ? "vocab" : "novocab")|score \(totalCorrect)/\(totalExpected)")
        #expect(totalExpected > 0)
    }
}

enum SampleWalkAround {
    static let kitchen = "Kitchen. The junk drawer has the batteries, AA and AAA, a tape measure, and the spare house keys. Under the sink, the fire extinguisher. In the pantry on the left side there's the stand mixer. Actually no, I gave the bread machine away so skip that one."

    static let longExpected: [BulkAddModelEvaluationTests.Expectation] = [
        .init(item: "Headlamps (2)", location: "Garage > Shelf 2 > Red bin"),
        .init(item: "Camping Stove", location: "Garage > Shelf 2 > Red bin"),
        .init(item: "Cordless Drill", location: "Garage > Tool Wall"),
        .init(item: "Socket Set", location: "Garage > Tool Wall"),
        .init(item: "Christmas Lights (3)", location: "Garage > Top Shelf"),
        .init(item: "Label Maker", location: "Office > Desk Drawer"),
        .init(item: "Passport", location: "Office > Desk Drawer"),
        .init(item: "Sleeping Bags (2)", location: "Bedroom > Closet"),
        .init(item: "Guitar Case", location: "Bedroom > Under Bed"),
        .init(item: "Fire Extinguisher", location: "Kitchen > Under Sink"),
        .init(item: "Stand Mixer", location: "Kitchen > Pantry"),
        .init(item: "Halloween Decorations", location: "Basement > Blue Tote"),
        .init(item: "Extension Cords", location: "Basement > Blue Tote"),
        .init(item: "Beach Towels", location: "Hall Closet > Top Shelf"),
        .init(item: "First Aid Kit", location: "Bathroom > Under Sink"),
        .init(item: "Snow Shovel", location: "Mudroom"),
        .init(item: "Board Games", location: "Living Room > TV Cabinet"),
        .init(item: "Air Mattress", location: "Attic"),
        .init(item: "Tax Documents", location: "Office > Filing Cabinet"),
        .init(item: "Hose Nozzle", location: "Shed")
    ]

    /// About 2,000 words of one continuous walk-around: room changes, filler, asides,
    /// and self-corrections. Each room is visited once, the way a real recording would go.
    static let long = """
    Okay so um I'm going to try to do the whole house in one go, let's see how this goes, I've been meaning to do this for like a year. I'm going to start in the garage because honestly that's where most of the chaos is. Alright. So I'm standing in the garage right now, the door's open, it's freezing, whatever. On shelf two, which is the middle one on the left wall, there's the red bin. In the red bin I've got two headlamps and the camping stove. I thought the tent was in there too but no, the tent is at my brother's place, he borrowed it in the summer and never gave it back, so forget the tent, don't put the tent anywhere. Still on shelf two next to the red bin is a coffee can full of screws, I don't think that's worth tracking, skip that. Um, let me think. Oh, the tool wall. On the tool wall there's the cordless drill hanging on the hook, and the socket set is right under it on the little shelf. There's also a hammer on the tool wall, wait, no, the hammer is in the kitchen junk drawer, I'll get to that later. Up on the top shelf, the really high one where you need the step ladder, there are three boxes of Christmas lights. And I think the tree stand is up there too, yeah, the tree stand, put that on the top shelf as well. Okay. I'm also looking at the floor by the car and there's the pressure washer, that's just on the garage floor, it doesn't have a spot, so just put it in the garage.

    Alright, that's the garage, I'm going inside now. Sorry, my dog is barking at a delivery guy, hold on. Okay I'm back. So I'm in the mudroom, which is the little room between the garage and the kitchen. The snow shovel is leaning in the corner here, and the dog leash and the dog's winter jacket are on the hooks. The dog jacket is ridiculous, it has a hood, but anyway, it exists, track it. There's a basket on the bench with like a million mismatched gloves, I'm not going to list all those, just say gloves basket, actually no, don't bother.

    Okay now the kitchen. This is going to be quick because I mostly know where kitchen stuff is, but there are a few things I always lose. The junk drawer, which is the one to the left of the stove, has the hammer like I said, a bunch of batteries, mostly double A and triple A, a tape measure, and the spare house keys. Oh and the little screwdriver set with the interchangeable bits. Under the sink there's the fire extinguisher, which I should probably check is still good. Also under the sink is the dishwasher salt, whatever, not important. In the pantry, on the left side on the floor, there's the stand mixer, which is heavy so I keep it low. On the top shelf of the pantry there's the bread machine, actually no, I gave the bread machine to my neighbor, so not that. The cake stand is up there instead. Yeah. The cake stand is on the top shelf of the pantry.

    Um, okay, what else. Living room. So in the living room there's the TV cabinet, the one under the TV, and inside it are the board games, like Catan and Ticket to Ride and that stuff, and the spare remote, and the HDMI cables. There's also a basket next to the couch with the throw blankets, but those are always out so I don't think they need to go in. Actually, add the throw blankets, why not, put them in the living room. On the bookshelf there's the photo albums, the old ones from my parents, on the bottom shelf. Those are important, I'd be sad if those got lost.

    Alright, now I'm going upstairs. Okay. The hall closet at the top of the stairs. Top shelf has the beach towels and the extra pillows. On the floor of the hall closet is the vacuum, the big one, not the stick one. And there's a bag of wrapping paper back there behind the vacuum, I always forget that's there and buy more wrapping paper, which is kind of the whole reason I'm doing this.

    Next the bathroom, the upstairs one. Under the sink is the first aid kit and the spare toothbrushes, the ones still in the package. And the hair clippers are in the top drawer of the vanity. Uh, that's it for the bathroom.

    Now the office. This is where all the paperwork lives. The desk drawer has the label maker, my passport, and um the checkbook, which I literally never use but whatever. The printer paper is on the floor next to the desk, I don't know if that counts, I guess just put it in the office. The filing cabinet, the gray one, has the tax documents, the car title, and the house stuff, like the closing papers. I should really put the passport in the filing cabinet too but right now it's in the desk drawer, so leave it in the desk drawer.

    Okay, the bedroom, our bedroom. In the closet there are two sleeping bags rolled up on the floor in the back, and the winter boots are on the shelf above the hanging stuff. Under the bed is the guitar case, the guitar's in it, and also the vacuum bags, the little ones for the stick vacuum. On my nightstand, in the drawer, there's the spare phone charger and the sleep mask. I keep thinking the extra reading glasses are in there too, but no, they're in the car, so skip those.

    Right, almost done. The guest room is basically empty, the only thing in there is the air mattress, wait, no, I moved the air mattress up to the attic last month because we needed the closet space. So the air mattress is in the attic. And while I'm thinking about the attic, the baby clothes bins are up there, two of them, and the old suitcases.

    Then down to the basement, I'm going down the stairs now. There's the blue tote with the Halloween decorations and the extra extension cords. And the dehumidifier is just sitting on the floor down there by the stairs, I'll say basement for that. The paint cans are on the metal shelf, the leftover paint from when we did the living room, and the drop cloths are on the same shelf. The camping chairs are leaning against the wall down there too, four of them.

    Okay, hang on, I skipped the laundry room, it's down here next to the basement stairs. So in the laundry room, on the shelf above the washer, there's the stain remover, the dryer sheets, and the iron. The ironing board is folded up behind the door. There's a plastic drawer thing on the floor, the white one with three drawers, and the top drawer has the sewing kit and the lint roller, the middle drawer has the shoe polish and the brushes, and the bottom drawer is empty, I think, or it's got old rags in it, whatever, skip the rags. Um, the step stool is in the laundry room too, folded against the wall, actually no, I took the step stool to the garage for the top shelf, so the step stool is in the garage now. Yeah, garage.

    And the dining room, there's not much, but the sideboard, the long cabinet, has the good dishes and the silverware box, the wooden one from my grandmother. Also the tablecloths are in the left drawer of the sideboard, and the candles and the candle holders are in the right drawer. The extra leaf for the table is leaning behind the sideboard, that's a weird one but I always forget where it is when we have people over for Thanksgiving, so definitely track that. Thanksgiving is like the one time a year we need it and every year it's the same panic, where's the leaf, where's the leaf.

    Let me think about the kids' room, which is really just my son's room. In his closet on the top shelf there's the bin of Lego, the big gray one, and the box with his baby teeth and stuff, which, you know, it's sentimental, put it in. Under his bed are the outgrown shoes that I keep meaning to donate, and the extra sheets for his bed. On his desk there's the old iPad, the one he uses for school, that just lives on the desk. Oh and the soccer ball and the shin guards are in the corner of his room by the window. They're never actually there when we need them for practice, but in theory that's where they live.

    Then the linen closet, which is the narrow one in the upstairs hallway, not the hall closet, the other one. Top shelf, extra blankets. Middle shelf, the guest towels and the washcloths. Bottom shelf, the toilet paper and paper towels, the bulk stuff from Costco. Okay, and the humidifier is on the floor of the linen closet, we only use it in the winter, which is now, so actually I should take it out, but for now it's there.

    The car, does the car count? I'll do the car anyway. In the glove box there's the registration and the tire pressure gauge, and the spare reading glasses I mentioned. In the trunk there's the jumper cables, wait, no, the jumper cables are in the red bin in the garage, the trunk has the emergency kit, the blanket, and the ice scraper. So: glove box has registration, tire gauge, reading glasses. Trunk has emergency kit, car blanket, ice scraper.

    The back porch has the cooler, the big blue one, and the grill cover and the grill tools are in the deck box out there. Also the citronella candles are in the deck box.

    Oh, and I almost forgot the shed out back. In the shed there's the lawn mower, obviously, the hose nozzle on the hook by the door, and the bag of grass seed. The leaf blower is in the shed too. Um, I think that's about everything. I'm sure I forgot a bunch of stuff but that's a start. Okay, stopping the recording now. Wait, one more, the bike pump is in the garage, on the tool wall. Okay, now I'm done for real.
    """
}
