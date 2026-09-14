import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("First Run Inventory Repository Tests")
struct FirstRunInventoryRepositoryTests {
    @MainActor
    private func makeRepository() throws -> CoreDataAppRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FirstRunInventoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return CoreDataAppRepository(
            persistenceController: try PersistenceController(storeDirectory: directory),
            shareService: nil
        )
    }

    @MainActor
    private func count(
        _ entityName: String,
        using repository: CoreDataAppRepository
    ) throws -> Int {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        return try repository.persistenceController.persistentContainer.viewContext.count(for: request)
    }

    @MainActor
    private func object(
        _ entityName: String,
        id: UUID,
        using repository: CoreDataAppRepository
    ) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try #require(
            repository.persistenceController.persistentContainer.viewContext.fetch(request).first
        )
    }

    @Test("Custom location commits one complete private-store inventory graph")
    @MainActor
    func customLocationCommitsCompleteGraph() throws {
        let repository = try makeRepository()

        let result = try repository.createFirstRunInventory(
            FirstRunInventoryDraft(
                homeName: "  Juniper House  ",
                itemTitle: "  Passport  ",
                locationChoice: .named("  Entry Closet  ")
            )
        )

        #expect(result.home.name == "Juniper House")
        #expect(result.item.title == "Passport")
        #expect(result.selectedLocation.name == "Entry Closet")
        #expect(result.item.homeID == result.home.id)
        #expect(result.item.storageLocationID == result.selectedLocation.id)
        #expect(try count("CDHome", using: repository) == 1)
        #expect(try count("CDStorageLocation", using: repository) == 2)
        #expect(try count("CDInventoryItem", using: repository) == 1)

        let privateStore = try #require(repository.persistenceController.privatePersistentStore())
        let committedObjects = try [
            object("CDHome", id: result.home.id, using: repository),
            object("CDStorageLocation", id: result.defaultUnsortedLocationID, using: repository),
            object("CDStorageLocation", id: result.selectedLocation.id, using: repository),
            object("CDInventoryItem", id: result.item.id, using: repository)
        ]
        #expect(committedObjects.allSatisfy { $0.objectID.persistentStore == privateStore })
    }

    @Test("Unsorted is reused instead of duplicated")
    @MainActor
    func unsortedIsReused() throws {
        let repository = try makeRepository()

        let result = try repository.createFirstRunInventory(
            FirstRunInventoryDraft(
                homeName: "Apartment",
                itemTitle: "Spare Keys",
                locationChoice: .unsorted
            )
        )

        #expect(result.selectedLocation.id == result.defaultUnsortedLocationID)
        #expect(result.selectedLocation.name == "Unsorted")
        #expect(try count("CDStorageLocation", using: repository) == 1)
        #expect(try count("CDInventoryItem", using: repository) == 1)
    }

    @Test("Every custom-location mutation boundary rolls back the whole graph")
    @MainActor
    func customLocationFailuresRollBack() throws {
        let repository = try makeRepository()

        for failurePoint in 1...4 {
            #expect(throws: FirstRunInventoryCommitError.simulatedFailure) {
                try repository.createFirstRunInventory(
                    FirstRunInventoryDraft(
                        homeName: "Home",
                        itemTitle: "Item",
                        locationChoice: .named("Closet")
                    ),
                    testFailureAfterMutationCount: failurePoint
                )
            }

            #expect(try count("CDHome", using: repository) == 0)
            #expect(try count("CDStorageLocation", using: repository) == 0)
            #expect(try count("CDInventoryItem", using: repository) == 0)
        }
    }

    @Test("Every Unsorted mutation boundary rolls back the whole graph")
    @MainActor
    func unsortedFailuresRollBack() throws {
        let repository = try makeRepository()

        for failurePoint in 1...3 {
            #expect(throws: FirstRunInventoryCommitError.simulatedFailure) {
                try repository.createFirstRunInventory(
                    FirstRunInventoryDraft(
                        homeName: "Home",
                        itemTitle: "Item",
                        locationChoice: .unsorted
                    ),
                    testFailureAfterMutationCount: failurePoint
                )
            }

            #expect(try count("CDHome", using: repository) == 0)
            #expect(try count("CDStorageLocation", using: repository) == 0)
            #expect(try count("CDInventoryItem", using: repository) == 0)
        }
    }

    @Test("Failed first-run commit preserves previously saved inventory")
    @MainActor
    func rollbackPreservesExistingInventory() throws {
        let repository = try makeRepository()
        _ = try repository.createHome(name: "Existing Home")

        #expect(throws: FirstRunInventoryCommitError.simulatedFailure) {
            try repository.createFirstRunInventory(
                FirstRunInventoryDraft(
                    homeName: "New Home",
                    itemTitle: "Item",
                    locationChoice: .unsorted
                ),
                testFailureAfterMutationCount: 2
            )
        }

        #expect(try count("CDHome", using: repository) == 1)
        #expect(try count("CDStorageLocation", using: repository) == 1)
        #expect(try count("CDInventoryItem", using: repository) == 0)
        #expect(try repository.listHomes().map(\.name) == ["Existing Home"])
    }

    @Test("Final save failure rolls back the new graph and preserves saved inventory")
    @MainActor
    func saveFailureRollsBack() throws {
        let repository = try makeRepository()
        _ = try repository.createHome(name: "Existing Home")

        #expect(throws: FirstRunInventoryCommitError.simulatedSaveFailure) {
            try repository.createFirstRunInventory(
                FirstRunInventoryDraft(
                    homeName: "New Home",
                    itemTitle: "Passport",
                    locationChoice: .named("Closet")
                ),
                testFailureAfterMutationCount: nil,
                testShouldFailSave: true
            )
        }

        #expect(try count("CDHome", using: repository) == 1)
        #expect(try count("CDStorageLocation", using: repository) == 1)
        #expect(try count("CDInventoryItem", using: repository) == 0)
        #expect(try repository.listHomes().map(\.name) == ["Existing Home"])
    }

    @Test("Repository rejects a duplicate named Unsorted location before mutation")
    @MainActor
    func duplicateUnsortedIsRejected() throws {
        let repository = try makeRepository()

        #expect(throws: FirstRunInventoryCommitError.self) {
            try repository.createFirstRunInventory(
                FirstRunInventoryDraft(
                    homeName: "Home",
                    itemTitle: "Item",
                    locationChoice: .named(" unsorted ")
                )
            )
        }

        #expect(try count("CDHome", using: repository) == 0)
    }
}

