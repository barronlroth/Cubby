import SwiftUI

struct AddHomeView: View {
    @Binding var selectedHome: AppHome?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.activePaywall) private var activePaywall
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @EnvironmentObject private var appStore: AppStore

    @State private var homeName = ""
    @State private var showingGateAlert = false
    @State private var gatePaywallReason: PaywallContext.Reason = .homeLimitReached

    var body: some View {
        NavigationStack {
            Form {
                Section("Home Details") {
                    TextField("Home Name", text: $homeName)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Add New Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveHome() }
                        .disabled(homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .alert("Cubby Pro Required", isPresented: $showingGateAlert) {
            Button("Upgrade") { presentUpgrade() }
            Button("Restore Purchases") {
                Task { await proAccessManager.restorePurchases() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(gateAlertMessage)
        }
    }

    private func saveHome() {
        let trimmedName = homeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let gate = appStore.canCreateHome(isPro: proAccessManager.isPro)
        guard gate.isAllowed else {
            gatePaywallReason = gate.reason == .overLimit ? .overLimit : .homeLimitReached
            showingGateAlert = true
            return
        }

        do {
            let newHome = try appStore.createHome(name: trimmedName)
            selectedHome = newHome
            dismiss()
        } catch {
            DebugLogger.error("Failed to save home: \(error)")
        }
    }

    private var gateAlertMessage: String {
        switch gatePaywallReason {
        case .subscriptionRequired:
            "Cubby Pro is required to create and use your home inventory."
        case .homeLimitReached:
            "Cubby Pro is required to add another home."
        case .overLimit:
            "Cubby Pro is required to keep adding homes and items."
        case .itemLimitReached:
            "Cubby Pro is required to add more items."
        case .manualUpgrade:
            "Cubby Pro unlocks every home and item."
        }
    }

    private func presentUpgrade() {
        let reason = gatePaywallReason
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            activePaywall.wrappedValue = PaywallContext(reason: reason)
        }
    }
}
