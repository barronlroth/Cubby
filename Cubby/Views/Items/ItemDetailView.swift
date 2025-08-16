//
//  ItemDetailView.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ItemDetailView: View {
    let item: InventoryItem
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    @State private var editedLocation: StorageLocation?
    @State private var editedImage: UIImage?
    @State private var loadedImage: UIImage?
    @State private var isLoadingImage = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    @State private var showingDeleteAlert = false
    @State private var showingMoveSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let photoFileName = item.photoFileName {
                    Group {
                        if let image = isEditing ? editedImage : loadedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                        } else if isLoadingImage {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                    .task {
                        if loadedImage == nil {
                            await loadPhoto(photoFileName)
                        }
                    }
                } else if let editedImage, isEditing {
                    Image(uiImage: editedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                }
                
                if isEditing {
                    editingView
                } else {
                    displayView
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Created", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                    
                    Label("Modified", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    HStack {
                        Button("Cancel") {
                            cancelEditing()
                        }
                        
                        Button("Save") {
                            Task {
                                await saveChanges()
                            }
                        }
                        .disabled(editedTitle.isEmpty || editedLocation == nil || isSaving)
                    }
                } else {
                    Menu {
                        Button(action: startEditing) {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(action: { showingMoveSheet = true }) {
                            Label("Move", systemImage: "folder")
                        }
                        
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
            Text("Are you sure you want to delete '\(item.title)'? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingMoveSheet) {
            if let home = item.storageLocation?.home {
                NavigationStack {
                    StorageLocationPicker(
                        currentHome: home,
                        selectedLocation: .init(
                            get: { item.storageLocation },
                            set: { newLocation in
                                if let location = newLocation {
                                    moveItem(to: location)
                                }
                            }
                        )
                    )
                }
            }
        }
        .disabled(isSaving)
        .overlay {
            if isSaving {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Saving...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
    }
    
    var displayView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.title)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let description = item.itemDescription, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            if let location = item.storageLocation {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.accentColor)
                    Text(location.fullPath)
                        .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    var editingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Title", text: $editedTitle)
                .textFieldStyle(.roundedBorder)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text("Description")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Description", text: $editedDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            
            if let home = item.storageLocation?.home {
                NavigationLink {
                    StorageLocationPicker(
                        currentHome: home,
                        selectedLocation: $editedLocation
                    )
                } label: {
                    HStack {
                        Text("Location")
                        Spacer()
                        Text(editedLocation?.fullPath ?? "Select")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading) {
                Text("Photo")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if editedImage != nil || item.photoFileName != nil {
                    Button(role: .destructive) {
                        editedImage = nil
                        selectedPhotoItem = nil
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                } else {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Add Photo")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .onChange(of: selectedPhotoItem) { _, newValue in
                        Task {
                            await loadSelectedImage(from: newValue)
                        }
                    }
                }
            }
        }
    }
    
    private func loadPhoto(_ fileName: String) async {
        isLoadingImage = true
        loadedImage = await PhotoService.shared.loadPhoto(fileName: fileName)
        isLoadingImage = false
    }
    
    private func loadSelectedImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    editedImage = image
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load image"
                showingError = true
            }
        }
    }
    
    private func startEditing() {
        editedTitle = item.title
        editedDescription = item.itemDescription ?? ""
        editedLocation = item.storageLocation
        editedImage = loadedImage
        isEditing = true
    }
    
    private func cancelEditing() {
        isEditing = false
        editedImage = nil
        selectedPhotoItem = nil
    }
    
    private func saveChanges() async {
        await MainActor.run {
            isSaving = true
        }
        
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        item.title = trimmedTitle
        item.itemDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        item.storageLocation = editedLocation
        item.modifiedAt = Date()
        
        let oldPhotoFileName = item.photoFileName
        
        if editedImage != loadedImage {
            if let newImage = editedImage {
                do {
                    let fileName = try await PhotoService.shared.savePhoto(newImage)
                    item.photoFileName = fileName
                    
                    if let oldFileName = oldPhotoFileName {
                        await PhotoService.shared.deletePhoto(fileName: oldFileName)
                    }
                    
                    await MainActor.run {
                        loadedImage = newImage
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to save photo: \(error.localizedDescription)"
                        showingError = true
                        isSaving = false
                    }
                    return
                }
            } else {
                item.photoFileName = nil
                if let oldFileName = oldPhotoFileName {
                    await PhotoService.shared.deletePhoto(fileName: oldFileName)
                }
                await MainActor.run {
                    loadedImage = nil
                }
            }
        }
        
        await MainActor.run {
            do {
                try modelContext.save()
                isEditing = false
                editedImage = nil
                selectedPhotoItem = nil
            } catch {
                errorMessage = "Failed to save changes: \(error.localizedDescription)"
                showingError = true
            }
            
            isSaving = false
        }
    }
    
    private func moveItem(to location: StorageLocation) {
        item.storageLocation = location
        item.modifiedAt = Date()
        
        do {
            try modelContext.save()
            showingMoveSheet = false
        } catch {
            errorMessage = "Failed to move item: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func deleteItem() {
        if let photoFileName = item.photoFileName {
            Task {
                await PhotoService.shared.deletePhoto(fileName: photoFileName)
            }
        }
        
        modelContext.delete(item)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to delete item: \(error.localizedDescription)"
            showingError = true
        }
    }
}