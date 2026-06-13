import SwiftUI

struct LocationSectionHeader: View {
    let locationPath: String
    let itemCount: Int
    var isCollapsed = false
    var allowsCollapse = true
    var onCollapse: () -> Void = {}
    var onExpand: () -> Void = {}
    
    private var segments: [String] {
        // Support both " > " and ">" separators
        if locationPath.contains(" > ") || locationPath.contains(">") {
            return locationPath
                .split(separator: ">")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
        } else {
            return [locationPath]
        }
    }

    private var title: String {
        segments.last ?? locationPath
    }

    private var itemCountText: String {
        itemCount == 1 ? "1 item" : "\(itemCount) items"
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            titleBlock
                .layoutPriority(1)

            Spacer(minLength: 8)

            Text(itemCountText)
                .font(.custom("CircularStd-Medium", size: 13, relativeTo: .caption))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.12), in: Capsule())
                .accessibilityIdentifier("location-section-count-\(locationPath)")

            if allowsCollapse {
                Button {
                    if isCollapsed {
                        onExpand()
                    } else {
                        onCollapse()
                    }
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right.circle.fill" : "chevron.down.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isCollapsed ? Color.accentColor : Color.primary.opacity(0.35))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isCollapsed ? "Expand \(title)" : "Collapse \(title)")
                .accessibilityValue(itemCountText)
                .accessibilityHint(isCollapsed ? "Shows the hidden items in this location." : "Hides the items in this location.")
                .accessibilityIdentifier("location-section-toggle-\(locationPath)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("CircularStd-Medium", size: 20))
                .foregroundStyle(Color.primary.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("location-section-title-\(locationPath)")

            if segments.count > 1 {
                let ancestors = Array(segments.dropLast().reversed())
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .renderingMode(.template)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.4))
                    ForEach(Array(ancestors.enumerated()), id: \.0) { index, segment in
                        Text(segment)
                            .font(.custom("CircularStd-MediumItalic", size: 14))
                            .foregroundStyle(Color.primary.opacity(0.4))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        if index < ancestors.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.primary.opacity(0.4))
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.45) {
            guard allowsCollapse, !isCollapsed else { return }
            onCollapse()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("\(title), \(itemCountText)")
        .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
        .accessibilityHint(headerAccessibilityHint)
        .accessibilityAction(named: isCollapsed ? "Expand section" : "Collapse section") {
            guard allowsCollapse else { return }
            if isCollapsed {
                onExpand()
            } else {
                onCollapse()
            }
        }
    }

    private var headerAccessibilityHint: String {
        guard allowsCollapse else { return "" }
        return isCollapsed
            ? "Use Expand to show items in this storage location."
            : "Long press to collapse this storage location."
    }
}
