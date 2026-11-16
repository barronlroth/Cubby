import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// Declared as exported types in Info.plist; payloads stay inside Cubby's process.
    static let cubbyItemRef = UTType(exportedAs: "com.barronroth.cubby.item-ref")
    static let cubbyLocationRef = UTType(exportedAs: "com.barronroth.cubby.location-ref")
}

/// A drag payload that refers to an inventory item by ID.
struct ItemDragRef: Codable, Hashable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .cubbyItemRef)
            .visibility(.ownProcess)
    }
}

/// A drag payload that refers to a storage location by ID.
struct LocationDragRef: Codable, Hashable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .cubbyLocationRef)
            .visibility(.ownProcess)
    }
}
