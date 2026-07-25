import CoreGraphics

extension CubbyDesign {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let standard: CGFloat = 16
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
        static let xxxLarge: CGFloat = 40
    }

    enum Layout {
        static let minimumTapTarget: CGFloat = 44
        static let compactIcon: CGFloat = 24
        static let rowIcon: CGFloat = 48
        static let readableContentMaximum: CGFloat = 720
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 18
        static let xLarge: CGFloat = 24
    }

    enum Stroke {
        static let hairline: CGFloat = 0.5
        static let standard: CGFloat = 1
        static let emphasized: CGFloat = 2
    }
}
