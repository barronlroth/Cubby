import SwiftUI
import SwiftData
import PhotosUI

struct AddItemView: View {
    let selectedHome: Home?
    var preselectedLocation: StorageLocation? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title = ""
    @State private var itemDescription = ""
    @State private var selectedLocation: StorageLocation?
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingLocationPicker = false
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Description", text: $itemDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section("Location") {
                    Button(action: { showingLocationPicker = true }) {
                        HStack {
                            Text("Storage Location")
                            Spacer()
                            Text(selectedLocation?.fullPath ?? "Select")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section("Photo") {
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Button("Remove Photo", role: .destructive) {
                            self.selectedImage = nil
                            self.selectedPhotoItem = nil
                        }
                    } else {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Add Photo", systemImage: "camera")
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await saveItem() } }
                        .disabled(title.isEmpty || selectedLocation == nil || isSaving)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                StorageLocationPicker(selectedHome: selectedHome, selectedLocation: $selectedLocation)
            }
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                    }
                }
            }
            .onAppear {
                if let preselectedLocation {
                    selectedLocation = preselectedLocation
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private func saveItem() async {
        guard let selectedLocation else { return }
        
        isSaving = true
        
        let newItem = InventoryItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: itemDescription.isEmpty ? nil : itemDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            storageLocation: selectedLocation
        )
        
        if let selectedImage {
            do {
                let fileName = try await PhotoService.shared.savePhoto(selectedImage)
                newItem.photoFileName = fileName
            } catch {
                print("Failed to save photo: \(error)")
            }
        }
        
        modelContext.insert(newItem)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save item: \(error)")
            isSaving = false
        }
    }
}