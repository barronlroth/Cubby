import SwiftUI
import SwiftData
import UIKit

struct AddItemView: View {
    let selectedHomeId: UUID?
    var preselectedLocation: StorageLocation? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title = ""
    @State private var itemDescription = ""
    @State private var selectedLocation: StorageLocation?
    @State private var selectedImage: UIImage?
    @State private var showingLocationPicker = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var cameraUnavailableAlert = false
    @State private var isSaving = false
    @State private var selectedHome: Home?
    @State private var tags: Set<String> = []
    @State private var tagInput = ""
    @Query private var allItems: [InventoryItem]
    
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
                
                Section("Tags") {
                    TagInputView(
                        tags: $tags,
                        currentInput: $tagInput,
                        suggestions: tagSuggestions
                    )
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
                        }
                    } else {
                        Menu {
                            Button {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    showingCamera = true
                                } else {
                                    cameraUnavailableAlert = true
                                }
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                            }
                            Button {
                                showingPhotoPicker = true
                            } label: {
                                Label("Choose from Gallery", systemImage: "photo")
                            }
                        } label: {
                            Label("Add Photo", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            .alert("Camera Unavailable", isPresented: $cameraUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The camera is not available on this device.")
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
                StorageLocationPicker(selectedHomeId: selectedHomeId, selectedLocation: $selectedLocation)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoLibraryPicker(selectedImage: $selectedImage)
            }
            .onAppear {
                DebugLogger.info("AddItemView.onAppear - homeId: \(String(describing: selectedHomeId))")
                if let preselectedLocation {
                    selectedLocation = preselectedLocation
                }
                // Fetch the home when view appears
                if let selectedHomeId {
                    DebugLogger.info("AddItemView - Fetching home with ID: \(selectedHomeId)")
                    let descriptor = FetchDescriptor<Home>(
                        predicate: #Predicate { $0.id == selectedHomeId }
                    )
                    if let homes = try? modelContext.fetch(descriptor) {
                        DebugLogger.info("AddItemView - Fetched \(homes.count) homes")
                        selectedHome = homes.first
                        if selectedHome == nil {
                            DebugLogger.error("AddItemView - No home found for ID: \(selectedHomeId)")
                        } else {
                            DebugLogger.success("AddItemView - Home found: \(selectedHome!.name)")
                        }
                    }
                } else {
                    DebugLogger.warning("AddItemView - No homeId provided")
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
        newItem.tagsSet = tags
        
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
    
    private var tagSuggestions: [String] {
        guard !tagInput.isEmpty else { return [] }
        let formatted = tagInput.formatAsTag()
        
        return Set(allItems.flatMap { $0.tags })
            .filter { $0.contains(formatted) && $0 != formatted }
            .sorted()
            .prefix(5)
            .map { String($0) }
    }
}
