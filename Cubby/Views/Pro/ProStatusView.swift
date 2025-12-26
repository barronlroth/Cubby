import RevenueCatUI
import StoreKit
import SwiftUI

#if os(iOS)
import UIKit
#endif

struct ProStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var proAccessManager: ProAccessManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(proAccessManager.isPro ? "Pro" : "Free")
                            .foregroundStyle(proAccessManager.isPro ? .green : .secondary)
                    }

                    if let product = proAccessManager.proProductIdentifier {
                        HStack {
                            Text("Plan")
                            Spacer()
                            Text(planName(for: product))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await proAccessManager.restorePurchases() }
                    } label: {
                        if proAccessManager.isRestoringPurchases {
                            Label("Restoring…", systemImage: "arrow.clockwise")
                        } else {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(proAccessManager.isRestoringPurchases)

                    if proAccessManager.hasActiveAnnualSubscription {
                        Button {
                            Task { await showManageSubscriptions() }
                        } label: {
                            Label("Manage Subscription", systemImage: "creditcard")
                        }
                    }

                    if let message = proAccessManager.restoreMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !proAccessManager.isPro, let offering = proAccessManager.offerings?.current {
                    Section("Upgrade") {
                        PaywallView(offering: offering, displayCloseButton: false)
                    }
                }
            }
            .navigationTitle("Cubby Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await proAccessManager.loadOfferings()
                await proAccessManager.refresh()
            }
        }
    }

    private func planName(for productId: String) -> String {
        switch productId {
        case ProAccessManager.annualProductId:
            "Annual"
        case ProAccessManager.lifetimeProductId:
            "Lifetime"
        default:
            productId
        }
    }

    @MainActor
    private func showManageSubscriptions() async {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene)
                return
            } catch { }
        }
        #endif

        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            openURL(url)
        }
    }
}
