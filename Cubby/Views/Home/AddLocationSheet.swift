//
//  AddLocationSheet.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData

struct AddLocationSheet: View {
    let home: Home
    let parentLocation: StorageLocation?
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var locationName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Location Details") {
                    TextField("Location name", text: $locationName)
                    
                    if let parent = parentLocation {
                        HStack {
                            Text("Parent Location")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(parent.fullPath)
                        }
                    } else {
                        HStack {
                            Text("Parent Location")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Root level")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let parent = parentLocation {
                    Section {
                        if parent.depth >= StorageLocation.maxNestingDepth - 1 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Maximum nesting depth reached")
                                    .font(.caption)
                            }
                        }
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
                        .disabled(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                                !ValidationHelpers.validateNestingDepth(parentLocation))
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
        let trimmedName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch ValidationHelpers.validateLocationName(trimmedName, in: parentLocation, home: home) {
        case .success:
            let newLocation = StorageLocation(name: trimmedName, home: home, parentLocation: parentLocation)
            modelContext.insert(newLocation)
            
            do {
                try modelContext.save()
                dismiss()
            } catch {
                errorMessage = "Failed to create location: \(error.localizedDescription)"
                showingError = true
            }
            
        case .failure(let message):
            errorMessage = message
            showingError = true
        }
    }
}