import SwiftUI

struct TagChip: View {
    let tag: String
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .padding(.leading, 8)
            
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(
                    minWidth: CubbyDesign.Layout.minimumTapTarget,
                    minHeight: CubbyDesign.Layout.minimumTapTarget
                )
                .contentShape(.rect)
                .accessibilityLabel("Remove \(tag)")
            }
        }
        .padding(.trailing, onDelete == nil ? 8 : 0)
        .padding(.vertical, onDelete == nil ? 4 : 0)
        .background(Color.secondary.opacity(0.2))
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        TagChip(tag: "home-office", onDelete: nil)
        TagChip(tag: "electronics", onDelete: {})
        TagChip(tag: "important", onDelete: {})
    }
    .padding()
}
