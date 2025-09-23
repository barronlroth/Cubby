import SwiftUI
import SwiftData

struct MainNavigationView: View {
    @Query private var homes: [Home]
    @State private var selectedHome: Home?
    @State private var selectedLocation: StorageLocation?
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
            if selectedHome == nil && !homes.isEmpty {
                selectedHome = homes.first
                DebugLogger.info("MainNavigationView.onAppear - Set selectedHome to: \(homes.first?.name ?? "nil")")
            }
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
        }
        .onChange(of: selectedHome) { oldHome, newHome in
            DebugLogger.info("MainNavigationView - selectedHome changed from \(oldHome?.name ?? "nil") to \(newHome?.name ?? "nil")")
        }
        .animation(.spring(response: 0.3), value: selectedHome?.id)
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
