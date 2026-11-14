import PhotosUI
import SwiftUI
import UIKit

extension PhotosPickerItem {
    /// Loads the picked photo as a `UIImage`, or `nil` if it can't be read.
    func loadUIImage() async -> UIImage? {
        guard let data = try? await loadTransferable(type: Data.self) else {
            return nil
        }
        return UIImage(data: data)
    }
}
