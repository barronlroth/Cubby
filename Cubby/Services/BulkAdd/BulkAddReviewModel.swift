import Foundation

struct BulkAddReviewRow: Identifiable, Equatable {
    let id: UUID
    var name: String
    var emoji: String?
    var destination: BulkAddDestination
    var isChecked: Bool

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String?,
        destination: BulkAddDestination,
        isChecked: Bool = true
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.destination = destination
        self.isChecked = isChecked
    }
}

struct BulkAddReviewSection: Identifiable, Equatable {
    let destination: BulkAddDestination
    let title: String
    let isNew: Bool
    let rowIDs: [UUID]

    var id: BulkAddDestination { destination }
}

/// Editable review state for one target home. Nothing is written until `makePlan` runs,
/// so proposed locations exist only as paths until the user saves.
struct BulkAddReviewState: Equatable {
    private(set) var homeID: UUID
    private(set) var tree: BulkAddLocationTree
    private(set) var rows: [BulkAddReviewRow] = []
    private var existingItemKeys: Set<String> = []

    init(
        candidates: [BulkAddCandidate],
        homeID: UUID,
        locations: [AppStorageLocation],
        items: [AppInventoryItem]
    ) {
        self.homeID = homeID
        self.tree = BulkAddLocationTree(homeID: homeID, locations: locations)
        self.existingItemKeys = Self.itemKeys(homeID: homeID, items: items)
        self.rows = BulkAddMerger().merge(candidates).map { candidate in
            BulkAddReviewRow(
                name: candidate.name,
                emoji: candidate.emoji,
                destination: candidate.destination ?? defaultDestination
            )
        }
        uncheckDuplicates()
    }

    // MARK: Reading

    var defaultDestination: BulkAddDestination {
        tree.unsorted.map { .existing($0.id) } ?? .new(["Unsorted"])
    }

    var checkedCount: Int {
        rows.filter { $0.isChecked && !BulkAddText.clean($0.name).isEmpty }.count
    }

    func row(id: UUID) -> BulkAddReviewRow? {
        rows.first { $0.id == id }
    }

    func isAlreadyInCubby(_ row: BulkAddReviewRow) -> Bool {
        guard case .existing(let locationID) = row.destination else { return false }
        return existingItemKeys.contains(Self.itemKey(title: row.name, locationID: locationID))
    }

    func title(for destination: BulkAddDestination) -> String {
        tree.displayPath(for: destination)
    }

