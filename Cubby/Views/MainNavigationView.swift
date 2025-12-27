import SwiftUI
import SwiftData

struct MainNavigationView: View {
    @Binding var searchText: String
    @Binding var showingAddItem: Bool
    @Binding var canAddItem: Bool
    @Query private var homes: [Home]
    @State private var selectedHome: Home?
    @State private var selectedLocation: StorageLocation?
    @State private var showingUndoToast = false
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @StateObject private var undoManager = UndoManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isSearching) private var isSearching
    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.activePaywall) private var activePaywall
    @EnvironmentObject private var proAccessManager: ProAccessManager
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
                    ToolbarItem(placement: .bottomBar) {
                        Spacer(minLength: 12)
                    }
                    ToolbarItem(placement: .bottomBar) {
                        toolbarButton
                    }
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
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
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
                }
            }
            .padding(.top, 8)
            .animation(.spring(response: 0.3), value: undoManager.canUndo)
            .animation(.easeInOut(duration: 0.2), value: undoManager.timeRemaining)
        }
        .onAppear {
            if selectedHome == nil {
                if let lastIdString = lastUsedHomeId,
                   let lastId = UUID(uuidString: lastIdString),
                   let restoredHome = homes.first(where: { $0.id == lastId }) {
                    selectedHome = restoredHome
                    DebugLogger.info("MainNavigationView.onAppear - Restored last used home: \(restoredHome.name)")
                } else if !homes.isEmpty {
                    selectedHome = homes.first
                    DebugLogger.info("MainNavigationView.onAppear - No last used home found, defaulted to: \(homes.first?.name ?? "nil")")
                }
            }
            canAddItem = selectedHome != nil
        }
        .onChange(of: homes) { oldHomes, newHomes in
            // Keep selectedHome synchronized with homes
            if let currentHome = selectedHome {
                // Check if current home still exists
                if !newHomes.contains(where: { $0.id == currentHome.id }) {
                    // Current home was deleted, select first available
                    selectedHome = newHomes.first
                    DebugLogger.warning("MainNavigationView - Selected home was deleted, switching to: \(newHomes.first?.name ?? "none")")
                }
            } else if selectedHome == nil && !newHomes.isEmpty {
                // No home selected but homes exist, select first
                selectedHome = newHomes.first
                DebugLogger.info("MainNavigationView - No home selected, auto-selecting: \(newHomes.first?.name ?? "none")")
            }
            canAddItem = selectedHome != nil
        }
        .onChange(of: selectedHome) { oldHome, newHome in
            DebugLogger.info("MainNavigationView - selectedHome changed from \(oldHome?.name ?? "nil") to \(newHome?.name ?? "nil")")
            if let newHome {
                lastUsedHomeId = newHome.id.uuidString
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
            ToolbarItem(placement: .bottomBar) {
                toolbarButton
            }
        }
        #else
        ToolbarItem(placement: .primaryAction) {
            toolbarButton
        }
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
        } else if canAddItem, let selectedHome {
            let gate = FeatureGate.canCreateItem(
                homeId: selectedHome.id,
                modelContext: modelContext,
                isPro: proAccessManager.isPro
            )
            guard gate.isAllowed else {
                DebugLogger.info("FeatureGate denied item creation: \(gate.reason?.description ?? "unknown")")
                if gate.reason == .overLimit {
                    activePaywall.wrappedValue = PaywallContext(reason: .overLimit)
                } else {
                    activePaywall.wrappedValue = PaywallContext(reason: .itemLimitReached)
                }
                return
            }
            showingAddItem = true
        }
    }

    private func performUndo() {
        let success = undoManager.undo(in: modelContext)
        if success {
            showingUndoToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingUndoToast = false
            }
        }
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
