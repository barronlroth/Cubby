#if DEBUG
import Testing
@testable import Cubby

@Suite("Design preview fixtures")
@MainActor
struct DesignPreviewFixtureTests {
    @Test("Standard fixture uses stable production repository data")
    func standardFixture() throws {
        let fixture = try DesignPreviewFixture()
        let secondarySelection = try DesignPreviewFixture(selection: .secondary)

        #expect(fixture.appStore.homes.count == 2)
        #expect(fixture.appStore.locations.count == 5)
        #expect(fixture.appStore.items.count == 4)
        #expect(fixture.primaryHomeID == DesignFixtureIDs.primaryHome)
        #expect(fixture.featuredItemID == DesignFixtureIDs.featuredItem)
        #expect(fixture.featuredItem?.title == "Roof Cargo Box")
        #expect(secondarySelection.selectedHome?.name == "Beach House")
        #expect(fixture.repository.persistenceController === fixture.persistenceController)
    }

    @Test("Seed-semantic scenarios remain deterministic")
    func scenarioSemantics() throws {
        let freeTier = try DesignPreviewFixture(scenario: .freeTier, proState: .free)
        let limit = try DesignPreviewFixture(scenario: .itemLimitReached, proState: .free)
        let empty = try DesignPreviewFixture(scenario: .emptyHome)
        let missingPhoto = try DesignPreviewFixture(scenario: .missingLocalPhoto)

        #expect(freeTier.appStore.homes.map(\.name) == ["Reach"])
        #expect(freeTier.appStore.items.count == 9)
        #expect(limit.appStore.items.count == 10)
        #expect(empty.appStore.items.isEmpty)
        #expect(empty.appStore.locations.map(\.name) == ["Unsorted"])
        #expect(missingPhoto.featuredItem?.photoFileName == "missing-local-photo.jpg")
    }

    @Test("Sharing permission is reflected through repository mapping")
    func readOnlySharing() throws {
        let fixture = try DesignPreviewFixture(sharing: .readOnly)
        let home = try #require(fixture.selectedHome)

        #expect(home.isShared)
        #expect(home.permission.role == .readOnlyParticipant)
        #expect(home.permission.canMutate == false)
        #expect(try fixture.repository.ownerHomeCount() == 0)
    }

    @Test("Pro preview states do not configure RevenueCat")
    func proStates() throws {
        let pro = try DesignPreviewFixture(proState: .pro)
        let free = try DesignPreviewFixture(proState: .free)
        let resolving = try DesignPreviewFixture(proState: .resolving)
        let loading = try DesignPreviewFixture(proState: .loadingOfferings)
        let error = try DesignPreviewFixture(
            proState: .offeringsError("Fixture error")
        )

        #expect(pro.proAccessManager.isPro)
        #expect(free.proAccessManager.isPro == false)
        #expect(resolving.proAccessManager.isRefreshingCustomerInfo)
        #expect(loading.proAccessManager.isLoadingOfferings)
        #expect(error.proAccessManager.offeringsErrorMessage == "Fixture error")
        #expect(pro.proAccessManager.isRevenueCatConfigured == false)
    }
}
#endif