@Suite("Onboarding Coordinator Tests")
struct OnboardingCoordinatorTests {
    @MainActor
    private func makeResult() -> FirstRunInventoryResult {
        let homeID = UUID()
        let locationID = UUID()
        let now = Date()
        return FirstRunInventoryResult(
            home: AppHome(
                id: homeID,
                name: "Home",
                createdAt: now,
                modifiedAt: now,
                isShared: false,
                isOwnedByCurrentUser: true,
                permission: SharePermission(role: .owner),
                participantSummary: nil
            ),
            defaultUnsortedLocationID: UUID(),
            selectedLocation: AppStorageLocation(
                id: locationID,
                name: "Closet",
                createdAt: now,
                modifiedAt: now,
                depth: 0,
                homeID: homeID,
                homeName: "Home",
                parentLocationID: nil,
                fullPath: "Home > Closet",
                childLocationIDs: [],
                itemCount: 1
            ),
            item: AppInventoryItem(
                id: UUID(),
                title: "Passport",
                itemDescription: nil,
                photoFileName: nil,
                emoji: "📦",
                isPendingAiEmoji: false,
                createdAt: now,
                modifiedAt: now,
                tags: [],
                homeID: homeID,
                homeName: "Home",
                storageLocationID: locationID,
                storageLocationName: "Closet",
                storageLocationPath: "Home > Closet"
            )
        )
    }

