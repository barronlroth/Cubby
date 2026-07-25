#if DEBUG
import CoreData
import Foundation
import SwiftUI

enum DesignFixtureScenario: String, CaseIterable, Identifiable {
    case standard
    case freeTier
    case itemLimitReached
    case emptyHome
    case missingLocalPhoto
    case onboarding

    var id: String { rawValue }
}

enum DesignFixtureSharing: String, CaseIterable, Identifiable {
    case notShared
    case owner
    case readWrite
    case readOnly
    case mixed

    var id: String { rawValue }
}

enum DesignFixtureSelection {
    case primary
    case secondary
    case none
}

struct DesignPreviewTraits {
    var colorScheme: ColorScheme?
    var dynamicTypeSize: DynamicTypeSize?
    var reduceMotion: Bool?

    static let standard = DesignPreviewTraits()
    static let dark = DesignPreviewTraits(colorScheme: .dark)
    static let accessibilityText = DesignPreviewTraits(dynamicTypeSize: .accessibility3)
    static let reducedMotion = DesignPreviewTraits(reduceMotion: true)
}

@MainActor
final class DesignPreviewFixture {
    let scenario: DesignFixtureScenario
    let persistenceController: PersistenceController
    let repository: CoreDataAppRepository
    let appStore: AppStore
    let proAccessManager: ProAccessManager
    let homeSharingService: (any HomeSharingServiceProtocol)?
    let sharedHomesGateService: any SharedHomesGateServiceProtocol
    let selectedHomeID: UUID?
    let primaryHomeID: UUID?
    let secondaryHomeID: UUID?
    let featuredItemID: UUID?
    let userDefaults: UserDefaults

    init(
        scenario: DesignFixtureScenario = .standard,
        selection: DesignFixtureSelection = .primary,
        proState: DesignProAccessState = .pro,
        sharing: DesignFixtureSharing = .notShared
    ) throws {
        self.scenario = scenario

        let persistenceController = try PersistenceController(inMemory: true)
        let seedResult = try DesignFixtureSeeder.seed(
            scenario,
            sharing: sharing,
            into: persistenceController
        )
        let homeSharingService = Self.makeSharingService(for: sharing)
        let sharedHomesGateService = SharedHomesGateService(
            distributionEnabled: true,
            runtimeOverride: true,
            localOverride: true,
            allowLocalOverride: true
        )
        let repository = CoreDataAppRepository(
            persistenceController: persistenceController,
            shareService: homeSharingService
        )
        let defaults = DesignCatalogDefaults.make(
            suiteName: "com.barronroth.Cubby.DesignPreview.\(UUID().uuidString)"
        )
        let appStore = AppStore(
            repository: repository,
            hiddenSharedHomeIDStore: HiddenSharedHomeIDStore(userDefaults: defaults)
        )

        self.persistenceController = persistenceController
        self.repository = repository
        self.appStore = appStore
        self.proAccessManager = ProAccessManager(designState: proState)
        self.homeSharingService = homeSharingService
        self.sharedHomesGateService = sharedHomesGateService
        self.primaryHomeID = seedResult.primaryHomeID
        self.secondaryHomeID = seedResult.secondaryHomeID
        self.featuredItemID = seedResult.featuredItemID
        self.userDefaults = defaults

        switch selection {
        case .primary:
            selectedHomeID = seedResult.primaryHomeID
        case .secondary:
            selectedHomeID = seedResult.secondaryHomeID
        case .none:
            selectedHomeID = nil
        }
    }

    var selectedHome: AppHome? {
        appStore.home(id: selectedHomeID)
    }

    var featuredItem: AppInventoryItem? {
        featuredItemID.flatMap(appStore.item(id:))
    }

    private static func makeSharingService(
        for sharing: DesignFixtureSharing
    ) -> (any HomeSharingServiceProtocol)? {
        let mode: DebugMockSharingMode
        switch sharing {
        case .notShared:
            return nil
        case .owner:
            mode = .owner
        case .readWrite:
            mode = .readWriteParticipant
        case .readOnly:
            mode = .readOnlyParticipant
        case .mixed:
            mode = .mixed
        }
        return DebugMockHomeSharingService(mode: mode)
    }
}

