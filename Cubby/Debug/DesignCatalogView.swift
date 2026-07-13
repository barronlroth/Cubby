#if DEBUG
import SwiftUI

@MainActor
struct DesignCatalogView: View {
    private let fixtureResult: Result<DesignPreviewFixture, Error>

    init() {
        fixtureResult = Result {
            try DesignPreviewFixture(
                scenario: .standard,
                proState: .free,
                sharing: .mixed
            )
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch fixtureResult {
                case .success(let fixture):
                    catalogList(fixture: fixture)
                case .failure(let error):
                    ContentUnavailableView(
                        "Design Catalog Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription)
                    )
                }
            }
            .navigationTitle("Design Catalog")
        }
    }

    private func catalogList(fixture: DesignPreviewFixture) -> some View {
        List {
            Section("Foundations") {
                NavigationLink("Colors & Type") {
                    DesignFoundationsCatalogView()
                }
            }

            Section("Components") {
                NavigationLink("Inventory & Locations") {
                    DesignComponentsCatalogView(fixture: fixture)
                }
            }

            Section("Screens & States") {
                ForEach(DesignCatalogScreen.allCases) { screen in
                    NavigationLink(screen.title) {
                        DesignCatalogScreenView(screen: screen)
                    }
                }
            }
        }
    }
}

private struct DesignFoundationsCatalogView: View {
    var body: some View {
        List {
            Section("Color") {
                colorRow("Canvas", color: CubbyDesign.Palette.canvas)
                colorRow("Home Canvas", color: CubbyDesign.Palette.homeCanvas)
                colorRow("Item Icon Background", color: CubbyDesign.Palette.itemIconBackground)
                colorRow("Surface", color: CubbyDesign.Palette.surface)
                colorRow("Accent", color: CubbyDesign.Palette.accent)
            }

            Section("Typography") {
                Text("Display")
                    .font(CubbyDesign.Typography.display)
                Text("Section title")
                    .font(CubbyDesign.Typography.sectionTitle)
                Text("Body and metadata scale with Dynamic Type")
                    .font(CubbyDesign.Typography.body)
                Text("Supporting caption")
                    .font(CubbyDesign.Typography.caption)
            }

            Section("Shape & Spacing") {
                HStack(spacing: CubbyDesign.Spacing.standard) {
                    RoundedRectangle(cornerRadius: CubbyDesign.Radius.medium)
                        .fill(CubbyDesign.Palette.accent.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Capsule()
                        .fill(.secondary.opacity(0.18))
                        .frame(height: CubbyDesign.Spacing.xxLarge)
                }
                .padding(.vertical, CubbyDesign.Spacing.small)

                Text("4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 pt")
                    .font(CubbyDesign.Typography.caption)
                    .foregroundStyle(CubbyDesign.Palette.secondaryText)
            }
        }
        .navigationTitle("Foundations")
    }

    private func colorRow(_ name: String, color: Color) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: CubbyDesign.Radius.medium)
                .fill(color)
                .frame(width: 52, height: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: CubbyDesign.Radius.medium)
                        .stroke(
                            CubbyDesign.Palette.separator.opacity(0.35),
                            lineWidth: CubbyDesign.Stroke.hairline
                        )
                }
            Text(name)
        }
    }
}

private struct DesignComponentsCatalogView: View {
    let fixture: DesignPreviewFixture

    var body: some View {
        DesignPreviewHarness(fixture: fixture) { fixture in
            List {
                if let item = fixture.featuredItem {
                    Section("Item Row") {
                        ItemRow(item: item)
                    }
                }

                Section("Location Headers") {
                    LocationSectionHeader(
                        locationPath: "Master Bedroom > Walk-in Closet",
                        itemCount: 3
                    )
                    LocationSectionHeader(
                        locationPath: "Garage",
                        itemCount: 2,
                        isCollapsed: true
                    )
                }

                Section("Tags") {
                    TagDisplayView(
                        tags: ["travel", "winter", "documents"],
                        onDelete: nil
                    )
                }
            }
            .navigationTitle("Components")
        }
    }
}

