import SwiftUI

/// The card Siri and Shortcuts show with a "where is" answer.
/// It receives a freshly resolved record, never stale indexed values.
struct InventoryItemSnippetView: View {
    let record: SiriInventoryRecord

    var body: some View {
        HStack(spacing: CubbyDesign.Spacing.medium) {
            Text(InventoryItemEmojiImage.emoji(record.emoji, for: record.id))
                .font(.title)
                .frame(width: CubbyDesign.Layout.rowIcon, height: CubbyDesign.Layout.rowIcon)
                .background(CubbyDesign.Palette.itemIconBackground, in: .rect(cornerRadius: CubbyDesign.Radius.medium))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: CubbyDesign.Spacing.xSmall) {
                Text(record.title)
                    .font(CubbyDesign.Typography.bodyEmphasized)
                    .foregroundStyle(.primary)
                Text(record.homeName)
                    .font(CubbyDesign.Typography.path)
                    .foregroundStyle(.secondary)
                if !record.locationPath.isEmpty {
                    Label(record.locationPath, systemImage: "mappin.and.ellipse")
                        .font(CubbyDesign.Typography.path)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}