struct DesignPreviewHarness<Content: View>: View {
    let fixture: DesignPreviewFixture
    let traits: DesignPreviewTraits
    let content: (DesignPreviewFixture) -> Content

    init(
        fixture: DesignPreviewFixture,
        traits: DesignPreviewTraits = .standard,
        @ViewBuilder content: @escaping (DesignPreviewFixture) -> Content
    ) {
        self.fixture = fixture
        self.traits = traits
        self.content = content
    }

    var body: some View {
        content(fixture)
            .defaultAppStorage(fixture.userDefaults)
            .environmentObject(fixture.appStore)
            .environmentObject(fixture.proAccessManager)
            .environment(\.sharedHomesGateService, fixture.sharedHomesGateService)
            .environment(\.homeSharingService, fixture.homeSharingService)
            .modifier(DesignValidationEnvironmentModifier(traits: traits))
    }
}

extension CloudKitSyncSettings {
    static let designPreview = CloudKitSyncSettings(
        usesCloudKit: false,
        isInMemory: true,
        reason: .uiTesting,
        strictStartup: false,
        shouldInitializeCloudKitSchema: false,
        forcedAvailability: nil
    )
}

enum DesignFixtureIDs {
    static let primaryHome = uuid(1)
    static let secondaryHome = uuid(2)
    static let primaryLocation = uuid(101)
    static let secondaryLocation = uuid(102)
    static let nestedLocation = uuid(103)
    static let tertiaryLocation = uuid(104)
    static let secondaryHomeLocation = uuid(105)
    static let featuredItem = uuid(201)
    static let secondaryItem = uuid(202)
    static let missingPhotoItem = uuid(299)

    static func item(_ index: Int) -> UUID {
        uuid(300 + index)
    }

    private static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

private enum DesignFixtureSeeder {
    struct Result {
        let primaryHomeID: UUID?
        let secondaryHomeID: UUID?
        let featuredItemID: UUID?
    }

    private static let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

    static func seed(
        _ scenario: DesignFixtureScenario,
        sharing: DesignFixtureSharing,
        into persistenceController: PersistenceController
    ) throws -> Result {
        guard scenario != .onboarding else {
            return Result(primaryHomeID: nil, secondaryHomeID: nil, featuredItemID: nil)
        }
        guard let privateStore = persistenceController.privatePersistentStore(),
              let sharedStore = persistenceController.sharedPersistentStore() else {
            throw NSError(
                domain: "DesignPreviewFixture",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing Core Data fixture stores."]
            )
        }

        let primaryStore: NSPersistentStore
        switch sharing {
        case .readWrite, .readOnly:
            primaryStore = sharedStore
        case .notShared, .owner, .mixed:
            primaryStore = privateStore
        }
        let secondaryStore = sharing == .mixed ? sharedStore : primaryStore

        let context = persistenceController.persistentContainer.viewContext
        let result: Result
        switch scenario {
        case .standard:
            result = seedStandard(
                in: context,
                primaryStore: primaryStore,
                secondaryStore: secondaryStore
            )
        case .freeTier:
            result = seedFreeTier(in: context, store: primaryStore)
        case .itemLimitReached:
            result = seedItemLimit(in: context, store: primaryStore)
        case .emptyHome:
            result = seedEmptyHome(in: context, store: primaryStore)
        case .missingLocalPhoto:
            result = seedMissingPhoto(in: context, store: primaryStore)
        case .onboarding:
            fatalError("Handled before Core Data seeding.")
        }

        try context.save()
        return result
    }