private enum DesignCatalogScreen: String, CaseIterable, Identifiable {
    case onboarding
    case homeLoaded
    case homeEmpty
    case homeReadOnly
    case search
    case itemDetail
    case itemEditor
    case locationPicker
    case proStatusFree
    case proResolving
    case paywallLoading
    case paywallError
    case startupLoading
    case startupFailure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onboarding: "Onboarding"
        case .homeLoaded: "Home — Loaded"
        case .homeEmpty: "Home — Empty"
        case .homeReadOnly: "Home — Read Only"
        case .search: "Search"
        case .itemDetail: "Item Detail"
        case .itemEditor: "Item Editor"
        case .locationPicker: "Location Picker"
        case .proStatusFree: "Pro Status — Free"
        case .proResolving: "Pro Status — Resolving"
        case .paywallLoading: "Paywall — Loading"
        case .paywallError: "Paywall — Error"
        case .startupLoading: "Startup — Loading"
        case .startupFailure: "Startup — Failure"
        }
    }

    var fixtureConfiguration: (
        DesignFixtureScenario,
        DesignProAccessState,
        DesignFixtureSharing
    ) {
        switch self {
        case .onboarding:
            (.onboarding, .pro, .notShared)
        case .homeEmpty:
            (.emptyHome, .pro, .notShared)
        case .homeReadOnly:
            (.standard, .pro, .readOnly)
        case .proStatusFree:
            (.standard, .free, .notShared)
        case .proResolving, .paywallLoading:
            (.standard, .loadingOfferings, .notShared)
        case .paywallError:
            (.standard, .offeringsError("Couldn’t load purchase options. Please try again."), .notShared)
        default:
            (.standard, .pro, .notShared)
        }
    }
}

@MainActor
private struct DesignCatalogScreenView: View {
    let screen: DesignCatalogScreen
    private let fixtureResult: Result<DesignPreviewFixture, Error>

    init(screen: DesignCatalogScreen) {
        self.screen = screen
        let configuration = screen.fixtureConfiguration
        fixtureResult = Result {
            try DesignPreviewFixture(
                scenario: configuration.0,
                proState: configuration.1,
                sharing: configuration.2
            )
        }
    }

    var body: some View {
        switch fixtureResult {
        case .success(let fixture):
            DesignPreviewHarness(fixture: fixture) { fixture in
                screenContent(fixture: fixture)
            }
        case .failure(let error):
            ContentUnavailableView(
                "Fixture Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
        }
    }

    @ViewBuilder
    private func screenContent(fixture: DesignPreviewFixture) -> some View {
        switch screen {
        case .onboarding:
            OnboardingView()
        case .homeLoaded, .homeEmpty, .homeReadOnly:
            HomeSearchContainer(
                cloudKitSettings: .designPreview,
                sharedHomesGateService: fixture.sharedHomesGateService,
                homeSharingService: fixture.homeSharingService,
                proAccessManager: fixture.proAccessManager,
                initialSelectedHomeID: fixture.selectedHomeID
            )
        case .search:
            SearchView()
        case .itemDetail:
            NavigationStack {
                if let itemID = fixture.featuredItemID {
                    ItemDetailView(itemId: itemID)
                }
            }
        case .itemEditor:
            if let itemID = fixture.featuredItemID {
                ItemEditView(itemId: itemID)
            }
        case .locationPicker:
            DesignLocationPickerPreview(fixture: fixture)
        case .proStatusFree, .proResolving:
            ProStatusView()
        case .paywallLoading, .paywallError:
            ProPaywallSheetView(context: PaywallContext(reason: .manualUpgrade))
        case .startupLoading:
            RestoringExistingHomeView()
        case .startupFailure:
            RuntimeInitializationFailureView()
        }
    }
}

private struct DesignLocationPickerPreview: View {
    let fixture: DesignPreviewFixture
    @State private var selectedLocation: AppStorageLocation?

    var body: some View {
        StorageLocationPicker(
            selectedHomeId: fixture.selectedHomeID,
            selectedLocation: $selectedLocation
        )
    }
}
#endif
