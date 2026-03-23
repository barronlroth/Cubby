import SwiftUI
import UIKit

struct AddItemView: View {
    let selectedHomeId: UUID?
    var preselectedLocation: AppStorageLocation? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.activePaywall) private var activePaywall
    @Environment(\.sharedHomesGateService) private var sharedHomesGateService
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @EnvironmentObject private var appStore: AppStore

    @State private var title = ""
    @State private var itemDescription = ""
    @State private var selectedLocation: AppStorageLocation?
    @State private var selectedImage: UIImage?
    @State private var showingLocationPicker = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var cameraUnavailableAlert = false
    @State private var isSaving = false
    @State private var tags: Set<String> = []
    @State private var tagInput = ""
    @FocusState private var titleIsFocused: Bool
    @State private var showingGateAlert = false
    @State private var gatePaywallReason: PaywallContext.Reason = .itemLimitReached

    private var selectedHome: AppHome? {
        appStore.home(id: selectedHomeId)
    }

    var body: some View {
        NavigationStack {
            Form {
                if canAddItemsToSelectedHome == false {
                    Section {
                        Label(
                            "You have read-only access to this shared home.",
                            systemImage: "lock.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

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
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveItem() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedLocation == nil || !canAddItemsToSelectedHome)
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
            .alert("Camera Unavailable", isPresented: $cameraUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The camera is not available on this device.")
            }
            .alert("Cubby Pro Required", isPresented: $showingGateAlert) {
                Button("Upgrade") { presentUpgrade() }
                Button("Restore Purchases") {
                    Task { await proAccessManager.restorePurchases() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(gateAlertMessage)
            }
            .onAppear {
                selectedLocation = preselectedLocation
                applyPreferredLocationIfNeeded()
            }
            .task {
                try? await Task.sleep(nanoseconds: 150_000_000)
                await MainActor.run { titleIsFocused = true }
            }
            .disabled(isSaving || !canAddItemsToSelectedHome)
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
        if selectedLocation == nil {
            selectedLocation = appStore.preferredLocation(for: selectedHomeId)
        }
    }

    private func saveItem() async {
        guard canAddItemsToSelectedHome else { return }

        let gate = appStore.canCreateItem(homeID: selectedHomeId, isPro: proAccessManager.isPro)
        guard gate.isAllowed else {
            gatePaywallReason = gate.reason == .overLimit ? .overLimit : .itemLimitReached
            showingGateAlert = true
            return
        }

        guard let selectedLocation else { return }
        isSaving = true

        do {
            _ = try await appStore.createItem(
                title: title.titleCased(),
                itemDescription: itemDescription.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                storageLocationID: selectedLocation.id,
                tags: tags,
                selectedImage: selectedImage
            )
            dismiss()
        } catch {
            DebugLogger.error("Failed to save item: \(error)")
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
            existingTags: appStore.allKnownTags()
        )
    }

    private var canAddItemsToSelectedHome: Bool {
        guard sharedHomesGateService.isEnabled() else { return true }
        guard let selectedHome else { return false }
        return selectedHome.permission.canAddItems
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
