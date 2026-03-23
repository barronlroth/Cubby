import SwiftUI
import UIKit

struct EmojiSelectionView: View {
    private let title: String
    private let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EmojiSelectionViewModel
    @State private var selectedCategoryID: String
    @State private var selectionHaptics = UISelectionFeedbackGenerator()

    private let gridColumns = [GridItem(.adaptive(minimum: 50, maximum: 54), spacing: 8)]

    init(
        selectedEmoji: String?,
        title: String = "Choose Emoji",
        onSelect: @escaping (String) -> Void
    ) {
        self.title = title
        self.onSelect = onSelect
        _viewModel = State(initialValue: EmojiSelectionViewModel(selectedEmoji: selectedEmoji))
        _selectedCategoryID = State(initialValue: EmojiPicker.categories.first?.id ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EmojiCategoryTabStrip(
                            categories: EmojiPicker.categories,
                            selectedCategoryID: selectedCategoryID,
                            onTap: { category in
                                scrollToCategory(category, proxy: proxy)
                            }
                        )

                        if !viewModel.isSearching, !viewModel.recentEmojis.isEmpty {
                            EmojiRecentsSection(
                                recents: viewModel.recentEmojis,
                                columns: gridColumns,
                                selectedEmoji: viewModel.selectedEmoji,
                                onSelect: handleSelection
                            )
                        }

                        if viewModel.filteredCategories.isEmpty {
                            ContentUnavailableView(
                                "No Emojis Found",
                                systemImage: "face.dashed",
                                description: Text("Try a different search term.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 44)
                        } else {
                            ForEach(viewModel.filteredCategories) { category in
                                EmojiCategorySection(
                                    category: category,
                                    columns: gridColumns,
                                    selectedEmoji: viewModel.selectedEmoji,
                                    onSelect: handleSelection
                                )
                                .id(category.id)
                                .onAppear {
                                    guard !viewModel.isSearching else { return }
                                    if selectedCategoryID != category.id {
                                        selectedCategoryID = category.id
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .background(backgroundColor)
                .onAppear {
                    selectionHaptics.prepare()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search emojis"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    @Environment(\.colorScheme) private var colorScheme
    private var backgroundColor: Color {
        if colorScheme == .light, UIColor(named: "AppBackground") != nil {
            return Color("AppBackground")
        } else {
            return Color(.systemGroupedBackground)
        }
    }

    private func scrollToCategory(_ category: EmojiPicker.EmojiCategory, proxy: ScrollViewProxy) {
        selectedCategoryID = category.id
        if viewModel.isSearching {
            viewModel.searchText = ""
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            proxy.scrollTo(category.id, anchor: .top)
        }
    }

    private func handleSelection(_ emoji: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
            viewModel.select(emoji: emoji)
        }
        selectionHaptics.selectionChanged()
        selectionHaptics.prepare()
        onSelect(emoji)
        dismiss()
    }
}

private struct EmojiCategoryTabStrip: View {
    let categories: [EmojiPicker.EmojiCategory]
    let selectedCategoryID: String
    let onTap: (EmojiPicker.EmojiCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories) { category in
                    EmojiCategoryChip(
                        category: category,
                        isSelected: selectedCategoryID == category.id
                    ) {
                        onTap(category)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct EmojiCategoryChip: View {
    let category: EmojiPicker.EmojiCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                Image(systemName: category.systemImage)
                    .font(.callout.weight(.semibold))
                Text(category.title)
                    .font(.callout.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .background(chipBackground)
            .overlay(chipBorder)
            .clipShape(Capsule())
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var chipBackground: some View {
        if isSelected {
            Capsule()
                .fill(Color.accentColor.opacity(0.18))
        } else {
            Capsule()
                .fill(.thinMaterial)
        }
    }

    @ViewBuilder
    private var chipBorder: some View {
        Capsule()
            .strokeBorder(
                isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.18),
                lineWidth: 1
            )
    }
}

private struct EmojiRecentsSection: View {
    let recents: [String]
    let columns: [GridItem]
    let selectedEmoji: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recently Used", systemImage: "clock.arrow.circlepath")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(recents, id: \.self) { emoji in
                    EmojiSelectionCell(
                        emoji: emoji,
                        isSelected: selectedEmoji == emoji
                    ) {
                        onSelect(emoji)
                    }
                }
            }
        }
    }
}

private struct EmojiCategorySection: View {
    let category: EmojiPicker.EmojiCategory
    let columns: [GridItem]
    let selectedEmoji: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(category.title, systemImage: category.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(category.emojis) { option in
                    EmojiSelectionCell(
                        emoji: option.emoji,
                        isSelected: selectedEmoji == option.emoji
                    ) {
                        onSelect(option.emoji)
                    }
                }
            }
        }
    }
}

private struct EmojiSelectionCell: View {
    let emoji: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(emoji)
                .font(.system(size: 29))
                .frame(width: 44, height: 44)
                .background(cellBackground)
                .overlay(cellBorder)
                .clipShape(Circle())
                .scaleEffect(isSelected ? 1.12 : 1.0)
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.2) : .clear,
                    radius: 8,
                    x: 0,
                    y: 3
                )
                .animation(.spring(response: 0.26, dampingFraction: 0.74), value: isSelected)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(.rect)
        .accessibilityLabel("Emoji \(emoji)")
    }

    @ViewBuilder
    private var cellBackground: some View {
        if isSelected {
            Circle()
                .fill(Color.accentColor.opacity(0.18))
        } else {
            Circle()
                .fill(.thinMaterial)
        }
    }

    @ViewBuilder
    private var cellBorder: some View {
        Circle()
            .strokeBorder(
                isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.14),
                lineWidth: 1
            )
    }
}
