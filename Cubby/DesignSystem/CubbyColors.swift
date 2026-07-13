import SwiftUI
import UIKit

extension CubbyDesign {
    enum Palette {
        /// The warm app canvas used by forms, detail views, and onboarding.
        static let canvas = Color("AppBackground")

        /// The neutral canvas used by the primary inventory navigation.
        static let homeCanvas = Color("CubbyHomeBackground")

        /// The adaptive fill behind item emoji artwork.
        static let itemIconBackground = Color("ItemIconBackground")

        static let surface = Color(uiColor: .secondarySystemBackground)
        static let elevatedSurface = Color(uiColor: .tertiarySystemBackground)
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let separator = Color(uiColor: .separator)
        static let accent = Color.accentColor
        static let destructive = Color.red
    }
}
