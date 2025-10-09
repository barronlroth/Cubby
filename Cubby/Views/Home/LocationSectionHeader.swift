import SwiftUI

struct LocationSectionHeader: View {
    let locationPath: String
    let itemCount: Int
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title (current/leaf location)
            Text(segments.last ?? locationPath)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            // Subtitle path (ancestors only)
            if segments.count > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .renderingMode(.template)
                        .foregroundStyle(.secondary)
                    Text(segments.dropLast().joined(separator: " → "))
                        .font(.system(size: 14, weight: .medium).italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

