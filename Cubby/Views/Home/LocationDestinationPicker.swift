import SwiftUI

/// What a destination picker is moving.
enum LocationMoveSubject: Identifiable, Equatable {
    case location(AppStorageLocation)
    case items([AppInventoryItem])

    var id: String {
        switch self {
        case .location(let location):
            "location-\(location.id)"
        case .items(let items):
            "items-" + items.map(\.id.uuidString).sorted().joined(separator: ",")
        }
    }

    var homeID: UUID? {
        switch self {
        case .location(let location):
            location.homeID
        case .items(let items):
            items.first?.homeID
        }
    }
}

/// Picks where to move a location (or a set of items). Invalid destinations are
/// shown greyed out; locations can also move to the top level of their home.
struct LocationDestinationPicker: View {
    /// A chosen destination: nil means the top level of the home (location moves only).
    typealias Destination = UUID?

    let subject: LocationMoveSubject
    let onMove: (Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appStore: AppStore

    @State private var selection: Destination?
    @State private var selectionFeedbackCount = 0

    private var homeID: UUID? { subject.homeID }

    private var home: AppHome? { appStore.home(id: homeID) }

    private var movingLocation: AppStorageLocation? {
        if case .location(let location) = subject {
            return appStore.location(id: location.id) ?? location
        }
        return nil
    }

    private var movingItems: [AppInventoryItem] {
        if case .items(let items) = subject { return items }
        return []
    }

    /// The moving location and its descendants can never be destinations.
    private var subtreeIDs: Set<UUID> {
        guard let movingLocation else { return [] }
        return appStore.subtreeLocationIDs(of: movingLocation.id)
    }

    /// Every location in the home in outline order.
    private var outline: [AppStorageLocation] {
        var result: [AppStorageLocation] = []
        func visit(_ locations: [AppStorageLocation]) {
            for location in locations {
                result.append(location)
                visit(appStore.childLocations(of: location.id))
            }
        }
        visit(appStore.rootLocations(in: homeID))
        return result
    }

    private var currentDestination: Destination {
        if let movingLocation {
            return movingLocation.parentLocationID
        }
        let origins = Set(movingItems.compactMap(\.storageLocationID))
        return origins.count == 1 ? origins.first : nil
    }

    private func isDisabled(_ destination: Destination) -> Bool {
        if let movingLocation {
            if let destination, subtreeIDs.contains(destination) { return true }
            return !appStore.canMoveLocation(id: movingLocation.id, toParent: destination)
        }
        guard let destination else { return true }
        return movingItems.allSatisfy { $0.storageLocationID == destination }
    }

    private var title: String {
        if let movingLocation {
            return "Move \u{201C}\(movingLocation.name)\u{201D}"
        }
        return movingItems.count == 1 ? "Move 1 Item" : "Move \(movingItems.count) Items"
    }

    private var subtitle: String {
        if let movingLocation {
            let nestedCount = subtreeIDs.count - 1
            let itemCount = appStore.items.filter { item in
                item.storageLocationID.map(subtreeIDs.contains) ?? false
            }.count
            if nestedCount == 0 && itemCount == 0 {
                return "Choose where this location should live."
            }
            return "Its \(nestedCount) nested location\(nestedCount == 1 ? "" : "s") and \(itemCount) item\(itemCount == 1 ? "" : "s") move with it."
        }
        return "Choose a location for the selected items."
    }

    private var resultingPath: String? {
        guard let selection else { return nil }
        let destinationPath = selection.flatMap { appStore.location(id: $0)?.fullPath }
        if let movingLocation {
            return [destinationPath ?? home?.name, movingLocation.name]
                .compactMap { $0 }
                .joined(separator: " > ")
        }
        return destinationPath
    }

    private var canConfirm: Bool {
        guard let selection else { return false }
        return selection != currentDestination && !isDisabled(selection)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(subtitle)
                        .font(CubbyDesign.Typography.bodySmall)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section {
                    if movingLocation != nil {
                        destinationRow(
                            destination: nil,
                            name: "Top level of \(home?.name ?? "Home")",
                            systemImage: "house",
                            depth: 0
                        )
                    }

                    ForEach(outline) { location in
                        destinationRow(
                            destination: location.id,
                            name: location.name,
                            systemImage: location.childLocationIDs.isEmpty ? "folder" : "folder.fill",
                            depth: location.depth + (movingLocation == nil ? 0 : 1)
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(CubbyDesign.Palette.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { confirmationBar }
            .sensoryFeedback(.selection, trigger: selectionFeedbackCount)
        }
    }

    private func destinationRow(
        destination resolved: Destination,
        name: String,
        systemImage: String,
        depth: Int
    ) -> some View {
        let disabled = isDisabled(resolved)
        let isCurrent = resolved == currentDestination
        let isSelected = selection.map { $0 == resolved } ?? false

        return Button {
            guard !disabled else { return }
            if !isSelected { selectionFeedbackCount += 1 }
            selection = .some(resolved)
        } label: {
            HStack(spacing: CubbyDesign.Spacing.medium) {
                Image(systemName: systemImage)
                    .foregroundStyle(disabled ? Color.secondary : CubbyDesign.Palette.accent)
                Text(name)
                    .font(CubbyDesign.Typography.body)
                    .foregroundStyle(disabled ? Color.secondary : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if isCurrent {
                    Text("Current")
                        .font(CubbyDesign.Typography.captionEmphasized)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: CubbyDesign.Spacing.small)
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(CubbyDesign.Palette.accent)
                }
            }
            .padding(.leading, CGFloat(min(depth, 6)) * CubbyDesign.Spacing.standard)
            .frame(minHeight: CubbyDesign.Layout.minimumTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isCurrent ? "Current location" : "")
        .accessibilityHint(disabled ? "Unavailable as a destination." : "")
    }

    private var confirmationBar: some View {
        VStack(alignment: .leading, spacing: CubbyDesign.Spacing.small) {
            if let resultingPath {
                Label {
                    Text(resultingPath)
                        .font(CubbyDesign.Typography.path)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "arrow.turn.down.right")
                }
                .foregroundStyle(.secondary)
                .accessibilityLabel("New location: \(resultingPath)")
            }

            Button {
                guard let selection, canConfirm else { return }
                dismiss()
                onMove(selection)
            } label: {
                Text("Move Here")
                    .font(CubbyDesign.Typography.callToAction)
                    .frame(maxWidth: .infinity, minHeight: CubbyDesign.Layout.minimumTapTarget)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canConfirm)
        }
        .padding(.horizontal, CubbyDesign.Spacing.standard)
        .padding(.vertical, CubbyDesign.Spacing.medium)
        .background(.bar)
    }
}
