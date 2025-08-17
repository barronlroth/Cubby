import SwiftUI
import SwiftData

struct MainNavigationView: View {
    @Query private var homes: [Home]
    @State private var selectedHome: Home?
    @State private var selectedLocation: StorageLocation?
    @State private var showingAddItem = false
    @State private var showingSearch = false
    @State private var showingUndoToast = false
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @StateObject private var undoManager = UndoManager.shared
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            HomeView(selectedHome: $selectedHome, selectedLocation: $selectedLocation)
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
        .overlay(alignment: .bottomTrailing) {
            AddItemFloatingButton(showingAddItem: $showingAddItem)
                .padding()
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                SearchPillButton(showingSearch: $showingSearch)
                
                if undoManager.canUndo {
                    Button(action: performUndo) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                            Text(undoManager.undoDescription ?? "Undo")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.9))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.top, 8)
            .animation(.spring(response: 0.3), value: undoManager.canUndo)
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(selectedHome: selectedHome)
        }
        .sheet(isPresented: $showingSearch) {
            SearchView()
        }
        .onAppear {
            if selectedHome == nil && !homes.isEmpty {
                selectedHome = homes.first
            }
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

struct AddItemFloatingButton: View {
    @Binding var showingAddItem: Bool
    
    var body: some View {
        Button(action: { showingAddItem = true }) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(radius: 4, y: 2)
        }
    }
}

struct SearchPillButton: View {
    @Binding var showingSearch: Bool
    
    var body: some View {
        Button(action: { showingSearch = true }) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(Capsule())
        }
    }
}