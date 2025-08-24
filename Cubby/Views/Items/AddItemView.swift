import SwiftUI
import SwiftData
import PhotosUI

struct AddItemView: View {
    let selectedHomeId: UUID?
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
                StorageLocationPicker(selectedHomeId: selectedHomeId, selectedLocation: $selectedLocation)
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
        newItem.tags = tags
        
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
        
        return Set(allItems.flatMap { Array($0.tags) })
            .filter { $0.contains(formatted) && $0 != formatted }
            .sorted()
            .prefix(5)
            .map { String($0) }
    }
}