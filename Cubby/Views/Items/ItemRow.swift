import SwiftUI

struct ItemRow: View {
    let item: AppInventoryItem
    let showLocation: Bool
    /// Non-nil in Select mode: the row shows a checkmark circle and tapping toggles it.
    var isSelected: Bool?
    var onToggleSelection: (() -> Void)?
    var onMove: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledIconSize = CubbyDesign.Layout.rowIcon

    init(
        item: AppInventoryItem,
        showLocation: Bool = true,
        isSelected: Bool? = nil,
        onToggleSelection: (() -> Void)? = nil,
        onMove: (() -> Void)? = nil
    ) {
        self.item = item
        self.showLocation = showLocation
        self.isSelected = isSelected
        self.onToggleSelection = onToggleSelection
        self.onMove = onMove
    }

    private var iconSize: CGFloat {
        min(scaledIconSize, CubbyDesign.Layout.rowIconMaximum)
    }

    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        rowContainer
        .buttonStyle(.plain)
        .accessibilityActions {
            if let onMove {
                Button("Move to\u{2026}", action: onMove)
            }
        }
        .siriInventoryItem(item.id)
    }

    @ViewBuilder
    private var rowContainer: some View {
        if let isSelected {
            Button {
                onToggleSelection?()
            } label: {
                HStack(spacing: CubbyDesign.Spacing.medium) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? CubbyDesign.Palette.accent : Color(uiColor: .tertiaryLabel))
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                    rowContent
                }
            }
            .sensoryFeedback(.selection, trigger: isSelected)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            NavigationLink(destination: ItemDetailView(itemId: item.id)) {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        rowLayout {
            emojiIcon
            textContent
            if !isAccessibilitySize {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 10)
    }

    private var rowLayout: AnyLayout {
        isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CubbyDesign.Spacing.small))
            : AnyLayout(HStackLayout(spacing: CubbyDesign.Spacing.medium))
    }

    private var emojiIcon: some View {
        ZStack {
            Circle()
                .fill(CubbyDesign.Palette.itemIconBackground)
                .frame(width: iconSize, height: iconSize)
            SlotMachineEmojiView(
                emoji: item.emoji,
                isPendingAiEmoji: item.isPendingAiEmoji,
                fallbackSeed: item.id,
                fontSize: iconSize / 2
            )
        }
        .accessibilityHidden(true)
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(CubbyDesign.Typography.bodyCompactEmphasized)
                .foregroundStyle(Color.primary.opacity(0.9))
                .lineLimit(isAccessibilitySize ? nil : 1)

            if let description = item.itemDescription, !description.isEmpty {
                Text(description)
                    .font(CubbyDesign.Typography.captionSmall)
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .lineLimit(isAccessibilitySize ? 3 : 1)
                    .truncationMode(.tail)
            }

            if showLocation {
                Label {
                    Text(item.storageLocationPath ?? "Unknown")
                        .font(.caption)
                        .lineLimit(isAccessibilitySize ? nil : 1)
                        .truncationMode(.tail)
                } icon: {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                }
                .labelStyle(CompactLabelStyle())
                .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CubbyDesign.Spacing.xSmall) {
            configuration.icon
            configuration.title
        }
    }
}
