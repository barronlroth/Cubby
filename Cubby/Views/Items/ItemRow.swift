import SwiftUI
import UIKit
import SwiftData

struct ItemRow: View {
    let item: InventoryItem
    let showLocation: Bool

    init(item: InventoryItem, showLocation: Bool = true) {
        self.item = item
        self.showLocation = showLocation
    }
    
    var body: some View {
        NavigationLink(destination: ItemDetailView(itemId: item.id)) {
            HStack(spacing: 12) {
                // Emoji icon in 48x48 circle
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 48, height: 48)
                    SlotMachineEmojiView(item: item, fontSize: 24)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.custom("CircularStd-Medium", size: 16, relativeTo: .body))
                        .foregroundStyle(Color.primary.opacity(0.9))
                        .lineLimit(1)

                    if let description = item.itemDescription, !description.isEmpty {
                        Text(description)
                            .font(.custom("CircularStd-Book", size: 12, relativeTo: .caption))
                            .foregroundStyle(Color.primary.opacity(0.4))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    if showLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(item.storageLocation?.fullPath ?? "Unknown")
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var iconBackground: Color {
        if UIColor(named: "ItemIconBackground") != nil {
            return Color("ItemIconBackground")
        } else {
            return Color(.secondarySystemBackground)
        }
    }
}
