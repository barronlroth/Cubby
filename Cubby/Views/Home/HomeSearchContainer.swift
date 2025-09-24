import SwiftUI

struct HomeSearchContainer: View {
    @State private var searchText: String = ""
    @State private var showingAddItem = false
    @State private var canAddItem = false
    @Environment(\.isSearching) private var isSearchActive
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        TabView {
            Tab(role: .search) {
                MainNavigationView(
                    searchText: $searchText,
                    showingAddItem: $showingAddItem,
                    canAddItem: $canAddItem
                )
                .searchable(text: $searchText, placement: .toolbarPrincipal, prompt: "Search Items")
                .configureSearchToolbar()
                .toolbar {
                    if horizontalSizeClass != .compact {
                        ToolbarItem(placement: .primaryAction) {
                            trailingButton
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if horizontalSizeClass == .compact {
                        bottomAddButton
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        #if !os(macOS)
        .applyTabBarMinimizeBehavior()
        #endif
    }

    private var bottomAddButton: some View {
        HStack {
            Spacer()
            trailingButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var trailingButton: some View {
        if isSearchActive || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button(action: {
                searchText = ""
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Cancel Search")
        } else {
            Button(action: { if canAddItem { showingAddItem = true } }) {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 6)
                    )
            }
            .disabled(!canAddItem)
            .accessibilityLabel("Add Item")
        }
    }
}

private extension View {
    @ViewBuilder
    func configureSearchToolbar() -> some View {
        if #available(iOS 26.0, *) {
            self
                .searchToolbarBehavior(.minimize)
                .searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            self
        }
    }
}

#if !os(macOS)
private extension View {
    @ViewBuilder
    func applyTabBarMinimizeBehavior() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
#endif
