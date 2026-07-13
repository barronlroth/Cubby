import SwiftUI

extension CubbyDesign {
    enum Motion {
        enum Token: Equatable {
            case quick
            case standard
            case emphasized
        }

        enum Resolution: Equatable {
            case immediate
            case animated(Token)
        }

        static func resolution(for token: Token, reduceMotion: Bool) -> Resolution {
            reduceMotion ? .immediate : .animated(token)
        }

        static func resolvedReduceMotion(
            systemValue: Bool,
            validationOverride: Bool?
        ) -> Bool {
            validationOverride ?? systemValue
        }

        static func allowsContinuousMotion(reduceMotion: Bool) -> Bool {
            !reduceMotion
        }

        static func animation(for token: Token, reduceMotion: Bool) -> Animation? {
            switch resolution(for: token, reduceMotion: reduceMotion) {
            case .immediate:
                nil
            case .animated(let resolvedToken):
                resolvedToken.animation
            }
        }
    }
}

extension EnvironmentValues {
    @Entry var cubbyReduceMotionValidationOverride: Bool?

    var cubbyReduceMotion: Bool {
        CubbyDesign.Motion.resolvedReduceMotion(
            systemValue: accessibilityReduceMotion,
            validationOverride: cubbyReduceMotionValidationOverride
        )
    }
}

extension View {
    /// Applies a Cubby motion token and automatically disables interpolation
    /// when the user has enabled Reduce Motion.
    func cubbyAnimation<Value: Equatable>(
        _ token: CubbyDesign.Motion.Token,
        value: Value
    ) -> some View {
        modifier(CubbyAnimationModifier(token: token, value: value))
    }
}

private extension CubbyDesign.Motion.Token {
    var animation: Animation {
        switch self {
        case .quick:
            .easeInOut(duration: 0.18)
        case .standard:
            .easeInOut(duration: 0.2)
        case .emphasized:
            .spring(response: 0.3, dampingFraction: 0.82)
        }
    }
}

private struct CubbyAnimationModifier<Value: Equatable>: ViewModifier {
    let token: CubbyDesign.Motion.Token
    let value: Value

    @Environment(\.cubbyReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(
            CubbyDesign.Motion.animation(for: token, reduceMotion: reduceMotion),
            value: value
        )
    }
}
