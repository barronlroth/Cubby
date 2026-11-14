import Foundation

@MainActor
final class OnboardingCoordinator: ObservableObject {
    enum Stage: String, Hashable {
        case welcome
        case home
        case item
        case location
        case review
    }

    struct Draft: Equatable {
        var homeName = ""
        var itemTitle = ""
        var locationChoice: FirstRunLocationChoice?
    }

    @Published var path: [Stage] = []
    @Published var draft = Draft()
    @Published var customLocationName = ""
    @Published private(set) var validationMessage: String?
    @Published private(set) var saveErrorMessage: String?
    @Published private(set) var isSaving = false

    var currentStage: Stage {
        path.last ?? .welcome
    }

    var isSubmitting: Bool {
        isSaving
    }

    var reviewPath: String? {
        guard let locationChoice = draft.locationChoice else { return nil }
        return [
            draft.homeName,
            locationChoice.displayName,
            draft.itemTitle
        ].joined(separator: " > ")
    }

    func startSetup() {
        guard currentStage == .welcome else { return }
        validationMessage = nil
        saveErrorMessage = nil
        path = [.home]
    }

    @discardableResult
    func continueFromHome() -> Bool {
        guard currentStage == .home else { return false }
        let trimmedName = draft.homeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard case .success = ValidationHelpers.validateHomeName(trimmedName) else {
            validationMessage = validationMessage(
                from: ValidationHelpers.validateHomeName(trimmedName)
            )
            return false
        }

        draft.homeName = trimmedName
        validationMessage = nil
        path.append(.item)
        return true
    }

    @discardableResult
    func continueFromItem() -> Bool {
        guard currentStage == .item else { return false }
        let trimmedTitle = draft.itemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard case .success = ValidationHelpers.validateItemTitle(trimmedTitle) else {
            validationMessage = validationMessage(
                from: ValidationHelpers.validateItemTitle(trimmedTitle)
            )
            return false
        }

        draft.itemTitle = trimmedTitle
        validationMessage = nil
        path.append(.location)
        return true
    }

    func selectSuggestedLocation(_ name: String) {
        guard currentStage == .location else { return }
        customLocationName = ""
        draft.locationChoice = .named(name)
        validationMessage = nil
    }

    func setCustomLocationName(_ name: String) {
        guard currentStage == .location else { return }
        customLocationName = name
        draft.locationChoice = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : .named(name)
        validationMessage = nil
    }

    @discardableResult
    func continueFromLocation() -> Bool {
        guard currentStage == .location else { return false }
        guard let locationChoice = draft.locationChoice else {
            validationMessage = "Choose a suggested location, enter your own, or use Unsorted."
            return false
        }

        if case .named(let rawName) = locationChoice {
            let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.isEmpty == false else {
                validationMessage = "Location name cannot be empty"
                return false
            }
            guard trimmedName.count <= 100 else {
                validationMessage = "Location name must be less than 100 characters"
                return false
            }
            guard trimmedName.caseInsensitiveCompare("Unsorted") != .orderedSame else {
                validationMessage = "Choose Use Unsorted for Now instead."
                return false
            }
            draft.locationChoice = .named(trimmedName)
            customLocationName = customLocationName.isEmpty ? "" : trimmedName
        }

        validationMessage = nil
        path.append(.review)
        return true
    }

    func useUnsorted() {
        guard currentStage == .location else { return }
        customLocationName = ""
        draft.locationChoice = .unsorted
        validationMessage = nil
        path.append(.review)
    }

    func makeInventoryDraft() -> FirstRunInventoryDraft? {
        guard let locationChoice = draft.locationChoice else { return nil }
        return FirstRunInventoryDraft(
            homeName: draft.homeName,
            itemTitle: draft.itemTitle,
            locationChoice: locationChoice
        )
    }

    func submit(
        using commit: (FirstRunInventoryDraft) throws -> FirstRunInventoryResult
    ) -> FirstRunInventoryResult? {
        guard currentStage == .review,
              isSaving == false,
              let inventoryDraft = makeInventoryDraft() else {
            return nil
        }

        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        do {
            return try commit(inventoryDraft)
        } catch {
            saveErrorMessage = "Cubby couldn’t save your first item. Your entries are still here. Try again."
            return nil
        }
    }

    private func validationMessage(from result: ValidationResult) -> String? {
        guard case .failure(let message) = result else { return nil }
        return message
    }
}