    @Test("Focused steps validate, trim, preserve draft, and support Back")
    @MainActor
    func focusedStepNavigation() {
        let coordinator = OnboardingCoordinator()

        #expect(coordinator.currentStage == .welcome)
        coordinator.startSetup()
        #expect(coordinator.currentStage == .home)
        #expect(coordinator.continueFromHome() == false)

        coordinator.draft.homeName = "  Juniper House "
        #expect(coordinator.continueFromHome())
        #expect(coordinator.draft.homeName == "Juniper House")
        coordinator.draft.itemTitle = " Passport "
        #expect(coordinator.continueFromItem())
        coordinator.selectSuggestedLocation("Entry Closet")
        #expect(coordinator.continueFromLocation())
        #expect(coordinator.reviewPath == "Juniper House > Entry Closet > Passport")

        coordinator.path.removeLast()
        #expect(coordinator.currentStage == .location)
        #expect(coordinator.draft.itemTitle == "Passport")
    }

    @Test("Unsorted is a deliberate location choice and reaches Review")
    @MainActor
    func unsortedChoice() {
        let coordinator = OnboardingCoordinator()
        coordinator.startSetup()
        coordinator.draft.homeName = "Home"
        #expect(coordinator.continueFromHome())
        coordinator.draft.itemTitle = "Keys"
        #expect(coordinator.continueFromItem())

        coordinator.useUnsorted()

        #expect(coordinator.currentStage == .review)
        #expect(coordinator.reviewPath == "Home > Unsorted > Keys")
    }

    @Test("Failed save keeps the draft and a retry can succeed")
    @MainActor
    func failedSaveCanRetry() {
        let coordinator = OnboardingCoordinator()
        coordinator.draft = .init(
            homeName: "Home",
            itemTitle: "Passport",
            locationChoice: .named("Closet")
        )
        coordinator.path = [.review]

        let failedResult = coordinator.submit { _ in
            throw FirstRunInventoryCommitError.simulatedFailure
        }
        #expect(failedResult == nil)
        #expect(coordinator.saveErrorMessage != nil)
        #expect(coordinator.draft.itemTitle == "Passport")

        let expectedResult = makeResult()
        let result = coordinator.submit { _ in expectedResult }
        #expect(result == expectedResult)
        #expect(coordinator.saveErrorMessage == nil)
        #expect(coordinator.isSaving == false)
    }

    @Test("Submit is single-flight while the repository closure is running")
    @MainActor
    func submitIsSingleFlight() {
        let coordinator = OnboardingCoordinator()
        coordinator.draft = .init(
            homeName: "Home",
            itemTitle: "Passport",
            locationChoice: .named("Closet")
        )
        coordinator.path = [.review]
        var commitCount = 0

        let outerResult = coordinator.submit { _ in
            commitCount += 1
            let nestedResult = coordinator.submit { _ in
                commitCount += 1
                return makeResult()
            }
            #expect(nestedResult == nil)
            return makeResult()
        }

        #expect(outerResult != nil)
        #expect(commitCount == 1)
    }

    @Test("Out-of-order and duplicate transitions are ignored")
    @MainActor
    func transitionsAreStageGuarded() {
        let coordinator = OnboardingCoordinator()
        coordinator.draft = .init(
            homeName: "Home",
            itemTitle: "Passport",
            locationChoice: .named("Closet")
        )
        var commitCount = 0

        #expect(coordinator.continueFromHome() == false)
        #expect(coordinator.submit { _ in
            commitCount += 1
            return makeResult()
        } == nil)

        coordinator.startSetup()
        #expect(coordinator.continueFromHome())
        #expect(coordinator.continueFromHome() == false)
        #expect(coordinator.path == [.home, .item])

        #expect(coordinator.continueFromItem())
        #expect(coordinator.continueFromItem() == false)
        #expect(coordinator.path == [.home, .item, .location])

        coordinator.selectSuggestedLocation("Closet")
        #expect(coordinator.continueFromLocation())
        #expect(coordinator.continueFromLocation() == false)
        coordinator.useUnsorted()
        #expect(coordinator.path == [.home, .item, .location, .review])
        #expect(commitCount == 0)
    }
}
