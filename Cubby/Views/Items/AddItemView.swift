//
//  AddItemView.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddItemView: View {
    let currentHome: Home
    var preselectedLocation: StorageLocation? = nil
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var itemDescription = ""
    @State private var selectedLocation: StorageLocation?
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isLoadingImage = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $itemDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Location") {
                    NavigationLink {
                        StorageLocationPicker(
                            currentHome: currentHome,
                            selectedLocation: $selectedLocation
                        )
                    } label: {
                        HStack {
                            Text("Storage Location")
                            Spacer()
                            Text(selectedLocation?.fullPath ?? "Select")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Photo") {
                    if let selectedImage {
                        VStack {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                            
                            Button(role: .destructive) {
                                self.selectedImage = nil
                                self.selectedPhotoItem = nil
                            } label: {
                                Label("Remove Photo", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    } else {
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images
                        ) {
                            HStack {
                                Image(systemName: "camera")
                                Text("Add Photo")
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newValue in
                            Task {
                                await loadImage(from: newValue)
                            }
                        }
                    }
                    
                    if isLoadingImage {
                        HStack {
                            ProgressView()
                            Text("Loading image...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { 
                        Task {
                            await saveItem()
                        }
                    }
                    .disabled(title.isEmpty || selectedLocation == nil || isSaving)
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
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            selectedLocation = preselectedLocation
        }
    }
    
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        
        isLoadingImage = true
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                    isLoadingImage = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load image"
                showingError = true
                isLoadingImage = false
            }
        }
    }
    
    private func saveItem() async {
        guard let location = selectedLocation else { return }
        
        await MainActor.run {
            isSaving = true
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch ValidationHelpers.validateItemTitle(trimmedTitle) {
        case .failure(let message):
            await MainActor.run {
                errorMessage = message
                showingError = true
                isSaving = false
            }
            return
        case .success:
            break
        }
        
        let newItem = InventoryItem(
            title: trimmedTitle,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            storageLocation: location
        )
        
        if let image = selectedImage {
            do {
                let fileName = try await PhotoService.shared.savePhoto(image)
                newItem.photoFileName = fileName
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save photo: \(error.localizedDescription)"
                    showingError = true
                    isSaving = false
                }
                return
            }
        }
        
        await MainActor.run {
            modelContext.insert(newItem)
            
            do {
                try modelContext.save()
                dismiss()
            } catch {
                errorMessage = "Failed to save item: \(error.localizedDescription)"
                showingError = true
                
                if let photoFileName = newItem.photoFileName {
                    Task {
                        await PhotoService.shared.deletePhoto(fileName: photoFileName)
                    }
                }
                modelContext.delete(newItem)
            }
            
            isSaving = false
        }
    }
}