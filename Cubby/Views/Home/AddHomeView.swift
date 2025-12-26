import SwiftUI
import SwiftData

struct AddHomeView: View {
    @Binding var selectedHome: Home?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.activePaywall) private var activePaywall
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var proAccessManager: ProAccessManager
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
            Button("Upgrade") {
                presentUpgrade()
            }
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

        let gate = FeatureGate.canCreateHome(modelContext: modelContext, isPro: proAccessManager.isPro)
        guard gate.isAllowed else {
            gatePaywallReason = gate.reason == .overLimit ? .overLimit : .homeLimitReached
            showingGateAlert = true
            return
        }
        
        let newHome = Home(name: trimmedName)
        modelContext.insert(newHome)
        
        let unsortedLocation = StorageLocation(name: "Unsorted", home: newHome)
        modelContext.insert(unsortedLocation)
        
        do {
            try modelContext.save()
            selectedHome = newHome
            dismiss()
        } catch {
            print("Failed to save home: \(error)")
        }
    }

    private var gateAlertMessage: String {
        switch gatePaywallReason {
        case .homeLimitReached:
            "Free includes 1 home. Upgrade to Cubby Pro to add more."
        case .overLimit:
            "You’re over the Free limit. Upgrade to Pro or delete down to continue creating."
        case .itemLimitReached:
            "Upgrade to Cubby Pro to add more."
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
