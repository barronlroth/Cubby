import Foundation

enum SyncedPhotoPresenceState: Equatable {
    case noPhoto
    case loading
    case available
    case missingOnDevice

    static func resolve(
        hasPhotoMetadata: Bool,
        hasDisplayImage: Bool,
        isLoading: Bool
    ) -> SyncedPhotoPresenceState {
        if hasDisplayImage {
            return .available
        }

        if hasPhotoMetadata == false {
            return .noPhoto
        }

        if isLoading {
            return .loading
        }

        return .missingOnDevice
    }

    var missingOnDeviceMessage: String? {
        guard self == .missingOnDevice else { return nil }
        return "Photo not on this device yet"
    }
}
