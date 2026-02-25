import SwiftUI
import SwiftData
import UIKit

struct AddItemView: View {
    let selectedHomeId: UUID?
    var preselectedLocation: StorageLocation? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.activePaywall) private var activePaywall
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var proAccessManager: ProAccessManager
    
    @State private var title = ""
    @State private var itemDescription = ""
    @State private var selectedLocation: StorageLocation?
    @State private var selectedImage: UIImage?
    @State private var showingLocationPicker = false
    @State private var showingEmojiPicker = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var cameraUnavailableAlert = false
    @State private var isSaving = false
    @State private var selectedHome: Home?
    @State private var tags: Set<String> = []
    @State private var tagInput = ""
    @Query private var allItems: [InventoryItem]
    @FocusState private var titleIsFocused: Bool
    @State private var showingGateAlert = false
    @State private var gatePaywallReason: PaywallContext.Reason = .itemLimitReached
    @State private var selectedEmoji: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .focused($titleIsFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            applyPreferredLocationIfNeeded()
                            if !isSaving, selectedLocation != nil {
                                Task { await saveItem() }
                            } else if selectedLocation == nil {
                                showingLocationPicker = true
                            }
                        }
                    
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

                Section("Emoji") {
                    Button(action: { showingEmojiPicker = true }) {
                        HStack(spacing: 12) {
                            Text("Item Emoji")
                            Spacer()
                            if let selectedEmoji {
                                Text(selectedEmoji)
                                    .font(.system(size: 28))
                                    .padding(6)
                                    .background(.thinMaterial)
                                    .clipShape(Circle())
                            } else {
                                Label("Auto", systemImage: "sparkles")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
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
            .scrollContentBackground(.hidden)
            .background(appBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Item")
                        .font(.custom("AwesomeSerif-ExtraTall", size: 20))
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await saveItem() } }
                        .disabled(title.isEmpty || selectedLocation == nil || isSaving)
                }
            }
            .alert("Cubby Pro Required", isPresented: $showingGateAlert) {
                Button("Upgrade") {
                    presentUpgrade()
                }
                Button("Restore Purchases") {
                    Task { await proAccessManager.restorePurchases() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(gateAlertMessage)
            }
            .sheet(isPresented: $showingLocationPicker) {
                StorageLocationPicker(selectedHomeId: selectedHomeId, selectedLocation: $selectedLocation)
            }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiSelectionView(selectedEmoji: selectedEmoji) { emoji in
                    selectedEmoji = emoji
                }
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
                applyPreferredLocationIfNeeded()
            }
            .task {
                // Slight delay ensures the sheet is fully presented before focusing
                try? await Task.sleep(nanoseconds: 150_000_000)
                await MainActor.run { titleIsFocused = true }
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
    
    private func applyPreferredLocationIfNeeded() {
        if selectedLocation == nil,
           let preferred = LastUsedLocationService.preferredLocation(
            for: selectedHomeId,
            in: modelContext
           ) {
            selectedLocation = preferred
        }
    }

    private func saveItem() async {
        let gate = FeatureGate.canCreateItem(homeId: selectedHomeId, modelContext: modelContext, isPro: proAccessManager.isPro)
        guard gate.isAllowed else {
            DebugLogger.info("FeatureGate denied item creation: \(gate.reason?.description ?? "unknown")")
            gatePaywallReason = gate.reason == .overLimit ? .overLimit : .itemLimitReached
            showingGateAlert = true
            return
        }

        guard let selectedLocation else { return }
        
        isSaving = true
        
        let newItem = InventoryItem(
            title: title.titleCased(),
            description: itemDescription.isEmpty ? nil : itemDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            storageLocation: selectedLocation
        )
        newItem.tagsSet = tags
        if let selectedEmoji {
            newItem.emoji = selectedEmoji
            newItem.isPendingAiEmoji = false
        } else {
            newItem.emoji = EmojiPicker.emoji(for: newItem.id)
        }
        if selectedEmoji == nil, FoundationModelEmojiService.isSupported {
            newItem.isPendingAiEmoji = true
        }
        
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
            LastUsedLocationService.remember(location: selectedLocation)
            if let pid = newItem.persistentModelID as? PersistentIdentifier {
                EmojiAssignmentCoordinator.shared.postSaveEmojiEnhancement(
                    for: pid,
                    title: newItem.title,
                    modelContext: modelContext
                )
            } else {
                EmojiAssignmentCoordinator.shared.postSaveEmojiEnhancement(
                    for: newItem.persistentModelID,
                    title: newItem.title,
                    modelContext: modelContext
                )
            }
            dismiss()
        } catch {
            print("Failed to save item: \(error)")
            isSaving = false
        }
    }

    private var gateAlertMessage: String {
        switch gatePaywallReason {
        case .itemLimitReached:
            "Free includes up to 10 items. Upgrade to Cubby Pro to add more."
        case .overLimit:
            "You’re over the Free limit. Upgrade to Pro or delete down to continue creating."
        case .homeLimitReached:
            "Upgrade to Cubby Pro to add more."
        case .manualUpgrade:
            "Upgrade to Cubby Pro to unlock unlimited homes and items."
        }
    }

    private func presentUpgrade() {
        let reason = gatePaywallReason
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            activePaywall.wrappedValue = PaywallContext(reason: reason)
        }
    }
    
    private var tagSuggestions: [String] {
        TagSuggestionService.suggestions(
            for: tagInput,
            existingTags: allItems.flatMap(\.tags)
        )
    }
    
    @Environment(\.colorScheme) private var colorScheme
    private var appBackground: Color {
        if colorScheme == .light, UIColor(named: "AppBackground") != nil {
            return Color("AppBackground")
        } else {
            return Color(.systemBackground)
        }
    }
}
