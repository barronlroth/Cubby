import SwiftUI
import SwiftData
import UIKit

struct ItemEditView: View {
    let itemId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.homeSharingService) private var homeSharingService
    @Environment(\.sharedHomesGateService) private var sharedHomesGateService

    @State private var title = ""
    @State private var itemDescription = ""
    @State private var tags: Set<String> = []
    @State private var tagInput = ""

    @State private var existingPhoto: UIImage?
    @State private var selectedPhoto: UIImage?
    @State private var didRemovePhoto = false
    @State private var isExistingPhotoLoading = false

    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var cameraUnavailableAlert = false
    @State private var isSaving = false
    @State private var didLoadDraft = false
    @State private var userFacingError: UserFacingError?

    @Query private var items: [InventoryItem]
    @Query private var allItems: [InventoryItem]

    init(itemId: UUID) {
        self.itemId = itemId
        _items = Query(filter: #Predicate<InventoryItem> { $0.id == itemId })
    }

    var body: some View {
        NavigationStack {
            content
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(selectedImage: $selectedPhoto, sourceType: .camera)
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoLibraryPicker(selectedImage: $selectedPhoto)
        }
        .onChange(of: selectedPhoto) { _, newValue in
            if newValue != nil {
                didRemovePhoto = false
            }
        }
        .alert("Camera Unavailable", isPresented: $cameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The camera is not available on this device.")
        }
        .alert(userFacingError?.title ?? "Error", isPresented: Binding(
            get: { userFacingError != nil },
            set: { isPresented in if !isPresented { userFacingError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(userFacingError?.message ?? "")
        }
        .task {
            await loadDraftIfNeeded()
        }
    }

    private var item: InventoryItem? { items.first }

    @ViewBuilder
    private var content: some View {
        if let item {
            editForm(for: item)
        } else {
            missingItemView
        }
    }

    private func editForm(for item: InventoryItem) -> some View {
        Form {
            if canEditCurrentItem == false {
                Section {
                    Label(
                        "You have read-only access to this shared home.",
                        systemImage: "lock.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            titleSection
            descriptionSection
            photoSection
            tagsSection
        }
        .disabled(isSaving || !canEditCurrentItem)
        .overlay {
            if isSaving {
                ProgressView("Saving…")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(.rect(cornerRadius: 12))
            }
        }
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveEdits(for: item) }
                }
                .fontWeight(.semibold)
                .disabled(!canSave || !canEditCurrentItem)
            }
        }
    }

    private var missingItemView: some View {
        ContentUnavailableView(
            "Item Unavailable",
            systemImage: "questionmark.folder",
            description: Text("This item may have been deleted.")
        )
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var titleSection: some View {
        Section {
            TextField("Title", text: $title)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
        } header: {
            Text("Title")
        } footer: {
            if case let .failure(message) = titleValidation {
                Text(message)
                    .foregroundStyle(.red)
            }
        }
    }

    private var descriptionSection: some View {
        Section {
            TextField("Description", text: $itemDescription, axis: .vertical)
                .lineLimit(3...8)
                .textInputAutocapitalization(.sentences)
        } header: {
            Text("Description")
        } footer: {
            if case let .failure(message) = descriptionValidation {
                Text(message)
                    .foregroundStyle(.red)
            }
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            Menu {
                Button {
                    beginTakingPhoto()
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }

                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo")
                }

                if hasAnyPhoto {
                    Divider()
                    Button(role: .destructive) {
                        removePhoto()
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            } label: {
                PhotoPreview(
                    image: previewPhoto,
                    state: photoPreviewState
                )
            }
            .accessibilityLabel("Photo actions")
            .accessibilityHint("Change or remove the photo for this item.")
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            TagInputView(
                tags: $tags,
                currentInput: $tagInput,
                suggestions: tagSuggestions
            )
        }
    }

    private var titleValidation: ValidationResult {
        ValidationHelpers.validateItemTitle(title)
    }

    private var descriptionValidation: ValidationResult {
        let trimmed = itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return ValidationHelpers.validateItemDescription(trimmed.isEmpty ? nil : trimmed)
    }

    private var canSave: Bool {
        guard !isSaving else { return false }
        guard canEditCurrentItem else { return false }
        if case .failure = titleValidation { return false }
        if case .failure = descriptionValidation { return false }
        return item != nil
    }

    private var canEditCurrentItem: Bool {
        guard sharedHomesGateService.isEnabled() else { return true }
        guard let home = item?.storageLocation?.home else { return true }
        guard let homeSharingService else { return true }
        return homeSharingService.canEditItems(in: home)
    }

    private var previewPhoto: UIImage? {
        if let selectedPhoto { return selectedPhoto }
        if didRemovePhoto { return nil }
        return existingPhoto
    }

    private var hasAnyPhoto: Bool {
        previewPhoto != nil || item?.photoFileName != nil
    }

    private var photoPreviewState: SyncedPhotoPresenceState {
        SyncedPhotoPresenceState.resolve(
            hasPhotoMetadata: item?.photoFileName != nil && didRemovePhoto == false,
            hasDisplayImage: previewPhoto != nil,
            isLoading: isExistingPhotoLoading
        )
    }

    private func beginTakingPhoto() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showingCamera = true
        } else {
            cameraUnavailableAlert = true
        }
    }

    private func removePhoto() {
        selectedPhoto = nil
        existingPhoto = nil
        didRemovePhoto = true
    }

    private func loadDraftIfNeeded() async {
        guard !didLoadDraft, let item else { return }
        didLoadDraft = true

        title = item.title
        itemDescription = item.itemDescription ?? ""
        tags = item.tagsSet
        didRemovePhoto = false

        await loadExistingPhoto(fileName: item.photoFileName)
    }

    private func loadExistingPhoto(fileName: String?) async {
        guard let fileName else {
            await MainActor.run {
                existingPhoto = nil
                isExistingPhotoLoading = false
            }
            return
        }

        await MainActor.run {
            isExistingPhotoLoading = true
        }
        let loaded = await PhotoService.shared.loadPhoto(fileName: fileName)
        await MainActor.run {
            existingPhoto = loaded
            isExistingPhotoLoading = false
        }

        if loaded == nil {
            DebugLogger.warning("ItemEditView - Missing photo for fileName: \(fileName)")
        }
    }

    private func saveEdits(for item: InventoryItem) async {
        guard canEditCurrentItem else { return }
        guard canSave else { return }

        isSaving = true
        defer { isSaving = false }

        let oldPhotoFileName = item.photoFileName

        item.title = title.titleCased()
        let trimmedDescription = itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        item.itemDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        item.tagsSet = tags
        item.modifiedAt = Date()

        if let selectedPhoto {
            do {
                let newFileName = try await PhotoService.shared.savePhoto(selectedPhoto)
                item.photoFileName = newFileName

                do {
                    try modelContext.save()
                } catch {
                    item.photoFileName = oldPhotoFileName
                    await PhotoService.shared.deletePhoto(fileName: newFileName)
                    DebugLogger.error("ItemEditView - Failed to save item after photo replace: \(error)")
                    userFacingError = .persistence(action: "save item", error: error)
                    return
                }

                if let oldPhotoFileName, oldPhotoFileName != newFileName {
                    await PhotoService.shared.deletePhoto(fileName: oldPhotoFileName)
                }

                dismiss()
                return
            } catch {
                DebugLogger.error("ItemEditView - Failed to save new photo: \(error)")
                userFacingError = .persistence(action: "save photo", error: error)
                return
            }
        }

        if didRemovePhoto, let oldPhotoFileName {
            item.photoFileName = nil

            do {
                try modelContext.save()
                await PhotoService.shared.deletePhoto(fileName: oldPhotoFileName)
                dismiss()
            } catch {
                item.photoFileName = oldPhotoFileName
                DebugLogger.error("ItemEditView - Failed to save item after photo removal: \(error)")
                userFacingError = .persistence(action: "remove photo", error: error)
            }

            return
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            DebugLogger.error("ItemEditView - Failed to save item edits: \(error)")
            userFacingError = .persistence(action: "save item", error: error)
        }
    }

    private var tagSuggestions: [String] {
        TagSuggestionService.suggestions(
            for: tagInput,
            existingTags: allItems.flatMap(\.tags)
        )
    }
}

private struct PhotoPreview: View {
    let image: UIImage?
    let state: SyncedPhotoPresenceState

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: 12))
        } else {
            switch state {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading photo…")
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            case .missingOnDevice:
                VStack(spacing: 8) {
                    Label(
                        state.missingOnDeviceMessage ?? "Photo unavailable",
                        systemImage: "icloud.slash"
                    )
                    .font(.callout.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                    Text("Photo metadata synced, but image files stay local in this release.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 72)
                .accessibilityIdentifier("MissingLocalPhotoMessage")
            case .noPhoto, .available:
                Label("Add Photo", systemImage: "camera")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }
}

#Preview("Item Edit") {
    let schema = Schema([Home.self, StorageLocation.self, InventoryItem.self])
    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    let container = try! ModelContainer(for: schema, configurations: [config])
    let ctx = container.mainContext

    let home = Home(name: "Hayes Valley")
    ctx.insert(home)
    let desk = StorageLocation(name: "Desk", home: home)
    ctx.insert(desk)

    let item = InventoryItem(
        title: "Rare Book",
        description: "On a high shelf, hidden behind other books",
        storageLocation: desk
    )
    item.tagsSet = ["books", "office"]
    ctx.insert(item)

    return ItemEditView(itemId: item.id)
        .modelContainer(container)
}
