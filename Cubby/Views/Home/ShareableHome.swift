import CloudKit
import CoreTransferable
import SwiftUI

/// A home handed to `ShareLink`. The system collaboration UI asks for the share
/// only when the user picks a destination, so nothing is created on tap.
struct ShareableHome: Transferable {
    let homeID: UUID
    let title: String
    let container: CKContainer
    /// The share that already exists, if the lookup found one.
    let existingShare: CKShare?
    /// Creates (or returns) the share. Runs on the main actor through AppStore.
    let prepare: @Sendable () async throws -> CKShare

    /// Owners choose who can join (anyone with the link, or invited people) and
    /// whether they can edit. Cubby never forces a public permission.
    static var allowedSharingOptions: CKAllowedSharingOptions {
        CKAllowedSharingOptions(
            allowedParticipantPermissionOptions: .any,
            allowedParticipantAccessOptions: .any
        )
    }

    static var transferRepresentation: some TransferRepresentation {
        CKShareTransferRepresentation { home in
            if let existingShare = home.existingShare {
                return .existing(
                    existingShare,
                    container: home.container,
                    allowedSharingOptions: allowedSharingOptions
                )
            }
            return .prepareShare(
                container: home.container,
                allowedSharingOptions: allowedSharingOptions
            ) {
                try await home.prepare()
            }
        }
    }
}
