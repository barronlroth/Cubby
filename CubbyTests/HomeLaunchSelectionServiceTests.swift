import Foundation
import Testing
@testable import Cubby

struct HomeLaunchSelectionServiceTests {
    @Test func testPreferredHomeUsesValidLastUsedHomeID() {
        let olderHome = makeHome(name: "Older", modifiedAt: Date(timeIntervalSince1970: 100))
        let newerHome = makeHome(name: "Newer", modifiedAt: Date(timeIntervalSince1970: 200))

        let preferredID = HomeLaunchSelectionService.preferredHomeID(
            lastUsedHomeId: olderHome.id.uuidString,
            homes: [olderHome, newerHome],
            locations: [],
            items: []
        )

        #expect(preferredID == olderHome.id)
    }

    @Test func testPreferredHomeFallsBackToMostRecentItemActivity() {
        let homeA = makeHome(name: "Alpha", modifiedAt: Date(timeIntervalSince1970: 100))
        let homeB = makeHome(name: "Beta", modifiedAt: Date(timeIntervalSince1970: 100))
        let recentItem = makeItem(
            title: "Recently Edited",
            modifiedAt: Date(timeIntervalSince1970: 500),
            homeID: homeB.id
        )

        let preferredHome = HomeLaunchSelectionService.preferredHome(
            homes: [homeA, homeB],
            locations: [],
            items: [recentItem]
        )

        #expect(preferredHome?.id == homeB.id)
    }

    @Test func testPreferredHomeFallsBackToStableNameSortWhenActivityMatches() {
        let date = Date(timeIntervalSince1970: 100)
        let beta = makeHome(name: "Beta", modifiedAt: date)
        let alpha = makeHome(name: "Alpha", modifiedAt: date)

        let preferredHome = HomeLaunchSelectionService.preferredHome(
            homes: [beta, alpha],
            locations: [],
            items: []
        )

        #expect(preferredHome?.id == alpha.id)
    }

    private func makeHome(
        id: UUID = UUID(),
        name: String,
        modifiedAt: Date
    ) -> AppHome {
        AppHome(
            id: id,
            name: name,
            createdAt: modifiedAt,
            modifiedAt: modifiedAt,
            isShared: false,
            isOwnedByCurrentUser: true,
            permission: SharePermission(role: .owner),
            participantSummary: nil
        )
    }

    private func makeItem(
        title: String,
        modifiedAt: Date,
        homeID: UUID
    ) -> AppInventoryItem {
        AppInventoryItem(
            id: UUID(),
            title: title,
            itemDescription: nil,
            photoFileName: nil,
            emoji: nil,
            isPendingAiEmoji: false,
            createdAt: modifiedAt,
            modifiedAt: modifiedAt,
            tags: [],
            homeID: homeID,
            homeName: nil,
            storageLocationID: nil,
            storageLocationName: nil,
            storageLocationPath: nil
        )
    }
}
