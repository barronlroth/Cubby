//
//  StorageLocationPicker.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData

struct StorageLocationPicker: View {
    let currentHome: Home
    @Binding var selectedLocation: StorageLocation?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchText = ""
    @State private var showingAddLocation = false
    @State private var parentForNewLocation: StorageLocation?
    
    var allLocations: [StorageLocation] {
        currentHome.storageLocations ?? []
    }
    
    var filteredLocations: [StorageLocation] {
        if searchText.isEmpty {
            return allLocations
        }
        return allLocations.filter { location in
            location.name.localizedCaseInsensitiveContains(searchText) ||
            location.fullPath.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var sortedLocations: [StorageLocation] {
        filteredLocations.sorted { $0.fullPath < $1.fullPath }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        Button(action: {
                            parentForNewLocation = nil
                            showingAddLocation = true
                        }) {
                            Label("Create New Location", systemImage: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                Section {
                    ForEach(sortedLocations) { location in
                        LocationPickerRow(
                            location: location,
                            isSelected: selectedLocation?.id == location.id,
                            onSelect: {
                                selectedLocation = location
                                dismiss()
                            },
                            onAddChild: {
                                parentForNewLocation = location
                                showingAddLocation = true
                            }
                        )
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search locations")
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationSheet(
                    home: currentHome,
                    parentLocation: parentForNewLocation,
                    isPresented: $showingAddLocation
                )
                .onDisappear {
                    if let newLocation = getNewestLocation() {
                        selectedLocation = newLocation
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getNewestLocation() -> StorageLocation? {
        allLocations.max(by: { $0.createdAt < $1.createdAt })
    }
}

struct LocationPickerRow: View {
    let location: StorageLocation
    let isSelected: Bool
    let onSelect: () -> Void
    let onAddChild: () -> Void
    
    var indentLevel: Int {
        location.depth
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<indentLevel, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 20)
                }
                
                Image(systemName: location.childLocations?.isEmpty == false ? "folder.fill" : "folder")
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
            }
            
            VStack(alignment: .leading) {
                Text(location.name)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text(location.fullPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
            
            if location.depth < StorageLocation.maxNestingDepth - 1 {
                Button(action: onAddChild) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}