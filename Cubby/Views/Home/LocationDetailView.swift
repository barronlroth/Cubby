//
//  LocationDetailView.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData

struct LocationDetailView: View {
    let location: StorageLocation
    @Environment(\.modelContext) private var modelContext
    @State private var editingName = false
    @State private var newName = ""
    @State private var showingAddItem = false
    
    var sortedItems: [InventoryItem] {
        location.items?.sorted(by: { $0.title < $1.title }) ?? []
    }
    
    var sortedChildLocations: [StorageLocation] {
        location.childLocations?.sorted(by: { $0.name < $1.name }) ?? []
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if editingName {
                            TextField("Location name", text: $newName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    saveNameChange()
                                }
                            
                            Button("Cancel") {
                                newName = location.name
                                editingName = false
                            }
                            
                            Button("Save") {
                                saveNameChange()
                            }
                            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        } else {
                            Text(location.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Button(action: { 
                                newName = location.name
                                editingName = true 
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    Text(location.fullPath)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                if !sortedChildLocations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nested Locations")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(sortedChildLocations) { childLocation in
                            NavigationLink(destination: LocationDetailView(location: childLocation)) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.accentColor)
                                    Text(childLocation.name)
                                    Spacer()
                                    Text("\(childLocation.items?.count ?? 0) items")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Items")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { showingAddItem = true }) {
                            Label("Add Item", systemImage: "plus")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    
                    if sortedItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No items in this location")
                                .foregroundColor(.secondary)
                            
                            Button(action: { showingAddItem = true }) {
                                Text("Add first item")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(sortedItems) { item in
                            ItemRow(item: item)
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddItem) {
            if let home = location.home {
                AddItemView(currentHome: home, preselectedLocation: location)
            }
        }
    }
    
    private func saveNameChange() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty && trimmedName != location.name {
            location.name = trimmedName
            location.modifiedAt = Date()
            try? modelContext.save()
        }
        editingName = false
    }
}