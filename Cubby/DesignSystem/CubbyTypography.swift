import SwiftUI

extension CubbyDesign {
    enum Typography {
        // MARK: Brand display

        static let displayLarge = brandSerif(size: 50, relativeTo: .largeTitle)
        static let display = brandSerif(size: 40, relativeTo: .largeTitle)
        static let title = brandSerif(size: 36, relativeTo: .largeTitle)
        static let navigationTitle = brandSerif(size: 20, relativeTo: .title3)

        // MARK: Content

        static let bodyLarge = brandSansBook(size: 20, relativeTo: .body)
        static let body = brandSansBook(size: 17, relativeTo: .body)
        static let bodyEmphasized = brandSansMedium(size: 17, relativeTo: .body)
        static let bodyCompactEmphasized = brandSansMedium(size: 16, relativeTo: .body)
        static let bodySmallEmphasized = brandSansMedium(size: 15, relativeTo: .body)
        static let bodySmall = brandSansBook(size: 14, relativeTo: .body)
        static let sectionTitle = brandSansMedium(size: 20, relativeTo: .title3)
        static let path = brandSansMediumItalic(size: 14, relativeTo: .subheadline)

        // MARK: Supporting text

        static let caption = brandSansBook(size: 13, relativeTo: .footnote)
        static let captionEmphasized = brandSansMedium(size: 13, relativeTo: .footnote)
        static let label = brandSansMedium(size: 12, relativeTo: .caption)
        static let captionSmall = brandSansBook(size: 12, relativeTo: .caption)
        static let finePrint = brandSansBook(size: 11, relativeTo: .caption2)
        static let finePrintEmphasized = brandSansMedium(size: 11, relativeTo: .caption2)
        static let callToAction = brandSansMedium(size: 17, relativeTo: .headline)

        private enum FontName {
            static let serif = "AwesomeSerif-ExtraTall"
            static let sansBook = "CircularStd-Book"
            static let sansMedium = "CircularStd-Medium"
            static let sansMediumItalic = "CircularStd-MediumItalic"
        }

        private static func brandSerif(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
            .custom(FontName.serif, size: size, relativeTo: textStyle)
        }

        private static func brandSansBook(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
            .custom(FontName.sansBook, size: size, relativeTo: textStyle)
        }

        private static func brandSansMedium(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
            .custom(FontName.sansMedium, size: size, relativeTo: textStyle)
        }

        private static func brandSansMediumItalic(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
            .custom(FontName.sansMediumItalic, size: size, relativeTo: textStyle)
        }
    }
}