    private static func seedStandard(
        in context: NSManagedObjectContext,
        primaryStore: NSPersistentStore,
        secondaryStore: NSPersistentStore
    ) -> Result {
        let mainHome = insertHome(
            id: DesignFixtureIDs.primaryHome,
            name: "Main Home",
            context: context,
            store: primaryStore
        )
        let beachHome = insertHome(
            id: DesignFixtureIDs.secondaryHome,
            name: "Beach House",
            context: context,
            store: secondaryStore
        )
        let garage = insertLocation(
            id: DesignFixtureIDs.primaryLocation,
            name: "Garage",
            home: mainHome,
            parent: nil,
            depth: 0,
            context: context,
            store: primaryStore
        )
        let bedroom = insertLocation(
            id: DesignFixtureIDs.secondaryLocation,
            name: "Master Bedroom",
            home: mainHome,
            parent: nil,
            depth: 0,
            context: context,
            store: primaryStore
        )
        let closet = insertLocation(
            id: DesignFixtureIDs.nestedLocation,
            name: "Walk-in Closet",
            home: mainHome,
            parent: bedroom,
            depth: 1,
            context: context,
            store: primaryStore
        )
        let office = insertLocation(
            id: DesignFixtureIDs.tertiaryLocation,
            name: "Home Office",
            home: mainHome,
            parent: nil,
            depth: 0,
            context: context,
            store: primaryStore
        )
        let beachShed = insertLocation(
            id: DesignFixtureIDs.secondaryHomeLocation,
            name: "Beach Equipment Shed",
            home: beachHome,
            parent: nil,
            depth: 0,
            context: context,
            store: secondaryStore
        )

        insertItem(
            id: DesignFixtureIDs.featuredItem,
            title: "Roof Cargo Box",
            description: "Thule XL, winter storage",
            emoji: "🛄",
            tags: ["travel", "winter"],
            location: garage,
            context: context,
            store: primaryStore
        )
        insertItem(
            id: DesignFixtureIDs.secondaryItem,
            title: "Travel Adapter Kit",
            description: "EU, UK, AU plugs and USB-C",
            emoji: "🔌",
            tags: ["electronics", "travel"],
            location: closet,
            context: context,
            store: primaryStore
        )
        insertItem(
            id: DesignFixtureIDs.item(1),
            title: "Passport",
            description: "Expires 2028",
            emoji: "🛂",
            tags: ["documents"],
            location: office,
            context: context,
            store: primaryStore
        )
        insertItem(
            id: DesignFixtureIDs.item(2),
            title: "Surfboard",
            description: "Seven-foot funboard",
            emoji: "🏄",
            tags: ["beach", "sports"],
            location: beachShed,
            context: context,
            store: secondaryStore
        )

        return Result(
            primaryHomeID: DesignFixtureIDs.primaryHome,
            secondaryHomeID: DesignFixtureIDs.secondaryHome,
            featuredItemID: DesignFixtureIDs.featuredItem
        )
    }

    private static func seedFreeTier(
        in context: NSManagedObjectContext,
        store: NSPersistentStore
    ) -> Result {
        let home = insertHome(
            id: DesignFixtureIDs.primaryHome,
            name: "Reach",
            context: context,
            store: store
        )
        let armory = insertLocation(
            id: DesignFixtureIDs.primaryLocation,
            name: "Armory",
            home: home,
            parent: nil,
            depth: 0,
            context: context,
            store: store
        )
        let titles = [
            "MA5B Assault Rifle", "BR55 Battle Rifle", "M6G Magnum",
            "MJOLNIR Armor", "Energy Sword", "Pelican Dropship",
            "Warthog", "Cortana AI Chip", "Nav Data Pad"
        ]
        for (index, title) in titles.enumerated() {
            insertItem(
                id: DesignFixtureIDs.item(index),
                title: title,
                description: "Free-tier design fixture",
                emoji: "📦",
                tags: ["fixture"],
                location: armory,
                context: context,
                store: store
            )
        }
        return Result(
            primaryHomeID: DesignFixtureIDs.primaryHome,
            secondaryHomeID: nil,
            featuredItemID: DesignFixtureIDs.item(0)
        )
    }

    private static func seedItemLimit(
        in context: NSManagedObjectContext,
        store: NSPersistentStore
    ) -> Result {
        let home = insertHome(
            id: DesignFixtureIDs.primaryHome,
            name: "Main Home",
            context: context,
            store: store
        )
        let closet = insertLocation(
            id: DesignFixtureIDs.primaryLocation,
            name: "Closet",
            home: home,
            parent: nil,
            depth: 0,
            context: context,
            store: store
        )
        for index in 1...10 {
            insertItem(
                id: DesignFixtureIDs.item(index),
                title: "Test Item \(index)",
                description: "Seeded to hit the free item limit",
                emoji: "📦",
                tags: [],
                location: closet,
                context: context,
                store: store
            )
        }
        return Result(
            primaryHomeID: DesignFixtureIDs.primaryHome,
            secondaryHomeID: nil,
            featuredItemID: DesignFixtureIDs.item(1)
        )
    }

