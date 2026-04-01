import SwiftUI

struct MainNavigationView: View {
    @Binding var searchText: String
    @Binding var showingAddItem: Bool
    @Binding var canAddItem: Bool

    @State private var selectedHome: AppHome?
    @State private var selectedLocation: AppStorageLocation?
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @StateObject private var undoManager = UndoManager.shared

    @Environment(\.isSearching) private var isSearching
    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.activePaywall) private var activePaywall
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @EnvironmentObject private var appStore: AppStore
    @AppStorage("lastUsedHomeId") private var lastUsedHomeId: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            HomeView(
                selectedHome: $selectedHome,
                selectedLocation: $selectedLocation,
                searchText: $searchText,
                showingAddItem: $showingAddItem
            )
            .searchable(text: $searchText, prompt: Text("Search Items"))
            .applyLiquidGlassSearchBehaviors()
            .scrollContentBackground(.hidden)
            .modifier(ApplyHomeDesign())
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .modifier(ContentTopMarginZero())
            .toolbar {
                #if os(iOS)
                if #available(iOS 26.0, *) {
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) { Spacer(minLength: 12) }
                    ToolbarItem(placement: .bottomBar) { toolbarButton }
                }
                #endif
            }
        } detail: {
            if let selectedLocation {
                LocationDetailView(location: selectedLocation)
            } else {
                ContentUnavailableView(
                    "Select a Location",
                    systemImage: "folder",
                    description: Text("Choose a storage location to view its items")
                )
            }
        }
        .toolbar { toolbarContent }
        .overlay(alignment: .topTrailing) {
            if undoManager.canUndo {
                HStack(spacing: 4) {
                    Button(action: performUndo) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                            Text(undoManager.undoDescription ?? "Undo")
                            if undoManager.timeRemaining > 0 {
                                Text("(\(undoManager.timeRemaining)s)")
                                    .font(.caption2)
                                    .opacity(0.8)
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.9))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }

                    Button(action: { undoManager.dismissUndo() }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .frame(width: 24, height: 24)
                            .background(Color.gray.opacity(0.6))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                .transition(.scale.combined(with: .opacity))
                .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.3), value: undoManager.canUndo)
        .animation(.easeInOut(duration: 0.2), value: undoManager.timeRemaining)
        .onAppear(perform: restoreSelectedHomeIfNeeded)
        .onChange(of: appStore.homes) { _, newHomes in
            synchronizeSelectedHome(with: newHomes)
        }
        .onChange(of: selectedHome) { _, newHome in
            if let newHome {
                lastUsedHomeId = newHome.id.uuidString
            }
            if selectedLocation?.homeID != newHome?.id {
                selectedLocation = nil
            }
            canAddItem = newHome != nil
        }
        .animation(.spring(response: 0.3), value: selectedHome?.id)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearchEngaged: Bool {
        !trimmedSearchText.isEmpty || isSearching
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        if #unavailable(iOS 26.0) {
            ToolbarItem(placement: .bottomBar) { toolbarButton }
        }
        #else
        ToolbarItem(placement: .primaryAction) { toolbarButton }
        #endif
    }

    private var toolbarButton: some View {
        Button(action: handleToolbarButtonTap) {
            Image(systemName: toolbarIconName)
                .font(.system(size: 20, weight: .semibold))
        }
        .labelStyle(.iconOnly)
        .controlSize(.large)
        .disabled(!isSearchEngaged && !canAddItem)
        .accessibilityLabel(toolbarAccessibilityLabel)
        .accessibilityHint(toolbarAccessibilityHint)
    }

    private var toolbarIconName: String {
        isSearchEngaged ? "xmark" : "plus"
    }

    private var toolbarAccessibilityLabel: String {
        isSearchEngaged ? "Cancel Search" : "Add Item"
    }

    private var toolbarAccessibilityHint: String {
        if isSearchEngaged {
            return "Clears the current search text"
        }
        return canAddItem ? "Opens the new item form" : "Select a home to add items"
    }

    private func handleToolbarButtonTap() {
        if isSearchEngaged {
            searchText = ""
            if #available(iOS 17.0, *) {
                dismissSearch()
            }
            return
        }

        guard canAddItem, let selectedHome else { return }
        let gate = appStore.canCreateItem(homeID: selectedHome.id, isPro: proAccessManager.isPro)
        guard gate.isAllowed else {
            if gate.reason == .overLimit {
                activePaywall.wrappedValue = PaywallContext(reason: .overLimit)
            } else {
                activePaywall.wrappedValue = PaywallContext(reason: .itemLimitReached)
            }
            return
        }
        showingAddItem = true
    }

    private func performUndo() {
        _ = undoManager.undo(using: appStore)
    }

    private func restoreSelectedHomeIfNeeded() {
        guard selectedHome == nil else { return }

        if let lastIdString = lastUsedHomeId,
           let lastId = UUID(uuidString: lastIdString),
           let restoredHome = appStore.home(id: lastId) {
            selectedHome = restoredHome
        } else {
            selectedHome = appStore.homes.first
        }
        canAddItem = selectedHome != nil
    }

    private func synchronizeSelectedHome(with homes: [AppHome]) {
        if let currentHome = selectedHome {
            if let refreshedSelection = homes.first(where: { $0.id == currentHome.id }) {
                selectedHome = refreshedSelection
            } else {
                selectedHome = homes.first
            }
        } else if selectedHome == nil && !homes.isEmpty {
            selectedHome = homes.first
        }

        if let selectedLocation,
           appStore.location(id: selectedLocation.id) == nil {
            self.selectedLocation = nil
        }

        canAddItem = selectedHome != nil
    }
}

private extension View {
    @ViewBuilder
    func applyLiquidGlassSearchBehaviors() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            self
                .searchToolbarBehavior(.minimize)
                .searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

private struct ContentTopMarginZero: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            content
                .contentMargins(.top, 0, for: .scrollContent)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct ApplyHomeDesign: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color("CubbyHomeBackground"))
    }
}
