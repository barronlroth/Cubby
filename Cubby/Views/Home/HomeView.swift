//
//  HomeView.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allHomes: [Home]
    
    @State var currentHome: Home
    @State private var selectedLocation: StorageLocation?
    @State private var showingAddLocation = false
    @State private var showingAddHome = false
    @State private var newLocationName = ""
    @State private var selectedParentLocation: StorageLocation?
    
    var rootStorageLocations: [StorageLocation] {
        currentHome.storageLocations?.filter { $0.parentLocation == nil } ?? []
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedLocation) {
                ForEach(rootStorageLocations.sorted(by: { $0.name < $1.name })) { location in
                    StorageLocationRow(location: location, selectedLocation: $selectedLocation)
                }
            }
            .navigationTitle(currentHome.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HomePicker(currentHome: $currentHome, allHomes: allHomes)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingAddLocation = true }) {
                        Label("Add Location", systemImage: "folder.badge.plus")
                    }
                }
            }
            .overlay {
                if rootStorageLocations.isEmpty {
                    EmptyStorageLocationView(showingAddLocation: $showingAddLocation)
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationSheet(
                    home: currentHome,
                    parentLocation: selectedParentLocation,
                    isPresented: $showingAddLocation
                )
            }
        } detail: {
            if let selectedLocation {
                LocationDetailView(location: selectedLocation)
            } else {
                Text("Select a location")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct HomePicker: View {
    @Binding var currentHome: Home
    let allHomes: [Home]
    @State private var showingAddHome = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Menu {
            ForEach(allHomes.sorted(by: { $0.name < $1.name })) { home in
                Button(action: { currentHome = home }) {
                    if home.id == currentHome.id {
                        Label(home.name, systemImage: "checkmark")
                    } else {
                        Text(home.name)
                    }
                }
            }
            
            Divider()
            
            Button(action: { showingAddHome = true }) {
                Label("Add New Home", systemImage: "plus")
            }
        } label: {
            HStack {
                Image(systemName: "house")
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
        .sheet(isPresented: $showingAddHome) {
            AddHomeSheet(currentHome: $currentHome)
        }
    }
}

struct AddHomeSheet: View {
    @Binding var currentHome: Home
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var homeName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Home Details") {
                    TextField("Home name", text: $homeName)
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
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveHome() {
        let trimmedName = homeName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch ValidationHelpers.validateHomeName(trimmedName) {
        case .success:
            let home = Home(name: trimmedName)
            modelContext.insert(home)
            
            let unsortedLocation = StorageLocation(name: "Unsorted", home: home)
            modelContext.insert(unsortedLocation)
            
            do {
                try modelContext.save()
                currentHome = home
                dismiss()
            } catch {
                errorMessage = "Failed to create home: \(error.localizedDescription)"
                showingError = true
            }
            
        case .failure(let message):
            errorMessage = message
            showingError = true
        }
    }
}

struct EmptyStorageLocationView: View {
    @Binding var showingAddLocation: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No storage locations yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add your first location to start organizing")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddLocation = true }) {
                Label("Add your first location", systemImage: "plus")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}