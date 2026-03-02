import RevenueCat
import RevenueCatUI
import SwiftUI

struct ProPaywallSheetView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @State private var didTimeout = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)

                if let error = proAccessManager.offeringsErrorMessage {
                    errorRetryView(message: error)
                } else if didTimeout {
                    errorRetryView(message: "Unable to load purchase options. Please check your connection and try again.")
                } else if proAccessManager.isLoadingOfferings {
                    ProgressView("Loading options…")
                        .padding(.vertical, 24)
                } else if let offering = proAccessManager.offerings?.current {
                    PaywallView(offering: offering, displayCloseButton: false)
                } else {
                    ProgressView("Loading options…")
                        .padding(.vertical, 24)
                        .task {
                            await proAccessManager.loadOfferings()
                        }
                        .task {
                            try? await Task.sleep(for: .seconds(10))
                            if proAccessManager.isLoadingOfferings || proAccessManager.offerings?.current == nil {
                                didTimeout = true
                            }
                        }
                }

                if let message = proAccessManager.restoreMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                complianceSection
            }
            .padding(.vertical, 16)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: proAccessManager.isPro) { _, isPro in
                if isPro {
                    dismiss()
                }
            }
        }
    }

    private func errorRetryView(message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Try Again") {
                    didTimeout = false
                    Task { await proAccessManager.loadOfferings() }
                }
                .buttonStyle(.borderedProminent)

                Button("Restore Purchases") {
                    Task { await proAccessManager.restorePurchases() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
    }

    private var complianceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subscription Information")
                .font(.headline)

            if subscriptionDetails.isEmpty {
                Text("Subscription title, length, and price are shown in the purchase options above.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(subscriptionDetails, id: \.self) { detail in
                    Text("• \(detail)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Manage or cancel in your App Store account settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    Link("Terms of Use (EULA)", destination: termsURL)
                }
                if let privacyURL = URL(string: "https://alfred.barronroth.com/cubby/privacy") {
                    Link("Privacy Policy", destination: privacyURL)
                }
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var subscriptionDetails: [String] {
        proAccessManager.availablePackages
            .filter { $0.storeProduct.productCategory == .subscription }
            .map { package in
                let product = package.storeProduct
                let title = product.localizedTitle.isEmpty ? package.identifier : product.localizedTitle
                return "\(title): \(product.localizedPriceString) every \(subscriptionLengthDescription(product.subscriptionPeriod))"
            }
    }

    private func subscriptionLengthDescription(_ period: SubscriptionPeriod?) -> String {
        guard let period else { return "period" }
        let unit: String
        switch period.unit {
        case .day:
            unit = period.value == 1 ? "day" : "days"
        case .week:
            unit = period.value == 1 ? "week" : "weeks"
        case .month:
            unit = period.value == 1 ? "month" : "months"
        case .year:
            unit = period.value == 1 ? "year" : "years"
        @unknown default:
            unit = "period"
        }
        return "\(period.value) \(unit)"
    }

    private var title: String {
        switch context.reason {
        case .homeLimitReached:
            "Add More Homes with Cubby Pro"
        case .itemLimitReached:
            "Add More Items with Cubby Pro"
        case .overLimit:
            "Upgrade to Keep Creating"
        case .manualUpgrade:
            "Upgrade to Cubby Pro"
        }
    }

    private var subtitle: String {
        switch context.reason {
        case .homeLimitReached:
            "Free includes 1 home. Pro unlocks unlimited homes and items."
        case .itemLimitReached:
            "Free includes up to 10 items. Pro unlocks unlimited items."
        case .overLimit:
            "You’re over the Free limit. Upgrade to Pro or delete down to continue creating."
        case .manualUpgrade:
            "Unlock unlimited homes and items with Cubby Pro."
        }
    }
}
