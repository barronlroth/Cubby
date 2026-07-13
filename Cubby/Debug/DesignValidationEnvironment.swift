#if DEBUG
import SwiftUI

struct DesignValidationProfile {
    static let darkModeArgument = "DESIGN_COLOR_SCHEME_DARK"
    static let accessibilityTextArgument = "DESIGN_DYNAMIC_TYPE_ACCESSIBILITY_3"
    static let reduceMotionArgument = "DESIGN_REDUCE_MOTION"

    let traits: DesignPreviewTraits

    static func resolve(arguments: [String]) -> DesignValidationProfile {
        DesignValidationProfile(
            traits: DesignPreviewTraits(
                colorScheme: arguments.contains(darkModeArgument) ? .dark : nil,
                dynamicTypeSize: arguments.contains(accessibilityTextArgument) ? .accessibility3 : nil,
                reduceMotion: arguments.contains(reduceMotionArgument) ? true : nil
            )
        )
    }
}

struct DesignValidationEnvironmentModifier: ViewModifier {
    let traits: DesignPreviewTraits

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(traits.colorScheme)
            .modifier(DesignDynamicTypeModifier(size: traits.dynamicTypeSize))
            .environment(\.cubbyReduceMotionValidationOverride, traits.reduceMotion)
    }
}

private struct DesignDynamicTypeModifier: ViewModifier {
    let size: DynamicTypeSize?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let size {
            content.dynamicTypeSize(size)
        } else {
            content
        }
    }
}

#endif
