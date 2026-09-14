import AppIntents
import Foundation

/// A deterministic answer about saved data, independent of Siri's generative reasoning.
struct LocateInventoryItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Item Location"
    static let description = IntentDescription("Find where a saved Cubby item is stored.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Item") var item: InventoryItemEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Find where \(\.$item) is stored")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        // Entity parameters may contain old indexed values. Resolve again before answering.
        let currentItem = try await SiriInventoryService.shared.locateItem(id: item.id)
        let spokenPath = currentItem.fullPath.replacingOccurrences(of: " > ", with: ", ")
        return .result(
            value: currentItem.fullPath,
            dialog: "\(currentItem.title) is stored in \(spokenPath)."
        )
    }
}

/// Explicit shortcut navigation on iOS 26; the iOS 27 system schema has the sole OpenIntent.
struct OpenInventoryItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Inventory Item"
    static let description = IntentDescription("Open a saved item's details in Cubby.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Item") var item: InventoryItemEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$item)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await SiriInventoryService.shared.openItem(id: item.id)
        return .result()
    }
}

struct SearchInventoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Inventory"
    static let description = IntentDescription("Search saved item names, descriptions, and tags in Cubby.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Search") var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search inventory for \(\.$query)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await SiriInventoryService.shared.search(query: query)
        return .result()
    }
}

struct CubbyAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LocateInventoryItemIntent(),
            phrases: [
                "Find an item in \(.applicationName)",
                "Where is \(\.$item) in \(.applicationName)",
                "Locate \(\.$item) in \(.applicationName)"
            ],
            shortTitle: "Find Item Location",
            systemImageName: "shippingbox"
        )
        AppShortcut(
            intent: OpenInventoryItemIntent(),
            phrases: [
                "Open an item in \(.applicationName)",
                "Open \(\.$item) in \(.applicationName)"
            ],
            shortTitle: "Open Item",
            systemImageName: "shippingbox"
        )
        AppShortcut(
            intent: SearchInventoryIntent(),
            phrases: ["Search my inventory in \(.applicationName)"],
            shortTitle: "Search Inventory",
            systemImageName: "magnifyingglass"
        )
    }
}
