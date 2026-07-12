import SwiftUI

struct AddLocationView: View {
    let homeId: UUID?
    let parentLocation: AppStorageLocation?
    let onLocationCreated: ((AppStorageLocation) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sharedHomesGateService) private var sharedHomesGateService
    @EnvironmentObject private var appStore: AppStore

    @State private var locationName = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    init(
        homeId: UUID?,
        parentLocation: AppStorageLocation?,
        onLocationCreated: ((AppStorageLocation) -> Void)? = nil
    ) {
        self.homeId = homeId
        self.parentLocation = parentLocation
        self.onLocationCreated = onLocationCreated
    }

    private var resolvedHome: AppHome? {
        parentLocation.flatMap { appStore.home(id: $0.homeID) } ?? appStore.home(id: homeId)
    }

    private var isAddingSubLocation: Bool {
        parentLocation != nil
    }

    private var title: String {
        isAddingSubLocation ? "Add Sub-location" : "Add Storage Location"
    }

    private var nameFieldTitle: String {
        isAddingSubLocation ? "Sub-location name" : "Location name"
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

                Section(nameFieldTitle) {
                    TextField(nameFieldTitle, text: $locationName)
                        .textInputAutocapitalization(.words)

                    if let parentLocation {
                        HStack {
                            Text("Inside")
                            Spacer()
                            Text(parentLocation.name)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let parentLocation {
                    Section {
                        Label("Creates a sub-location inside \"\(parentLocation.name)\".", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(CubbyDesign.Palette.canvas)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(CubbyDesign.Typography.navigationTitle)
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveLocation() }
                        .disabled(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canCreateLocationsInHome)
                        .accessibilityIdentifier("save-location-button")
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
            let location = try appStore.createLocation(
                name: trimmedName,
                homeID: home.id,
                parentLocationID: parentLocation?.id
            )
            onLocationCreated?(location)
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

}
