import SwiftUI
import SwiftData

struct AddLocationView: View {
    let home: Home?
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
            .navigationTitle("Add Storage Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        guard let home else { return }
        
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
}