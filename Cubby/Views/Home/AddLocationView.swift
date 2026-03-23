import SwiftUI

struct AddLocationView: View {
    let homeId: UUID?
    let parentLocation: AppStorageLocation?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sharedHomesGateService) private var sharedHomesGateService
    @EnvironmentObject private var appStore: AppStore

    @State private var locationName = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    private var resolvedHome: AppHome? {
        parentLocation.flatMap { appStore.home(id: $0.homeID) } ?? appStore.home(id: homeId)
    }

    var body: some View {
        NavigationStack {
            Form {
                if canCreateLocationsInHome == false {
                    Section {
                        Label(
                            "You have read-only access to this shared home.",
                            systemImage: "lock.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Location Details") {
                    TextField("Location Name", text: $locationName)
                        .textInputAutocapitalization(.words)

                    if let parentLocation {
                        HStack {
                            Text("Parent Location")
                            Spacer()
                            Text(parentLocation.name)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let parentLocation {
                    Section {
                        Label("This location will be nested under \"\(parentLocation.name)\"", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(appBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Storage Location")
                        .font(.custom("AwesomeSerif-ExtraTall", size: 20))
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveLocation() }
                        .disabled(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canCreateLocationsInHome)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveLocation() {
        guard canCreateLocationsInHome else {
            errorMessage = "You have read-only access and can’t add locations in this shared home."
            showingError = true
            return
        }

        guard let home = resolvedHome else {
            errorMessage = "Unable to find the selected home. Please try again."
            showingError = true
            return
        }

        let trimmedName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        do {
            _ = try appStore.createLocation(
                name: trimmedName,
                homeID: home.id,
                parentLocationID: parentLocation?.id
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private var canCreateLocationsInHome: Bool {
        guard sharedHomesGateService.isEnabled() else { return true }
        guard let home = resolvedHome else { return false }
        return home.permission.canCreateLocations
    }

    @Environment(\.colorScheme) private var colorScheme
    private var appBackground: Color {
        if colorScheme == .light, UIColor(named: "AppBackground") != nil {
            return Color("AppBackground")
        } else {
            return Color(.systemBackground)
        }
    }
}
