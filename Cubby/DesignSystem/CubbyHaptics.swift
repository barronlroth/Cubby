#if canImport(UIKit)
import UIKit
#endif

extension CubbyDesign {
    /// Restrained haptic vocabulary for Cubby.
    ///
    /// Prefer SwiftUI's `.sensoryFeedback(_:trigger:)` when the view that owns the
    /// trigger stays on screen. Use `Haptics.play(_:)` when the action also dismisses
    /// the view (saving a sheet, confirming a delete that pops the screen), because a
    /// trigger change on a disappearing view is not guaranteed to play.
    ///
    /// Do not add haptics to plain navigation, scrolling, or text entry.
    enum Haptics {
        enum Event: Equatable {
            /// An item, location, or home was created or saved, or an undo succeeded.
            case success
            /// A destructive action was confirmed.
            case warning
            /// A value was chosen from a set (location, tag).
            case selection
        }

        @MainActor
        static func play(_ event: Event) {
            #if canImport(UIKit) && !os(visionOS)
            switch event {
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .warning:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .selection:
                UISelectionFeedbackGenerator().selectionChanged()
            }
            #endif
        }
    }
}
