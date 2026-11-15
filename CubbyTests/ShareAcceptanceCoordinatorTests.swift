import CloudKit
import Foundation
import Testing
@testable import Cubby

@Suite("Share Acceptance Coordinator Tests")
@MainActor
struct ShareAcceptanceCoordinatorTests {
    private enum AcceptFailure: Error { case denied }

    private func home(_ name: String, owned: Bool) -> AppHome {
        AppHome(
            id: UUID(),
            name: name,
            createdAt: Date(),
            modifiedAt: Date(),
            isShared: !owned,
            isOwnedByCurrentUser: owned,
            permission: SharePermission(role: owned ? .owner : .readWriteParticipant),
            participantSummary: nil
        )
    }

    @Test("A successful accept shows joining, then selects the newly imported shared home once")
    func successSelectsNewHome() async {
        let coordinator = ShareAcceptanceCoordinator()
        let existing = home("Mine", owned: true)
        coordinator.knownHomeIDs = { [existing.id] }
        var observedJoining = false

        await coordinator.accept(
            title: "Beach House",
            using: DebugMockHomeSharingService(mode: .owner),
            errorHandler: nil
        ) { _ in
            observedJoining = coordinator.state == .joining(title: "Beach House")
        }

        #expect(observedJoining)
        #expect(coordinator.state == .waitingForImport(title: "Beach House"))
        #expect(coordinator.homesDidChange([existing]) == nil)

        let joined = home("Beach House", owned: false)
        #expect(coordinator.homesDidChange([existing, joined]) == joined.id)
        #expect(coordinator.state == .idle)
        #expect(coordinator.homesDidChange([existing, joined]) == nil)
    }

    @Test("A failed accept surfaces the sharing error copy and can be dismissed")
    func failureSurfacesMessage() async {
        let coordinator = ShareAcceptanceCoordinator()

        await coordinator.accept(
            title: nil,
            using: DebugMockHomeSharingService(mode: .owner),
            errorHandler: SharingErrorHandler(notificationCenter: NotificationCenter())
        ) { _ in
            throw CKError(.networkUnavailable)
        }

        #expect(coordinator.state == .failed(
            message: "You're offline. Check your internet connection and try again."
        ))
        coordinator.dismissFailure()
        #expect(coordinator.state == .idle)
    }

    @Test("Without a sharing service the accept fails instead of silently dropping the invitation")
    func missingServiceFails() async {
        let coordinator = ShareAcceptanceCoordinator()
        var performed = false

        await coordinator.accept(title: "X", using: nil, errorHandler: nil) { _ in
            performed = true
        }

        #expect(performed == false)
        if case .failed = coordinator.state {} else {
            Issue.record("Expected a failed state, got \(coordinator.state)")
        }
    }

    @Test("Waiting for import times out back to idle")
    func importTimeout() async throws {
        let coordinator = ShareAcceptanceCoordinator(importTimeout: .milliseconds(50))
        await coordinator.accept(
            title: nil,
            using: DebugMockHomeSharingService(mode: .owner),
            errorHandler: nil
        ) { _ in }

        for _ in 0..<50 where coordinator.state != .idle {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(coordinator.state == .idle)
    }
}

@Suite("CloudKit Event Log Tests")
@MainActor
struct CloudKitEventLogTests {
    private func entry(id: UUID = UUID(), finished: Bool, succeeded: Bool = true) -> CloudKitEventLog.Entry {
        CloudKitEventLog.Entry(
            id: id,
            kind: .export,
            store: "private",
            startDate: Date(),
            endDate: finished ? Date() : nil,
            succeeded: succeeded,
            errorDescription: succeeded ? nil : "boom"
        )
    }

    @Test("An event's end updates its start entry in place")
    func updatesInPlace() {
        let log = CloudKitEventLog(capacity: 10)
        let id = UUID()
        log.record(entry(id: id, finished: false))
        log.record(entry(id: id, finished: true, succeeded: false))

        #expect(log.entries.count == 1)
        #expect(log.entries.first?.isFinished == true)
        #expect(log.entries.first?.errorDescription == "boom")
    }

    @Test("The log keeps only the newest entries up to its capacity")
    func ringBuffer() {
        let log = CloudKitEventLog(capacity: 3)
        let ids = (0..<5).map { _ in UUID() }
        for id in ids {
            log.record(entry(id: id, finished: true))
        }

        #expect(log.entries.map(\.id) == Array(ids.suffix(3).reversed()))
    }
}
