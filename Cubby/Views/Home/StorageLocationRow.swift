//
//  StorageLocationRow.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData

struct StorageLocationRow: View {
    let location: StorageLocation
    @Binding var selectedLocation: StorageLocation?
    @State private var isExpanded = false
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteAlert = false
    @State private var showingAddLocation = false
    
    var itemCount: Int {
        location.items?.count ?? 0
    }
    
    var hasChildren: Bool {
        !(location.childLocations?.isEmpty ?? true)
    }
    
    var sortedChildren: [StorageLocation] {
        location.childLocations?.sorted(by: { $0.name < $1.name }) ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if hasChildren {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Spacer()
                        .frame(width: 20)
                }
                
                Button(action: { selectedLocation = location }) {
                    HStack {
                        Image(systemName: hasChildren ? "folder.fill" : "folder")
                            .foregroundColor(.accentColor)
                        
                        Text(location.name)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if itemCount > 0 {
                            Text("\(itemCount)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
            .padding(.leading, CGFloat(location.depth) * 20)
            .contentShape(Rectangle())
            .contextMenu {
                Button(action: { showingAddLocation = true }) {
                    Label("Add Nested Location", systemImage: "folder.badge.plus")
                }
                
                if location.canDelete {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if location.canDelete {
                    Button(role: .destructive, action: deleteLocation) {
                        Label("Delete", systemImage: "trash")
                    }
                }
                
                Button(action: { showingAddLocation = true }) {
                    Label("Add", systemImage: "folder.badge.plus")
                }
                .tint(.blue)
            }
            
            if isExpanded && hasChildren {
                ForEach(sortedChildren) { child in
                    StorageLocationRow(location: child, selectedLocation: $selectedLocation)
                }
            }
        }
        .sheet(isPresented: $showingAddLocation) {
            AddLocationSheet(
                home: location.home!,
                parentLocation: location,
                isPresented: $showingAddLocation
            )
        }
        .alert("Delete Location", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: deleteLocation)
        } message: {
            Text("Are you sure you want to delete '\(location.name)'?")
        }
    }
    
    private func deleteLocation() {
        if location.canDelete {
            modelContext.delete(location)
            if selectedLocation?.id == location.id {
                selectedLocation = nil
            }
            try? modelContext.save()
        }
    }
}