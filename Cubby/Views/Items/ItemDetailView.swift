import SwiftUI
import SwiftData
import UIKit

struct ItemDetailView: View {
    let itemId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var undoManager = UndoManager.shared

    @State private var presentedSheet: PresentedSheet?
    @State private var showingDeleteConfirmation = false
    @State private var pendingMoveLocation: StorageLocation?
    @State private var pendingMoveHomeId: UUID?
    @State private var photo: UIImage?
    @State private var isPhotoLoading = false
    @State private var userFacingError: UserFacingError?

    @Query private var items: [InventoryItem]

    @ScaledMetric(relativeTo: .largeTitle) private var headerBadgeSize: CGFloat = 92
    @ScaledMetric(relativeTo: .largeTitle) private var headerEmojiSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title) private var photoCardHeight: CGFloat = 320

    init(itemId: UUID) {
        self.itemId = itemId
        _items = Query(filter: #Predicate<InventoryItem> { $0.id == itemId })
    }

    var body: some View {
        Group {
            if let item {
                ScrollView {
                    VStack(spacing: 24) {
                        ItemDetailHeader(
                            item: item,
                            badgeSize: headerBadgeSize,
                            emojiSize: headerEmojiSize
                        )

                        ItemDetailPhotoCard(
                            item: item,
                            photo: photo,
                            isLoading: isPhotoLoading,
                            height: photoCardHeight
                        )

                        if let descriptionText {
                            ItemDetailDescription(text: descriptionText)
                        }

                        if !item.tagsSet.isEmpty {
                            ItemDetailTags(tags: item.tagsSet)
                        }

                        ItemDetailMetadata(item: item)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .background(appBackground)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                beginMove()
                            } label: {
                                Label("Move Item", systemImage: "shippingbox")
                            }

                            Button {
                                presentedSheet = .edit
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(.rect)
                                .accessibilityLabel("More actions")
                                .accessibilityHint("Move, edit, or delete this item.")
                        }
                    }
                }
                .confirmationDialog(
                    "Delete Item?",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        deleteItem()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to delete “\(item.title)”? You can undo this for a limited time.")
                }
                .sheet(item: $presentedSheet) { sheet in
                    switch sheet {
                    case .move:
                        StorageLocationPicker(
                            selectedHomeId: pendingMoveHomeId,
                            selectedLocation: Binding(
                                get: { pendingMoveLocation },
                                set: { pendingMoveLocation = $0 }
                            ),
                            onDone: commitMoveIfNeeded
                        )
                    case .edit:
                        ItemEditView(itemId: itemId)
                    }
                }
                .task(id: item.photoFileName) {
                    await loadPhoto(fileName: item.photoFileName)
                }
                .alert(userFacingError?.title ?? "Error", isPresented: Binding(
                    get: { userFacingError != nil },
                    set: { isPresented in if !isPresented { userFacingError = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(userFacingError?.message ?? "")
                }
            } else {
                ContentUnavailableView(
                    "Item Unavailable",
                    systemImage: "questionmark.folder",
                    description: Text("This item may have been deleted.")
                )
                .padding()
                .background(appBackground)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    private var item: InventoryItem? { items.first }

    private var descriptionText: String? {
        guard let item else { return nil }
        guard let raw = item.itemDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw
    }

    private func beginMove() {
        guard let item else { return }
        pendingMoveLocation = item.storageLocation
        pendingMoveHomeId = item.storageLocation?.home?.id
        presentedSheet = .move
    }

    private func commitMoveIfNeeded() {
        guard let item else { return }
        guard let pendingMoveLocation else { return }
        guard pendingMoveLocation.id != item.storageLocation?.id else { return }

        item.storageLocation = pendingMoveLocation
        item.modifiedAt = Date()

        do {
            try modelContext.save()
        } catch {
            DebugLogger.error("ItemDetailView - Failed to move item: \(error)")
            userFacingError = .persistence(action: "move item", error: error)
        }
    }

    private func deleteItem() {
        guard let item else { return }
        undoManager.recordDeletion(item: item)
        modelContext.delete(item)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            DebugLogger.error("ItemDetailView - Failed to delete item: \(error)")
            userFacingError = .persistence(action: "delete item", error: error)
        }
    }

    private func loadPhoto(fileName: String?) async {
        guard let fileName else {
            await MainActor.run {
                photo = nil
                isPhotoLoading = false
            }
            return
        }

        await MainActor.run { isPhotoLoading = true }
        let loaded = await PhotoService.shared.loadPhoto(fileName: fileName)

        await MainActor.run {
            photo = loaded
            isPhotoLoading = false
        }

        if loaded == nil {
            DebugLogger.warning("ItemDetailView - Missing photo for fileName: \(fileName)")
        }
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

private enum PresentedSheet: Identifiable {
    case move
    case edit

    var id: Int {
        switch self {
        case .move: 1
        case .edit: 2
        }
    }
}

private struct ItemDetailHeader: View {
    let item: InventoryItem
    let badgeSize: CGFloat
    let emojiSize: CGFloat

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: badgeSize, height: badgeSize)
                SlotMachineEmojiView(item: item, fontSize: emojiSize)
            }

            Text(item.title)
                .font(CubbyTypography.itemTitleSerif)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var iconBackground: Color {
        if UIColor(named: "ItemIconBackground") != nil {
            return Color("ItemIconBackground")
        } else {
            return Color(.secondarySystemBackground)
        }
    }
}

private struct ItemDetailPhotoCard: View {
    let item: InventoryItem
    let photo: UIImage?
    let isLoading: Bool
    let height: CGFloat

    @ScaledMetric(relativeTo: .title) private var placeholderEmojiSize: CGFloat = 84

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.secondary.opacity(0.08))

            if item.photoFileName != nil {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else if isLoading {
                    ProgressView()
                } else {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(.rect(cornerRadius: 24))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)

            SlotMachineEmojiView(item: item, fontSize: placeholderEmojiSize)
        }
    }
}

private struct ItemDetailDescription: View {
    let text: String

    var body: some View {
        Text(text)
            .font(CubbyTypography.itemDescription)
            .foregroundStyle(Color.primary.opacity(0.9))
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ItemDetailTags: View {
    let tags: Set<String>

    var body: some View {
        TagDisplayView(tags: tags, onDelete: nil)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ItemDetailMetadata: View {
    let item: InventoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "shippingbox")
                    .foregroundStyle(.tint)

                Text(locationText)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Text("Last updated on \(lastUpdatedDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var locationText: String {
        guard let location = item.storageLocation else { return "Unknown Location" }
        return location.breadcrumbLeafToRoot()
    }

    private var lastUpdatedDate: Date {
        max(item.createdAt, item.modifiedAt)
    }
}

#Preview("Item Detail") {
    let schema = Schema([Home.self, StorageLocation.self, InventoryItem.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let ctx = container.mainContext

    let home = Home(name: "Hayes Valley")
    ctx.insert(home)
    let closet = StorageLocation(name: "Closet", home: home)
    ctx.insert(closet)
    let topShelf = StorageLocation(name: "Top Shelf", home: home, parentLocation: closet)
    ctx.insert(topShelf)

    let item = InventoryItem(
        title: "Vintage Film Camera",
        description: "On a high shelf, hidden behind other books",
        storageLocation: topShelf
    )
    item.tagsSet = ["electronics", "important", "photo"]
    ctx.insert(item)

    return NavigationStack {
        ItemDetailView(itemId: item.id)
    }
    .modelContainer(container)
}
