import Foundation
import RevenueCat

@MainActor
final class ProAccessManager: NSObject, ObservableObject {
    static let proEntitlementId = "pro"
    static let annualProductId = "cubby_pro_annual"
    static let monthlyProductId = "cubby_pro_monthly"

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published private(set) var availablePackages: [Package] = []
    @Published private(set) var isPro: Bool = false

    @Published private(set) var isRefreshingCustomerInfo = false
    @Published private(set) var isLoadingOfferings = false
    @Published private(set) var offeringsErrorMessage: String?

    @Published private(set) var isRestoringPurchases = false
    @Published private(set) var restoreMessage: String?

    private let isUITestingOverride: Bool
    private let isConfigured: Bool

    var isRevenueCatConfigured: Bool {
        isConfigured
    }

    override init() {
        let args = ProcessInfo.processInfo.arguments
        let isUITestingOverride = args.contains("UI-TESTING") || args.contains("-ui_testing")
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let forcedProAccess: Bool? = {
            if args.contains("FORCE_PRO_TIER") {
                return true
            }
            if args.contains("FORCE_FREE_TIER") {
                return false
            }
            return nil
        }()

        let shouldBypassRevenueCat: Bool
        if isUITestingOverride || isPreview || isRunningTests {
            shouldBypassRevenueCat = true
        } else {
            #if DEBUG
            shouldBypassRevenueCat = forcedProAccess != nil
            #else
            shouldBypassRevenueCat = false
            #endif
        }

        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "RevenueCatPublicApiKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let looksLikeUnexpandedBuildSetting = apiKey.contains("$(") || apiKey.contains("REVENUECAT_PUBLIC_API_KEY")
        let looksLikeTestKey = apiKey.hasPrefix("test_")
        let hasUsableApiKey = !apiKey.isEmpty && !looksLikeUnexpandedBuildSetting

        let apiKeyErrorMessage: String? = {
            if !hasUsableApiKey {
                return "Purchases aren’t configured in this build. Set REVENUECAT_PUBLIC_API_KEY in your .xcconfig."
            }
            #if DEBUG
            return nil
            #else
            if looksLikeTestKey {
                return "Purchases aren’t configured in this build. This build is using a RevenueCat test key; use your production Public SDK Key for TestFlight/App Store builds."
            }
            return nil
            #endif
        }()

        #if DEBUG
        if !hasUsableApiKey {
            fatalError("Missing RevenueCatPublicApiKey. Set REVENUECAT_PUBLIC_API_KEY in your .xcconfig.")
        }
        #endif

        let shouldConfigureRevenueCat = !shouldBypassRevenueCat && hasUsableApiKey && apiKeyErrorMessage == nil

        self.isUITestingOverride = isUITestingOverride
        self.isConfigured = shouldConfigureRevenueCat
        super.init()

        if shouldBypassRevenueCat {
            self.isPro = forcedProAccess ?? true
            return
        }

        guard shouldConfigureRevenueCat else {
            self.offeringsErrorMessage = apiKeyErrorMessage
            return
        }

        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        Purchases.configure(withAPIKey: apiKey)

        Purchases.shared.delegate = self

        if let cached = Purchases.shared.cachedCustomerInfo {
            applyCustomerInfo(cached)
        }

        Task {
            await refresh()
            await loadOfferings()
        }
    }

    var hasActiveAnnualSubscription: Bool {
        guard isPro else { return false }
        return proProductIdentifier == Self.annualProductId
    }

    var hasActiveMonthlySubscription: Bool {
        guard isPro else { return false }
        return proProductIdentifier == Self.monthlyProductId
    }

    var proProductIdentifier: String? {
        customerInfo?.entitlements[Self.proEntitlementId]?.productIdentifier
    }

    func refresh() async {
        guard isConfigured else { return }
        isRefreshingCustomerInfo = true
        defer { isRefreshingCustomerInfo = false }

        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            DebugLogger.warning("RevenueCat refresh failed: \(error.localizedDescription)")
        }
    }

    func loadOfferings() async {
        guard isConfigured else { return }
        isLoadingOfferings = true
        offeringsErrorMessage = nil
        defer { isLoadingOfferings = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            let packages = offerings.current?.availablePackages ?? []
            self.availablePackages = packages
            if offerings.current == nil || packages.isEmpty {
                offeringsErrorMessage = "No purchase options found. Configure your Current Offering in RevenueCat."
            }
        } catch {
            offeringsErrorMessage = "Couldn’t load purchase options. Please try again."
            DebugLogger.warning("RevenueCat loadOfferings failed: \(error.localizedDescription)")
        }
    }

    func purchase(package: Package) async throws {
        guard isConfigured else { return }
        restoreMessage = nil

        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled {
            return
        }
        applyCustomerInfo(result.customerInfo)
    }

    func restorePurchases() async {
        guard isConfigured else { return }
        isRestoringPurchases = true
        restoreMessage = nil
        defer { isRestoringPurchases = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            applyCustomerInfo(info)

            if isPro {
                restoreMessage = "Purchases restored."
            } else {
                restoreMessage = "No purchases found."
            }
        } catch {
            restoreMessage = "Restore failed. Please try again."
            DebugLogger.warning("RevenueCat restorePurchases failed: \(error.localizedDescription)")
        }
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        customerInfo = info
        isPro = info.entitlements[Self.proEntitlementId]?.isActive == true
    }
}

extension ProAccessManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        applyCustomerInfo(customerInfo)
    }
}
