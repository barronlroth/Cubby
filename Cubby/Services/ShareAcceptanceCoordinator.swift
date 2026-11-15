import CloudKit
import Foundation

/// Tracks accepting a share invitation so the UI can show progress, surface
/// errors and select the new home once CloudKit imports it. Used for warm and
/// cold launches and the DEBUG "Join from link" field.
@MainActor
final class ShareAcceptanceCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        /// Accepting the invitation with CloudKit.
        case joining(title: String?)
        /// Accepted; waiting for the shared home to import.
        case waitingForImport(title: String?)
        case failed(message: String)
    }

    static let shared = ShareAcceptanceCoordinator()

    @Published private(set) var state: State = .idle

    /// Supplies the home ids present before accepting, to recognize the new one.
    var knownHomeIDs: () -> Set<UUID> = { [] }

    private var homeIDsBeforeAccept = Set<UUID>()
    private var importTimeoutTask: Task<Void, Never>?
    private let importTimeout: Duration

    init(importTimeout: Duration = .seconds(120)) {
        self.importTimeout = importTimeout
    }

    var isBusy: Bool {
        switch state {
        case .joining, .waitingForImport: true
        case .idle, .failed: false
        }
    }

    func accept(
        _ metadata: CKShare.Metadata,
        using service: (any HomeSharingServiceProtocol)?,
        errorHandler: (any SharingErrorHandlerProtocol)?
    ) async {
        let title = metadata.share[CKShare.SystemFieldKey.title] as? String
        await accept(title: title, using: service, errorHandler: errorHandler) { service in
            try await service.acceptShareInvitation(from: metadata)
        }
    }

    /// Shared by real metadata and tests, which cannot construct `CKShare.Metadata`.
    func accept(
        title: String?,
        using service: (any HomeSharingServiceProtocol)?,
        errorHandler: (any SharingErrorHandlerProtocol)?,
        perform: (any HomeSharingServiceProtocol) async throws -> Void
    ) async {
        guard let service else {
            DebugLogger.warning("Received a share invitation, but sharing is not configured.")
            state = .failed(message: "Shared homes aren't available right now.")
            return
        }

        homeIDsBeforeAccept = knownHomeIDs()
        state = .joining(title: title)
        DebugLogger.info("Accepting share invitation \(title ?? "(untitled)")")
        do {
            try await perform(service)
            DebugLogger.success("Accepted share invitation; waiting for import")
            state = .waitingForImport(title: title)
            scheduleImportTimeout()
        } catch {
            let message = errorHandler?.handleShareAcceptanceFailure(error).message
                ?? SharingErrorHandler().handleShareAcceptanceFailure(error).message
            DebugLogger.error("Failed to accept share invitation: \(error). Message: \(message)")
            state = .failed(message: message)
        }
    }

    /// Call when the visible homes change. Returns the newly imported shared
    /// home to select, once, after an accepted invitation.
    func homesDidChange(_ homes: [AppHome]) -> UUID? {
        guard case .waitingForImport = state else { return nil }
        let newHomes = homes.filter { !homeIDsBeforeAccept.contains($0.id) }
        guard let joined = newHomes.first(where: { !$0.isOwnedByCurrentUser }) ?? newHomes.first else {
            return nil
        }
        importTimeoutTask?.cancel()
        state = .idle
        return joined.id
    }

    func dismissFailure() {
        if case .failed = state {
            state = .idle
        }
    }

    private func scheduleImportTimeout() {
        importTimeoutTask?.cancel()
        let timeout = importTimeout
        importTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled, let self, case .waitingForImport = self.state else { return }
            DebugLogger.warning("Accepted share has not imported yet; it will appear after the next sync.")
            self.state = .idle
        }
    }
}
