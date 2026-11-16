import SwiftUI

extension CubbyDesign {
    /// The one "opens something" chevron. Sized and tinted to match the system
    /// disclosure indicator that List draws for navigation rows, so custom rows
    /// (section headers, location cards) read the same as item rows.
    struct DisclosureIndicator: View {
        var body: some View {
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .accessibilityHidden(true)
        }
    }
}