    private static func seedEmptyHome(
        in context: NSManagedObjectContext,
        store: NSPersistentStore
    ) -> Result {
        let home = insertHome(
            id: DesignFixtureIDs.primaryHome,
            name: "Empty Home",
            context: context,
            store: store
        )
        _ = insertLocation(
            id: DesignFixtureIDs.primaryLocation,
            name: "Unsorted",
            home: home,
            parent: nil,
            depth: 0,
            context: context,
            store: store
        )
        return Result(
            primaryHomeID: DesignFixtureIDs.primaryHome,
            secondaryHomeID: nil,
            featuredItemID: nil
        )
    }

    private static func seedMissingPhoto(
        in context: NSManagedObjectContext,
        store: NSPersistentStore
    ) -> Result {
        let home = insertHome(
            id: DesignFixtureIDs.primaryHome,
            name: "Main Home",
            context: context,
            store: store
        )
        let closet = insertLocation(
            id: DesignFixtureIDs.primaryLocation,
            name: "Closet",
            home: home,
            parent: nil,
            depth: 0,
            context: context,
            store: store
        )
        insertItem(
            id: DesignFixtureIDs.missingPhotoItem,
            title: "Missing Photo Item",
            description: "Metadata synced, but the local photo file does not exist",
            emoji: "📷",
            photoFileName: "missing-local-photo.jpg",
            tags: ["photo"],
            location: closet,
            context: context,
            store: store
        )
        return Result(
            primaryHomeID: DesignFixtureIDs.primaryHome,
            secondaryHomeID: nil,
            featuredItemID: DesignFixtureIDs.missingPhotoItem
        )
    }

    @discardableResult
    private static func insertHome(
        id: UUID,
        name: String,
        context: NSManagedObjectContext,
        store: NSPersistentStore
    ) -> NSManagedObject {
        let home = NSEntityDescription.insertNewObject(forEntityName: "CDHome", into: context)
        context.assign(home, to: store)
        home.setValue(id, forKey: "id")
        home.setValue(name, forKey: "name")
        home.setValue(timestamp, forKey: "createdAt")
        home.setValue(timestamp, forKey: "modifiedAt")
        return home
    }

    @discardableResult
    private static func insertLocation(
        id: UUID,
        name: String,
        home: NSManagedObject,
        parent: NSManagedObject?,
        depth: Int16,
        context: NSManagedObjectContext,
        store: NSPersistentStore
    ) -> NSManagedObject {
        let location = NSEntityDescription.insertNewObject(
            forEntityName: "CDStorageLocation",
            into: context
        )
        context.assign(location, to: store)
        location.setValue(id, forKey: "id")
        location.setValue(name, forKey: "name")
        location.setValue(depth, forKey: "depth")
        location.setValue(timestamp, forKey: "createdAt")
        location.setValue(timestamp, forKey: "modifiedAt")
        location.setValue(home, forKey: "home")
        location.setValue(parent, forKey: "parentLocation")
        return location
    }

    private static func insertItem(
        id: UUID,
        title: String,
        description: String,
        emoji: String,
        photoFileName: String? = nil,
        tags: [String],
        location: NSManagedObject,
        context: NSManagedObjectContext,
        store: NSPersistentStore
    ) {
        let item = NSEntityDescription.insertNewObject(
            forEntityName: "CDInventoryItem",
            into: context
        )
        context.assign(item, to: store)
        item.setValue(id, forKey: "id")
        item.setValue(title, forKey: "title")
        item.setValue(description, forKey: "itemDescription")
        item.setValue(photoFileName, forKey: "photoFileName")
        item.setValue(emoji, forKey: "emoji")
        item.setValue(false, forKey: "isPendingAiEmoji")
        item.setValue(timestamp, forKey: "createdAt")
        item.setValue(timestamp, forKey: "modifiedAt")
        item.setValue(tags.sorted(), forKey: "tags")
        item.setValue(location, forKey: "storageLocation")
    }
}
#endif
