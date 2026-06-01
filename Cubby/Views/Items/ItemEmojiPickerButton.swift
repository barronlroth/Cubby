import MCEmojiPicker
import SwiftUI
import UIKit

struct ItemEmojiPickerButton: View {
    @Binding var selectedEmoji: String?
    let fallbackEmoji: String
    let isPendingAiEmoji: Bool
    var onBeginEditing: () -> Void = {}

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
        Button(action: presentPicker) {
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
        .overlay {
            ItemMCEmojiPickerController(
                isPresented: $isPickerPresented,
                selectedEmoji: emojiBinding,
                arrowDirection: .up,
                customHeight: 360,
                isDismissAfterChoosing: true,
                selectedEmojiCategoryTintColor: .systemBlue,
                feedBackGeneratorStyle: .light
            )
            .allowsHitTesting(false)
        }
        .accessibilityLabel("Item emoji")
        .accessibilityValue(displayEmoji)
        .accessibilityHint("Opens emoji picker.")
    }

    private func presentPicker() {
        guard !isPickerPresented else { return }

        onBeginEditing()
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isPickerPresented = true
        }
    }
}

private struct ItemMCEmojiPickerController: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var selectedEmoji: String

    let arrowDirection: MCPickerArrowDirection
    let customHeight: CGFloat
    let isDismissAfterChoosing: Bool
    let selectedEmojiCategoryTintColor: UIColor
    let feedBackGeneratorStyle: UIImpactFeedbackGenerator.FeedbackStyle?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ representableController: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard !context.coordinator.isNewEmojiSet else {
            context.coordinator.isNewEmojiSet.toggle()
            return
        }

        switch isPresented {
        case true:
            if representableController.presentedViewController is MCEmojiPickerViewController {
                return
            }

            let emojiPicker = MCEmojiPickerViewController()
            emojiPicker.delegate = context.coordinator
            emojiPicker.sourceView = representableController.view
            emojiPicker.arrowDirection = arrowDirection
            emojiPicker.customHeight = customHeight
            emojiPicker.isDismissAfterChoosing = isDismissAfterChoosing
            emojiPicker.selectedEmojiCategoryTintColor = selectedEmojiCategoryTintColor
            emojiPicker.feedBackGeneratorStyle = feedBackGeneratorStyle

            context.coordinator.addPickerDismissingObserver()
            representableController.present(emojiPicker, animated: true)
        case false:
            if representableController.presentedViewController is MCEmojiPickerViewController,
               context.coordinator.isPresented {
                representableController.presentedViewController?.dismiss(animated: true)
            }
        }

        context.coordinator.isPresented = isPresented
    }

    final class Coordinator: NSObject, MCEmojiPickerDelegate {
        var parent: ItemMCEmojiPickerController
        var isNewEmojiSet = false
        var isPresented = false

        init(_ parent: ItemMCEmojiPickerController) {
            self.parent = parent
        }

        func addPickerDismissingObserver() {
            NotificationCenter.default.removeObserver(
                self,
                name: Self.pickerDidDisappearNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pickerDismissingAction),
                name: Self.pickerDidDisappearNotification,
                object: nil
            )
        }

        func didGetEmoji(emoji: String) {
            isNewEmojiSet.toggle()
            parent.selectedEmoji = emoji
        }

        @objc private func pickerDismissingAction() {
            NotificationCenter.default.removeObserver(
                self,
                name: Self.pickerDidDisappearNotification,
                object: nil
            )
            parent.isPresented = false
        }

        private static let pickerDidDisappearNotification = Notification.Name("MCEmojiPickerDidDisappear")
    }
}
