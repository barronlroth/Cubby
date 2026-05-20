import SwiftUI

struct ItemEmojiPickerButton: View {
    @Binding var selectedEmoji: String?
    let fallbackEmoji: String
    let isPendingAiEmoji: Bool

    @State private var isPickerPresented = false

    private var displayEmoji: String {
        selectedEmoji ?? fallbackEmoji
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
        .accessibilityLabel("Item emoji")
        .accessibilityValue(displayEmoji)
        .accessibilityHint("Opens emoji picker.")
        .sheet(isPresented: $isPickerPresented) {
            ItemEmojiPickerSheet(
                selectedEmoji: $selectedEmoji,
                fallbackEmoji: fallbackEmoji
            )
            .presentationDetents([.medium, .large])
        }
    }
}

private struct ItemEmojiPickerSheet: View {
    @Binding var selectedEmoji: String?
    let fallbackEmoji: String

    @Environment(\.dismiss) private var dismiss
    @State private var customEmoji = ""

    private let columns = [
        GridItem(.adaptive(minimum: 48), spacing: 10)
    ]

    private var resolvedCustomEmoji: String? {
        EmojiPicker.firstEmoji(in: customEmoji)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        TextField("Type or paste emoji", text: $customEmoji)
                            .font(.title3)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.done)
                            .onSubmit(useCustomEmoji)

                        Button("Use", action: useCustomEmoji)
                            .disabled(resolvedCustomEmoji == nil)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(EmojiPicker.emojis.enumerated()), id: \.offset) { _, emoji in
                        Button {
                            selectedEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 48, height: 48)
                                .background(selectionBackground(for: emoji))
                                .clipShape(.rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Choose \(emoji)")
                    }
                }
                .padding(16)
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Automatic") {
                        selectedEmoji = nil
                        dismiss()
                    }
                    .accessibilityLabel("Use automatic emoji")
                }
            }
        }
    }

    private func useCustomEmoji() {
        guard let emoji = resolvedCustomEmoji else { return }
        selectedEmoji = emoji
        dismiss()
    }

    @ViewBuilder
    private func selectionBackground(for emoji: String) -> some View {
        if selectedEmoji == emoji || (selectedEmoji == nil && fallbackEmoji == emoji) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 1)
                }
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }
}
