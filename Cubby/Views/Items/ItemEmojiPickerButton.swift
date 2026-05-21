import MCEmojiPicker
import SwiftUI

struct ItemEmojiPickerButton: View {
    @Binding var selectedEmoji: String?
    let fallbackEmoji: String
    let isPendingAiEmoji: Bool

    @State private var isPickerPresented = false

    private var displayEmoji: String {
        selectedEmoji ?? fallbackEmoji
    }

    private var emojiBinding: Binding<String> {
        Binding(
            get: { displayEmoji },
            set: { selectedEmoji = EmojiPicker.firstEmoji(in: $0) }
        )
    }

    var body: some View {
        Button {
            isPickerPresented = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 46, height: 46)

                Text(displayEmoji)
                    .font(.title2)
                    .frame(width: 46, height: 46)

                if isPendingAiEmoji && selectedEmoji == nil {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 14, height: 14)
                        .background(.thinMaterial, in: Circle())
                        .offset(x: 3, y: 3)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .emojiPicker(
            isPresented: $isPickerPresented,
            selectedEmoji: emojiBinding,
            arrowDirection: .up,
            customHeight: 360,
            isDismissAfterChoosing: true,
            selectedEmojiCategoryTintColor: .systemBlue,
            feedBackGeneratorStyle: .light
        )
        .accessibilityLabel("Item emoji")
        .accessibilityValue(displayEmoji)
        .accessibilityHint("Opens emoji picker.")
    }
}
