import SwiftUI
import SwiftData

struct AddHomeView: View {
    @Binding var selectedHome: Home?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var homeName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Home Details") {
                    TextField("Home Name", text: $homeName)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Add New Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveHome() }
                        .disabled(homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveHome() {
        let trimmedName = homeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newHome = Home(name: trimmedName)
        modelContext.insert(newHome)
        
        let unsortedLocation = StorageLocation(name: "Unsorted", home: newHome)
        modelContext.insert(unsortedLocation)
        
        do {
            try modelContext.save()
            selectedHome = newHome
            dismiss()
        } catch {
            print("Failed to save home: \(error)")
        }
    }
}