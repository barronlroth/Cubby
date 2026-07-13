import SwiftUI

struct TagDisplayView: View {
    let tags: Set<String>
    let onDelete: ((String) -> Void)?
    var body: some View {
        WrappingHStackLayout(spacing: CubbyDesign.Spacing.small) {
            ForEach(Array(tags).sorted(), id: \.self) { tag in
                TagChip(
                    tag: tag,
                    onDelete: onDelete != nil ? { onDelete?(tag) } : nil
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .cubbyAnimation(.emphasized, value: tags)
    }
}

#Preview {
    TagDisplayView(
        tags: ["home-office", "electronics", "important", "work", "personal"],
        onDelete: { _ in }
    )
    .padding()
}
