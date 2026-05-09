import Foundation
import Testing
@testable import Cubby

@Suite("Main Navigation Selection Tests")
struct MainNavigationSelectionTests {
    @Test("Removing the selected home falls back to the first remaining home")
    func testSelectionFallsBackAfterSelectedHomeIsRemoved() {
        let removed = makeHome(name: "A Home")
        let fallback = makeHome(name: "B Home")

        let selection = MainNavigationView.selectionAfterRemovingHome(
            removed.id,
            currentSelection: removed,
            remainingHomes: [fallback]
        )

        #expect(selection == fallback)
    }

    @Test("Removing the last home clears the selected home")
    func testSelectionClearsAfterLastHomeIsRemoved() {
        let removed = makeHome(name: "Only Home")

        let selection = MainNavigationView.selectionAfterRemovingHome(
            removed.id,
            currentSelection: removed,
            remainingHomes: []
        )

        #expect(selection == nil)
    }

    private func makeHome(name: String) -> AppHome {
        AppHome(
            id: UUID(),
            name: name,
            createdAt: Date(),
            modifiedAt: Date(),
            isShared: false,
            isOwnedByCurrentUser: true,
            permission: SharePermission(role: .owner),
            participantSummary: nil
        )
    }
}
