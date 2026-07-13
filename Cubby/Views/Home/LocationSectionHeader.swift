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

            if isCollapsed {
                Text(itemCountText)
                    .font(CubbyDesign.Typography.captionEmphasized)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .accessibilityIdentifier("location-section-count-\(locationPath)")
            }

            if allowsCollapse, isCollapsed {
                Button {
                    onExpand()
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Expand \(title)")
                .accessibilityValue(itemCountText)
                .accessibilityHint("Shows the hidden items in this location.")
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
        interactiveTitleContent
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

    @ViewBuilder
    private var interactiveTitleContent: some View {
        if allowsCollapse, isCollapsed {
            titleContent
                .contentShape(Rectangle())
                .onTapGesture {
                    onExpand()
                }
        } else if allowsCollapse {
            titleContent
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.45) {
                    onCollapse()
                }
        } else {
            titleContent
        }
    }

    private var titleContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CubbyDesign.Typography.sectionTitle)
                .foregroundStyle(Color.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
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
                            .font(CubbyDesign.Typography.path)
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
    }

    private var headerAccessibilityHint: String {
        guard allowsCollapse else { return "" }
        return isCollapsed
            ? "Tap to show items in this storage location."
            : "Long press to collapse this storage location."
    }
}