    /// Rows grouped by location, existing places first and then new ones, each by path.
    var sections: [BulkAddReviewSection] {
        var order: [BulkAddDestination] = []
        var rowIDs: [BulkAddDestination: [UUID]] = [:]
        for row in rows {
            if rowIDs[row.destination] == nil { order.append(row.destination) }
            rowIDs[row.destination, default: []].append(row.id)
        }
        return order
            .map { destination in
                let isNew: Bool
                if case .new = destination { isNew = true } else { isNew = false }
                return BulkAddReviewSection(
                    destination: destination,
                    title: tree.displayPath(for: destination),
                    isNew: isNew,
                    rowIDs: rowIDs[destination] ?? []
                )
            }
            .sorted { lhs, rhs in
                if lhs.isNew != rhs.isNew { return !lhs.isNew }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    /// Proposed new paths, offered in the location chooser so several rows can share one.
    var proposedNewPaths: [[String]] {
        var seen = Set<String>()
        return rows.compactMap { row -> [String]? in
            guard case .new(let path) = row.destination,
                  seen.insert(BulkAddText.pathKey(path)).inserted else { return nil }
            return path
        }
    }

    // MARK: Editing

    mutating func setName(_ name: String, for id: UUID) {
        update(id) { $0.name = name }
    }

    mutating func setEmoji(_ emoji: String?, for id: UUID) {
        update(id) { $0.emoji = emoji }
    }

    mutating func setChecked(_ isChecked: Bool, for id: UUID) {
        update(id) { $0.isChecked = isChecked }
    }

    /// Moving a row re-runs the duplicate check: an item moved onto an existing copy is unchecked.
    mutating func setDestination(_ destination: BulkAddDestination, for id: UUID) {
        let canonical = Self.canonical(destination, in: tree)
        update(id) { $0.destination = canonical }
        if let row = row(id: id), isAlreadyInCubby(row) {
            setChecked(false, for: id)
        }
    }

    /// Points every row in a section (typically a proposed "New" location) somewhere else.
    mutating func moveSection(_ destination: BulkAddDestination, to newDestination: BulkAddDestination) {
        for row in rows where row.destination == destination {
            setDestination(newDestination, for: row.id)
        }
    }

    mutating func deleteRow(id: UUID) {
        rows.removeAll { $0.id == id }
    }

    @discardableResult
    mutating func addRow(name: String = "", destination: BulkAddDestination? = nil) -> UUID {
        let row = BulkAddReviewRow(
            name: name,
            emoji: nil,
            destination: Self.canonical(destination ?? defaultDestination, in: tree)
        )
        rows.append(row)
        return row.id
    }

    /// Re-targets every row at another home, keeping each row's place by path.
    /// Paths that don't exist there become proposed new locations.
    mutating func switchHome(
        to newHomeID: UUID,
        locations: [AppStorageLocation],
        items: [AppInventoryItem]
    ) {
        guard newHomeID != homeID else { return }
        let oldTree = tree
        homeID = newHomeID
        tree = BulkAddLocationTree(homeID: newHomeID, locations: locations)
        existingItemKeys = Self.itemKeys(homeID: newHomeID, items: items)
        for index in rows.indices {
            let path = oldTree.pathComponents(for: rows[index].destination) ?? []
            rows[index].destination = tree.destination(forPath: path) ?? defaultDestination
            if isAlreadyInCubby(rows[index]) {
                rows[index].isChecked = false
            }
        }
    }

    // MARK: Saving

    /// Builds the reviewed rows as Cubby's import document. Two checked rows with the same name
    /// and place are saved once. A checked "Already in Cubby" row carries no emoji, so it leaves
    /// the existing item unchanged rather than overwriting it or creating a second copy.
    func makeImportDocument() -> InventoryImportDocument {
        var seen = Set<String>()
        var items: [InventoryImportItem] = []
        for row in rows where row.isChecked {
            let name = BulkAddText.clean(row.name)
            guard !name.isEmpty,
                  let path = tree.pathComponents(for: row.destination),
                  !path.isEmpty,
                  seen.insert(BulkAddMerger.key(name: name, destination: row.destination)).inserted else { continue }
            let emoji = isAlreadyInCubby(row) ? nil : row.emoji
            items.append(InventoryImportItem(title: name, locationPath: path, emoji: emoji))
        }
        return InventoryImportDocument(items: items)
    }

    func makePlan(
        homes: [AppHome],
        locations: [AppStorageLocation],
        items: [AppInventoryItem]
    ) -> InventoryImportPlan {
        InventoryImportDryRunPlanner().plan(
            document: makeImportDocument(),
            selectedHomeID: homeID,
            homes: homes,
            locations: locations,
            items: items
        )
    }

    // MARK: Helpers

    private mutating func update(_ id: UUID, _ change: (inout BulkAddReviewRow) -> Void) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        change(&rows[index])
    }

    private mutating func uncheckDuplicates() {
        for index in rows.indices where isAlreadyInCubby(rows[index]) {
            rows[index].isChecked = false
        }
    }

    /// A typed "new" path that already exists is the existing location.
    private static func canonical(_ destination: BulkAddDestination, in tree: BulkAddLocationTree) -> BulkAddDestination {
        guard case .new(let path) = destination, let entry = tree.match(path: path),
              BulkAddText.pathKey(entry.path) == BulkAddText.pathKey(path) else { return destination }
        return .existing(entry.id)
    }

    private static func itemKeys(homeID: UUID, items: [AppInventoryItem]) -> Set<String> {
        Set(items.compactMap { item in
            guard item.homeID == homeID, let locationID = item.storageLocationID else { return nil }
            return itemKey(title: item.title, locationID: locationID)
        })
    }

    private static func itemKey(title: String, locationID: UUID) -> String {
        "\(BulkAddText.normalized(title))|\(locationID.uuidString)"
    }
}

/// Picks the input path: JSON skips the model; otherwise the model reads the ramble,
/// or, without Apple Intelligence, each line becomes one row.
struct BulkAddInputInterpreter {
    enum Route: Equatable {
        case json
        case model
        case plainList
    }

    static func route(for text: String, availability: BulkAddAIAvailability) -> Route {
        if BulkAddJSONInput.looksLikeJSON(text) { return .json }
        return availability.isAvailable ? .model : .plainList
    }
}
