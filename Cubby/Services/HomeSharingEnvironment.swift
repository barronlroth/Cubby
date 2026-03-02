import SwiftUI

private struct HomeSharingServiceEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any HomeSharingServiceProtocol)? = nil
}

extension EnvironmentValues {
    var homeSharingService: (any HomeSharingServiceProtocol)? {
        get { self[HomeSharingServiceEnvironmentKey.self] }
        set { self[HomeSharingServiceEnvironmentKey.self] = newValue }
    }
}
