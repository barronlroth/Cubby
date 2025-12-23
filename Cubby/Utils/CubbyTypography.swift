import SwiftUI

enum CubbyTypography {
    static var homeTitleSerif: Font {
        Font.custom("AwesomeSerif-ExtraTall", size: 36, relativeTo: .largeTitle)
    }

    static var itemTitleSerif: Font { homeTitleSerif }

    static var itemDescription: Font {
        Font.custom("CircularStd-Book", size: 20, relativeTo: .body)
    }
}

