#if DEBUG
import SwiftUI

private extension DesignPreviewFixture {
    static func preview(
        scenario: DesignFixtureScenario = .standard,
        selection: DesignFixtureSelection = .primary,
        proState: DesignProAccessState = .pro,
        sharing: DesignFixtureSharing = .notShared
    ) -> DesignPreviewFixture {
        try! DesignPreviewFixture(
            scenario: scenario,
            selection: selection,
            proState: proState,
            sharing: sharing
        )
    }
}

private struct LocationPickerPreviewScreen: View {
    let fixture: DesignPreviewFixture
    @State private var selectedLocation: AppStorageLocation?

    var body: some View {
        StorageLocationPicker(
            selectedHomeId: fixture.selectedHomeID,
            selectedLocation: $selectedLocation
        )
    }
}

#Preview("Home — Loaded") {
    let fixture = DesignPreviewFixture.preview()
    DesignPreviewHarness(fixture: fixture) { fixture in
        HomeSearchContainer(
            cloudKitSettings: .designPreview,
            sharedHomesGateService: fixture.sharedHomesGateService,
            homeSharingService: fixture.homeSharingService,
            proAccessManager: fixture.proAccessManager,
            initialSelectedHomeID: fixture.selectedHomeID
        )
    }
}

#Preview("Home — Dark, Read Only") {
    let fixture = DesignPreviewFixture.preview(sharing: .readOnly)
    DesignPreviewHarness(fixture: fixture, traits: .dark) { fixture in
        HomeSearchContainer(
            cloudKitSettings: .designPreview,
            sharedHomesGateService: fixture.sharedHomesGateService,
            homeSharingService: fixture.homeSharingService,
            proAccessManager: fixture.proAccessManager,
            initialSelectedHomeID: fixture.selectedHomeID
        )
    }
}

#Preview("Home — Empty, Accessibility Text") {
    let fixture = DesignPreviewFixture.preview(scenario: .emptyHome)
    DesignPreviewHarness(fixture: fixture, traits: .accessibilityText) { fixture in
        HomeSearchContainer(
            cloudKitSettings: .designPreview,
            sharedHomesGateService: fixture.sharedHomesGateService,
            homeSharingService: fixture.homeSharingService,
            proAccessManager: fixture.proAccessManager,
            initialSelectedHomeID: fixture.selectedHomeID
        )
    }
}

#Preview("Onboarding") {
    let fixture = DesignPreviewFixture.preview(scenario: .onboarding)
    DesignPreviewHarness(fixture: fixture) { _ in
        OnboardingView()
    }
}

#Preview("Search") {
    let fixture = DesignPreviewFixture.preview()
    DesignPreviewHarness(fixture: fixture) { _ in
        SearchView()
    }
}

#Preview("Item Detail") {
    let fixture = DesignPreviewFixture.preview()
    DesignPreviewHarness(fixture: fixture) { fixture in
        NavigationStack {
            ItemDetailView(itemId: fixture.featuredItemID!)
        }
    }
}

#Preview("Item Detail — Missing Photo") {
    let fixture = DesignPreviewFixture.preview(scenario: .missingLocalPhoto)
    DesignPreviewHarness(fixture: fixture) { fixture in
        NavigationStack {
            ItemDetailView(itemId: fixture.featuredItemID!)
        }
    }
}

#Preview("Item Editor") {
    let fixture = DesignPreviewFixture.preview()
    DesignPreviewHarness(fixture: fixture) { fixture in
        ItemEditView(itemId: fixture.featuredItemID!)
    }
}

#Preview("Location Picker") {
    let fixture = DesignPreviewFixture.preview()
    DesignPreviewHarness(fixture: fixture) { fixture in
        LocationPickerPreviewScreen(fixture: fixture)
    }
}

#Preview("Paywall — Loading") {
    let fixture = DesignPreviewFixture.preview(proState: .loadingOfferings)
    DesignPreviewHarness(fixture: fixture) { _ in
        ProPaywallSheetView(context: PaywallContext(reason: .manualUpgrade))
    }
}

#Preview("Paywall — Error") {
    let fixture = DesignPreviewFixture.preview(
        proState: .offeringsError("Couldn’t load purchase options. Please try again.")
    )
    DesignPreviewHarness(fixture: fixture) { _ in
        ProPaywallSheetView(context: PaywallContext(reason: .manualUpgrade))
    }
}

#Preview("Item Row") {
    let fixture = DesignPreviewFixture.preview()
    DesignPreviewHarness(fixture: fixture) { fixture in
        List {
            ItemRow(item: fixture.featuredItem!)
        }
    }
}

#Preview("Location Header — Collapsed") {
    LocationSectionHeader(
        locationPath: "Master Bedroom > Walk-in Closet",
        itemCount: 3,
        isCollapsed: true
    )
    .padding()
}

#Preview("Startup — Loading") {
    RestoringExistingHomeView()
}

#Preview("Startup — Error") {
    RuntimeInitializationFailureView()
}
#endif
