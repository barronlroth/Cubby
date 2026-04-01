import SwiftUI
import UIKit

struct ItemDetailView: View {
    let itemId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sharedHomesGateService) private var sharedHomesGateService
    @EnvironmentObject private var appStore: AppStore
    @StateObject private var undoManager = UndoManager.shared

    @State private var presentedSheet: PresentedSheet?
    @State private var showingDeleteConfirmation = false
    @State private var pendingMoveLocation: AppStorageLocation?
    @State private var pendingMoveHomeId: UUID?
    @State private var photo: UIImage?
    @State private var isPhotoLoading = false
    @State private var userFacingError: UserFacingError?

    @ScaledMetric(relativeTo: .largeTitle) private var headerBadgeSize: CGFloat = 92
    @ScaledMetric(relativeTo: .largeTitle) private var headerEmojiSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title) private var photoCardHeight: CGFloat = 320

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

                        if item.photoFileName != nil {
                            ItemDetailPhotoCard(
                                item: item,
                                photo: photo,
                                photoState: photoState(for: item),
                                height: photoCardHeight
                            )
                        }

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
                    if canMutateItem {
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

    private var item: AppInventoryItem? {
        appStore.item(id: itemId)
    }

    private var home: AppHome? {
        appStore.home(id: item?.homeID)
    }

    private var canMutateItem: Bool {
        guard sharedHomesGateService.isEnabled() else { return true }
        guard let home else { return true }
        return home.permission.canEditItems
    }

    private var descriptionText: String? {
        guard let raw = item?.itemDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw
    }

    private func photoState(for item: AppInventoryItem) -> SyncedPhotoPresenceState {
        SyncedPhotoPresenceState.resolve(
            hasPhotoMetadata: item.photoFileName != nil,
            hasDisplayImage: photo != nil,
            isLoading: isPhotoLoading
        )
    }

    private func beginMove() {
        guard canMutateItem, let item else { return }
        pendingMoveLocation = appStore.location(id: item.storageLocationID)
        pendingMoveHomeId = item.homeID
        presentedSheet = .move
    }

    private func commitMoveIfNeeded() {
        guard canMutateItem,
              let item,
              let pendingMoveLocation,
              pendingMoveLocation.id != item.storageLocationID else {
            return
        }

        do {
            try appStore.moveItem(id: item.id, to: pendingMoveLocation.id)
        } catch {
            DebugLogger.error("ItemDetailView - Failed to move item: \(error)")
            userFacingError = .persistence(action: "move item", error: error)
        }
    }

    private func deleteItem() {
        guard canMutateItem, let item else { return }
        if let snapshot = appStore.deleteSnapshot(for: item.id) {
            undoManager.recordDeletion(snapshot: snapshot)
        }

        do {
            try appStore.deleteItem(id: item.id)
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
    let item: AppInventoryItem
    let badgeSize: CGFloat
    let emojiSize: CGFloat

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: badgeSize, height: badgeSize)
                SlotMachineEmojiView(
                    emoji: item.emoji,
                    isPendingAiEmoji: item.isPendingAiEmoji,
                    fallbackSeed: item.id,
                    fontSize: emojiSize
                )
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
    let item: AppInventoryItem
    let photo: UIImage?
    let photoState: SyncedPhotoPresenceState
    let height: CGFloat

    @ScaledMetric(relativeTo: .title) private var placeholderEmojiSize: CGFloat = 84

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.secondary.opacity(0.08))

            switch photoState {
            case .available:
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            case .loading:
                ProgressView()
            case .missingOnDevice:
                missingLocalPlaceholder
            case .noPhoto:
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

            SlotMachineEmojiView(
                emoji: item.emoji,
                isPendingAiEmoji: item.isPendingAiEmoji,
                fallbackSeed: item.id,
                fontSize: placeholderEmojiSize
            )
        }
    }

    private var missingLocalPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)

            VStack(spacing: 8) {
                Image(systemName: "icloud.slash")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(photoState.missingOnDeviceMessage ?? "Photo unavailable")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
        }
    }
}

private struct ItemDetailDescription: View {
    let text: String

    var body: some View {
        detailCard(title: "Description") {
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ItemDetailTags: View {
    let tags: Set<String>

    var body: some View {
        detailCard(title: "Tags") {
            FlexibleTagFlow(tags: tags.sorted())
        }
    }
}

private struct ItemDetailMetadata: View {
    let item: AppInventoryItem

    private var createdAtText: String {
        item.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    private var updatedAtText: String {
        item.modifiedAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        detailCard(title: "Details") {
            VStack(alignment: .leading, spacing: 14) {
                metadataRow(
                    systemImage: "location.fill",
                    title: "Location",
                    value: item.storageLocationPath ?? "Unknown"
                )

                if let homeName = item.homeName {
                    metadataRow(
                        systemImage: "house.fill",
                        title: "Home",
                        value: homeName
                    )
                }

                metadataRow(
                    systemImage: "calendar",
                    title: "Added",
                    value: createdAtText
                )

                metadataRow(
                    systemImage: "clock.arrow.circlepath",
                    title: "Updated",
                    value: updatedAtText
                )
            }
        }
    }

    private func metadataRow(systemImage: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
    }
}

private func detailCard<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 14) {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)

        content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemBackground))
    )
}

private struct FlexibleTagFlow: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
    }
}
