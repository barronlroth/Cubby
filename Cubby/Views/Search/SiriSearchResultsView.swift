import AppIntents
import SwiftUI

/// Search initiated outside the app always spans all currently accessible homes.
struct SiriSearchResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var proAccessManager: ProAccessManager

    @State private var query: String
    @State private var results: [SiriInventoryRecord] = []
    @State private var isLoading = false
    @State private var searchError: String?
    @State private var refreshID = UUID()
    @State private var path: [UUID] = []
    @State private var openingItemID: UUID?
    @State private var openingError: String?
    private let onNavigationHandled: () -> Void

    init(initialQuery: String, onNavigationHandled: @escaping () -> Void) {
        _query = State(initialValue: initialQuery)
        self.onNavigationHandled = onNavigationHandled
    }

    var body: some View {
        NavigationStack(path: $path) {
            searchContent
                .background(CubbyDesign.Palette.canvas)
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search all homes"
                )
                .navigationTitle("Search Items")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
                .navigationDestination(for: UUID.self) { itemID in
                    ItemDetailView(itemId: itemID, requiresSiriAccessValidation: true)
                }
        }
        .task(id: SearchTaskKey(query: query, refreshID: refreshID)) {
            await loadResults()
        }
        .task(id: openingItemID) {
            if let itemID = openingItemID { await openItem(id: itemID) }
        }
        .onChange(of: appStore.inventoryRevision) { _, _ in invalidateResults() }
        .onChange(of: proAccessManager.entitlementState) { _, state in
            if state != .pro {
                path = []
                openingItemID = nil
            }
            invalidateResults()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { invalidateResults() }
        }
        .alert("Item Unavailable", isPresented: Binding(
            get: { openingError != nil },
            set: { if !$0 { openingError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(openingError ?? "")
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if proAccessManager.entitlementState != .pro {
            ContentUnavailableView(
                "Inventory Access Required",
                systemImage: "lock",
                description: Text("Return to Cubby to resolve your subscription access.")
            )
        } else if isLoading {
            ProgressView("Searching all homes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let searchError {
            ContentUnavailableView {
                Label("Search Unavailable", systemImage: "exclamationmark.magnifyingglass")
            } description: {
                Text(searchError)
            } actions: {
                Button("Try Again") { invalidateResults() }
            }
        } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView(
                "Search Your Items",
                systemImage: "magnifyingglass",
                description: Text("Find belongings across all your accessible homes.")
            )
        } else if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                Section {
                    ForEach(results) { record in
                        Button {
                            openingItemID = record.id
                        } label: {
                            SiriInventoryResultRow(
                                record: record,
                                isOpening: openingItemID == record.id
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(openingItemID != nil)
                        .appEntityIdentifier(
                            EntityIdentifier(for: InventoryItemEntity.self, identifier: record.id)
                        )
                        .accessibilityIdentifier("siri-search-result-\(record.id.uuidString)")
                    }
                } header: {
                    Text("All Homes")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private func invalidateResults() {
        results = []
        searchError = nil
        refreshID = UUID()
    }

    @MainActor
    private func loadResults() async {
        results = []
        searchError = nil
        isLoading = true
        let searchTerm = query.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if !searchTerm.isEmpty {
                let records = try await SiriInventoryService.shared.entities(matching: searchTerm)
                guard !Task.isCancelled else { return }
                results = records
            }
        } catch {
            guard !Task.isCancelled else { return }
            searchError = error.localizedDescription
        }
        guard !Task.isCancelled else { return }
        isLoading = false
        onNavigationHandled()
    }

    @MainActor
    private func openItem(id: UUID) async {
        do {
            _ = try await SiriInventoryService.shared.locateItem(id: id)
            guard !Task.isCancelled else { return }
            appStore.refresh()
            path.append(id)
        } catch {
            guard !Task.isCancelled else { return }
            openingError = error.localizedDescription
        }
        openingItemID = nil
    }

    private struct SearchTaskKey: Equatable {
        let query: String
        let refreshID: UUID
    }
}

private struct SiriInventoryResultRow: View {
    let record: SiriInventoryRecord
    let isOpening: Bool

    var body: some View {
        HStack(spacing: CubbyDesign.Spacing.medium) {
            Text(record.emoji ?? EmojiPicker.emoji(for: record.id))
                .font(.title2)
                .frame(width: CubbyDesign.Layout.rowIcon, height: CubbyDesign.Layout.rowIcon)
                .background(CubbyDesign.Palette.itemIconBackground, in: .rect(cornerRadius: CubbyDesign.Radius.medium))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: CubbyDesign.Spacing.xSmall) {
                Text(record.title)
                    .font(CubbyDesign.Typography.bodyEmphasized)
                    .foregroundStyle(.primary)
                Text(record.fullPath)
                    .font(CubbyDesign.Typography.path)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isOpening {
                ProgressView()
                    .accessibilityLabel("Opening item")
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, CubbyDesign.Spacing.xSmall)
        .frame(minHeight: CubbyDesign.Layout.minimumTapTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this item's details.")
    }
}
