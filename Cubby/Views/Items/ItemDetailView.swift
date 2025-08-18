import SwiftUI
import SwiftData
import PhotosUI

struct ItemDetailView: View {
    let item: InventoryItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var undoManager = UndoManager.shared
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedDescription = ""
    @State private var photo: UIImage?
    @State private var showingDeleteAlert = false
    @State private var showingMovePicker = false
    @State private var newLocation: StorageLocation?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let photoFileName = item.photoFileName {
                    Group {
                        if let photo {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ProgressView()
                                .frame(height: 200)
                        }
                    }
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if isEditing {
                            TextField("Title", text: $editedTitle)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if isEditing {
                            TextField("Description", text: $editedDescription, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        } else {
                            Text(item.itemDescription ?? "No description")
                                .foregroundStyle(item.itemDescription != nil ? .primary : .secondary)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text(item.storageLocation?.fullPath ?? "Unknown Location")
                        } icon: {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.tint)
                        }
                        
                        Label {
                            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        if item.modifiedAt != item.createdAt {
                            Label {
                                Text("Modified " + item.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                            } icon: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: { showingMovePicker = true }) {
                            Label("Move", systemImage: "folder.badge.gearshape")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    .padding(.top)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveChanges()
                    } else {
                        startEditing()
                    }
                }
            }
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("Are you sure you want to delete \"\(item.title)\"? You can undo this action for a limited time.")
        }
        .sheet(isPresented: $showingMovePicker) {
            StorageLocationPicker(selectedHomeId: item.storageLocation?.home?.id, selectedLocation: $newLocation)
                .onDisappear {
                    if let newLocation, newLocation.id != item.storageLocation?.id {
                        moveItem(to: newLocation)
                    }
                }
        }
        .task {
            await loadPhoto()
        }
    }
    
    private func loadPhoto() async {
        guard let photoFileName = item.photoFileName else { return }
        photo = await PhotoService.shared.loadPhoto(fileName: photoFileName)
    }
    
    private func startEditing() {
        editedTitle = item.title
        editedDescription = item.itemDescription ?? ""
        isEditing = true
    }
    
    private func saveChanges() {
        item.title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        item.itemDescription = editedDescription.isEmpty ? nil : editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        item.modifiedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save changes: \(error)")
        }
        
        isEditing = false
    }
    
    private func moveItem(to newLocation: StorageLocation) {
        item.storageLocation = newLocation
        item.modifiedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to move item: \(error)")
        }
    }
    
    private func deleteItem() {
        // Record the deletion for undo
        undoManager.recordDeletion(item: item)
        
        // Don't delete the photo yet since we might undo
        // The photo will be cleaned up when the undo stack is cleared or item removed from stack
        
        modelContext.delete(item)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to delete item: \(error)")
        }
    }
}