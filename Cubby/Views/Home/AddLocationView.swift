import SwiftUI
import SwiftData

struct AddLocationView: View {
    let homeId: UUID?
    let parentLocation: StorageLocation?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.homeSharingService) private var homeSharingService
    @Environment(\.sharedHomesGateService) private var sharedHomesGateService
    @State private var locationName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var resolvedHome: Home?
    
    var body: some View {
        NavigationStack {
            Form {
                if canCreateLocationsInHome == false {
                    Section {
                        Label(
                            "You have read-only access to this shared home.",
                            systemImage: "lock.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

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
                        .disabled(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canCreateLocationsInHome)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                resolvedHome = fetchHomeForCurrentSelection()
            }
        }
    }
    
    private func saveLocation() {
        print("🔍 AddLocationView.saveLocation - homeId: \(String(describing: homeId))")

        if resolvedHome == nil {
            resolvedHome = fetchHomeForCurrentSelection()
        }

        guard canCreateLocationsInHome else {
            errorMessage = "You have read-only access and can’t add locations in this shared home."
            showingError = true
            return
        }

        let home = resolvedHome
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

    private var canCreateLocationsInHome: Bool {
        guard sharedHomesGateService.isEnabled() else { return true }
        guard let home = resolvedHome ?? fetchHomeForCurrentSelection() else { return false }
        guard let homeSharingService else { return true }
        return homeSharingService.canCreateLocations(in: home)
    }

    private func fetchHomeForCurrentSelection() -> Home? {
        if let parentLocation {
            return parentLocation.home
        }

        guard let homeId else {
            return nil
        }

        let descriptor = FetchDescriptor<Home>(
            predicate: #Predicate { $0.id == homeId }
        )

        do {
            let homes = try modelContext.fetch(descriptor)
            print("🔍 AddLocationView - Fetched \(homes.count) homes for ID: \(homeId)")
            return homes.first
        } catch {
            print("❌ AddLocationView - Fetch failed: \(error)")
            return nil
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
