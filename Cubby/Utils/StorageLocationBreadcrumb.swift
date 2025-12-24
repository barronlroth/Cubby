import Foundation

extension StorageLocation {
    var breadcrumbComponentsLeafToRoot: [String] {
        var components: [String] = []
        var current: StorageLocation? = self

        while let location = current {
            components.append(location.name)
            current = location.parentLocation
        }

        return components
    }

    func breadcrumbLeafToRoot(separator: String = " → ") -> String {
        breadcrumbComponentsLeafToRoot.joined(separator: separator)
    }
}

