import AppIntents
import Foundation

// Xcode 27's Swift 6.4 compiler ships the AppIntent schema macros. Runtime
// availability remains separate so the application can retain its iOS 26 target.
#if compiler(>=6.4)
@available(iOS 27.0, *)
@AppIntent(schema: .system.open)
struct OpenInventoryItemSystemIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Cubby Item"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    static let supportedModes: IntentModes = .foreground

    var target: InventoryItemEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        try await SiriInventoryService.shared.openItem(id: target.id)
        return .result()
    }
}

@available(iOS 27.0, *)
@AppIntent(schema: .system.searchInApp)
struct SearchInventorySystemIntent: ShowInAppSearchResultsIntent {
    static let title: LocalizedStringResource = "Search Cubby"
    static let searchScopes: [StringSearchScope] = [.general]
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    static let supportedModes: IntentModes = .foreground

    var criteria: StringSearchCriteria

    @MainActor
    func perform() async throws -> some IntentResult {
        try await SiriInventoryService.shared.search(query: criteria.term)
        return .result()
    }
}
#endif
