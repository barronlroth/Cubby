import SwiftUI

/// Rows Cubby found, grouped by location. Each row can be renamed, re-emojied, moved,
/// unchecked, or deleted. Save writes every checked row in one import batch, so CloudKit
/// sync and shared-home permissions behave like any other item creation.
struct BulkAddReviewView: View {
    @Binding var review: BulkAddReviewState
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.activePaywall) private var activePaywall
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var proAccessManager: ProAccessManager

    @State private var locationTarget: LocationTarget?
    @State private var saveErrorMessage: String?
    @State private var isSaving = false
    @State private var savedCount = 0
    @FocusState private var focusedRowID: UUID?

    private enum LocationTarget: Identifiable {
        case row(UUID)
        case section(BulkAddDestination)

        var id: String {
            switch self {
            case .row(let id): "row-\(id.uuidString)"
            case .section(let destination): "section-\(destination.hashValue)"
            }
        }
    }

    private var home: AppHome? {
        appStore.home(id: review.homeID)
    }

    private var editableHomes: [AppHome] {
        appStore.homes.filter(\.permission.canMutate)
    }

    var body: some View {
        List {
            homeSection

            if review.rows.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "shippingbox",
                    description: Text("Add items by hand, or go back and try different wording.")
                )
                .listRowBackground(Color.clear)
            }

            ForEach(review.sections) { section in
                Section {
                    ForEach(section.rowIDs, id: \.self) { rowID in
                        if let row = review.row(id: rowID) {
                            rowView(row)
                        }
                    }
                } header: {
                    sectionHeader(section)
                }
            }

            Section {
                Button {
                    let id = review.addRow()
                    focusedRowID = id
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .accessibilityIdentifier("bulk-add-add-row-button")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Review Items")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(saveTitle) { save() }
                    .disabled(review.checkedCount == 0 || isSaving || home == nil)
                    .accessibilityIdentifier("bulk-add-save-button")
            }
        }
        .sheet(item: $locationTarget) { target in
            BulkAddLocationChooser(
                tree: review.tree,
                proposedPaths: review.proposedNewPaths,
                current: currentDestination(for: target)
            ) { destination in
                switch target {
                case .row(let id):
                    review.setDestination(destination, for: id)
                case .section(let old):
                    review.moveSection(old, to: destination)
                }
            }
        }
        .alert(
            "Couldn't Save",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .sensoryFeedback(.success, trigger: savedCount)
    }

    private var saveTitle: String {
        review.checkedCount > 0 ? "Save \(review.checkedCount)" : "Save"
    }

    // MARK: Sections

    private var homeSection: some View {
        Section {
            if editableHomes.count > 1 {
                Picker(selection: homeSelection) {
                    ForEach(editableHomes) { home in
                        Text(home.name).tag(home.id)
                    }
                } label: {
                    Label("Home", systemImage: "house")
                }
                .accessibilityIdentifier("bulk-add-home-picker")
            } else {
                LabeledContent {
                    Text(home?.name ?? "No Home")
                } label: {
                    Label("Home", systemImage: "house")
                }
            }
        } footer: {
            Text("Items marked New go in locations Cubby creates when you save.")
                .font(CubbyDesign.Typography.caption)
        }
    }

    private var homeSelection: Binding<UUID> {
        Binding(
            get: { review.homeID },
            set: { newHomeID in
                review.switchHome(to: newHomeID, locations: appStore.locations, items: appStore.items)
            }
        )
    }

    private func sectionHeader(_ section: BulkAddReviewSection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CubbyDesign.Spacing.small) {
            Text(section.title)
                .font(CubbyDesign.Typography.path)
                .textCase(nil)
                .foregroundStyle(CubbyDesign.Palette.primaryText)

            if section.isNew {
                NewLocationBadge()
            }

            Spacer(minLength: CubbyDesign.Spacing.small)

            Button("Change") {
                locationTarget = .section(section.destination)
            }
            .font(CubbyDesign.Typography.captionEmphasized)
            .textCase(nil)
            .accessibilityLabel("Change location for \(section.title)")
        }
    }

    // MARK: Rows

    private func rowView(_ row: BulkAddReviewRow) -> some View {
        let isDuplicate = review.isAlreadyInCubby(row)
        return HStack(spacing: CubbyDesign.Spacing.medium) {
            Button {
                review.setChecked(!row.isChecked, for: row.id)
                CubbyDesign.Haptics.play(.selection)
            } label: {
                Image(systemName: row.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(row.isChecked ? CubbyDesign.Palette.accent : CubbyDesign.Palette.secondaryText)
                    .frame(minWidth: CubbyDesign.Layout.minimumTapTarget, minHeight: CubbyDesign.Layout.minimumTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(row.isChecked ? "Will be added" : "Won't be added")
            .accessibilityValue(row.name)
            .accessibilityHint("Double-tap to toggle")

            ItemEmojiPickerButton(
                selectedEmoji: Binding(
                    get: { review.row(id: row.id)?.emoji },
                    set: { review.setEmoji($0, for: row.id) }
                ),
                fallbackEmoji: EmojiPicker.emoji(for: row.id),
                isPendingAiEmoji: false,
                onBeginEditing: { focusedRowID = nil }
            )

            VStack(alignment: .leading, spacing: CubbyDesign.Spacing.xSmall) {
                TextField(
                    "Item name",
                    text: Binding(
                        get: { review.row(id: row.id)?.name ?? "" },
                        set: { review.setName($0, for: row.id) }
                    )
                )
                .font(CubbyDesign.Typography.body)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($focusedRowID, equals: row.id)
                .opacity(row.isChecked ? 1 : 0.55)

                if isDuplicate {
                    Label("Already in Cubby", systemImage: "exclamationmark.circle")
                        .font(CubbyDesign.Typography.caption)
                        .foregroundStyle(.orange)
                        .accessibilityHint("Rename or move this item to add another one.")
                        .accessibilityIdentifier("bulk-add-duplicate-flag")
                }
            }

            Menu {
                Button {
                    locationTarget = .row(row.id)
                } label: {
                    Label("Change Location", systemImage: "folder")
                }
                Button(role: .destructive) {
                    review.deleteRow(id: row.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(CubbyDesign.Palette.secondaryText)
                    .frame(minWidth: CubbyDesign.Layout.minimumTapTarget, minHeight: CubbyDesign.Layout.minimumTapTarget)
                    .contentShape(.rect)
            }
            .accessibilityLabel("More for \(row.name)")
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                review.deleteRow(id: row.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                locationTarget = .row(row.id)
            } label: {
                Label("Move", systemImage: "folder")
            }
        }
    }

    private func currentDestination(for target: LocationTarget) -> BulkAddDestination? {
        switch target {
        case .row(let id): review.row(id: id)?.destination
        case .section(let destination): destination
        }
    }

    // MARK: Save

    private func save() {
        guard !isSaving, let home else { return }
        focusedRowID = nil
        let gate = appStore.canCreateItem(homeID: home.id, isPro: proAccessManager.isPro)
        guard gate.isAllowed else {
            activePaywall.wrappedValue = PaywallContext(reason: gate.reason == .overLimit ? .overLimit : .itemLimitReached)
            return
        }

        isSaving = true
        defer { isSaving = false }
        let plan = review.makePlan(homes: appStore.homes, locations: appStore.locations, items: appStore.items)
        if let firstError = plan.blockingErrors.first {
            saveErrorMessage = firstError.message
            return
        }
        do {
            _ = try appStore.commitInventoryImportPlan(plan)
            savedCount += 1
            onSaved()
        } catch {
            saveErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Cubby couldn't save these items. Try again."
        }
    }
}

struct NewLocationBadge: View {
    var body: some View {
        Text("New")
            .font(CubbyDesign.Typography.finePrintEmphasized)
            .textCase(nil)
            .foregroundStyle(CubbyDesign.Palette.accent)
            .padding(.horizontal, CubbyDesign.Spacing.small)
            .padding(.vertical, 2)
            .background(CubbyDesign.Palette.accent.opacity(0.12), in: Capsule())
            .accessibilityLabel("New location")
    }
}

/// Picks where a row (or a whole section) goes: an existing location, a location another
/// row proposed, or a typed new path. Nothing is created until the review is saved.
struct BulkAddLocationChooser: View {
    let tree: BulkAddLocationTree
    let proposedPaths: [[String]]
    let current: BulkAddDestination?
    let onChoose: (BulkAddDestination) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var newPath = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Garage > Shelf 2 > Red Bin", text: $newPath)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit(chooseTypedPath)
                        Button("Use", action: chooseTypedPath)
                            .disabled(BulkAddText.pathComponents(newPath).isEmpty)
                    }
                } header: {
                    Text("New Location")
                } footer: {
                    Text("Separate levels with >. Cubby creates it when you save.")
                }

                if !filteredProposed.isEmpty {
                    Section("New in This List") {
                        ForEach(filteredProposed, id: \.self) { path in
                            choiceRow(title: path.joined(separator: " > "), destination: .new(path), isNew: true)
                        }
                    }
                }

                Section("Existing Locations") {
                    if filteredEntries.isEmpty {
                        Text(tree.isEmpty ? "This home has no locations yet." : "No matching locations.")
                            .foregroundStyle(CubbyDesign.Palette.secondaryText)
                    }
                    ForEach(filteredEntries) { entry in
                        choiceRow(title: entry.displayPath, destination: .existing(entry.id), isNew: false)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search locations")
            .scrollContentBackground(.hidden)
            .background(CubbyDesign.Palette.canvas)
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var filteredEntries: [BulkAddLocationTree.Entry] {
        let query = BulkAddText.clean(searchText)
        guard !query.isEmpty else { return tree.entries }
        return tree.entries.filter { $0.displayPath.localizedStandardContains(query) }
    }

    private var filteredProposed: [[String]] {
        let query = BulkAddText.clean(searchText)
        guard !query.isEmpty else { return proposedPaths }
        return proposedPaths.filter { $0.joined(separator: " > ").localizedStandardContains(query) }
    }

    private func choiceRow(title: String, destination: BulkAddDestination, isNew: Bool) -> some View {
        Button {
            onChoose(destination)
            dismiss()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(CubbyDesign.Palette.primaryText)
                if isNew { NewLocationBadge() }
                Spacer()
                if destination == current {
                    Image(systemName: "checkmark")
                        .foregroundStyle(CubbyDesign.Palette.accent)
                        .accessibilityLabel("Current")
                }
            }
            .contentShape(.rect)
        }
    }

    private func chooseTypedPath() {
        let path = BulkAddText.pathComponents(newPath)
        guard !path.isEmpty else { return }
        onChoose(tree.destination(forPath: path) ?? .new(path))
        dismiss()
    }
}
