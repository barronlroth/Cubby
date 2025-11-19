import SwiftUI
import SwiftData

struct AddLocationView: View {
    let homeId: UUID?
    let parentLocation: StorageLocation?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var locationName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Location Details") {
                    TextField("Location Name", text: $locationName)
                        .textInputAutocapitalization(.words)
                    
                    if let parentLocation {
                        HStack {
                            Text("Parent Location")
                            Spacer()
                            Text(parentLocation.name)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if let parentLocation {
                    Section {
                        Label("This location will be nested under \"\(parentLocation.name)\"", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(appBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Storage Location")
                        .font(.custom("AwesomeSerif-ExtraTall", size: 20))
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveLocation() }
                        .disabled(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveLocation() {
        print("🔍 AddLocationView.saveLocation - homeId: \(String(describing: homeId))")
        
        // First, try to get the home from the parent location if available
        var home: Home?
        
        if let parentLocation {
            home = parentLocation.home
            print("🔍 AddLocationView - Got home from parent: \(String(describing: home?.name))")
        } else if let homeId {
            // Fetch the home directly from the model context
            let descriptor = FetchDescriptor<Home>(
                predicate: #Predicate { $0.id == homeId }
            )
            
            do {
                let homes = try modelContext.fetch(descriptor)
                print("🔍 AddLocationView - Fetched \(homes.count) homes for ID: \(homeId)")
                home = homes.first
            } catch {
                print("❌ AddLocationView - Fetch failed: \(error)")
                errorMessage = "Failed to fetch home: \(error.localizedDescription)"
                showingError = true
                return
            }
        }
        
        guard let home else {
            print("❌ AddLocationView - No home found, homeId: \(String(describing: homeId))")
            errorMessage = "Unable to find the selected home. Please try again."
            showingError = true
            return
        }
        
        let trimmedName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        if let parentLocation {
            if parentLocation.depth >= StorageLocation.maxNestingDepth - 1 {
                errorMessage = "Maximum nesting depth reached. Cannot create location here."
                showingError = true
                return
            }
            
            let siblings = parentLocation.childLocations ?? []
            if siblings.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                errorMessage = "A location with this name already exists at this level."
                showingError = true
                return
            }
        } else {
            let siblings = home.storageLocations ?? []
            if siblings.contains(where: { $0.name.lowercased() == trimmedName.lowercased() && $0.parentLocation == nil }) {
                errorMessage = "A location with this name already exists at this level."
                showingError = true
                return
            }
        }
        
        let newLocation = StorageLocation(name: trimmedName, home: home, parentLocation: parentLocation)
        modelContext.insert(newLocation)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save location: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    private var appBackground: Color {
        if colorScheme == .light, UIColor(named: "AppBackground") != nil {
            return Color("AppBackground")
        } else {
            return Color(.systemBackground)
        }
    }
}