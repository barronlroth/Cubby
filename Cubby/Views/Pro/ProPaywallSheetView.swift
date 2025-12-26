import RevenueCatUI
import StoreKit
import SwiftUI

struct ProPaywallSheetView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var proAccessManager: ProAccessManager

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
                    VStack(spacing: 12) {
                        Text(error)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button("Retry") {
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
                }

                if let message = proAccessManager.restoreMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
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

    private var title: String {
        switch context.reason {
        case .homeLimitReached:
            "Add More Homes with Cubby Pro"
        case .itemLimitReached:
            "Add More Items with Cubby Pro"
        case .overLimit:
            "Upgrade to Keep Creating"
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
        }
    }
}

