import SwiftUI

struct TagChip: View {
    let tag: String
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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