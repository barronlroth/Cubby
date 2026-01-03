import Testing
import SwiftData
@testable import Cubby

@Suite("Storage Location Tests")
struct StorageLocationTests {
    
    // MARK: - Test Container Setup
    
    @MainActor
    func createTestContainer() throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        
        return try ModelContainer(
            for: Home.self,
            StorageLocation.self,
            InventoryItem.self,
            configurations: modelConfiguration
        )
    }
    
    // MARK: - Nested Location Tests
    
    @Test("Create nested storage location")
    @MainActor
    func testCreateNestedLocation() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        // Create home
        let home = Home(name: "Test Home")
        context.insert(home)
        
        // Create parent location
        let parentLocation = StorageLocation(name: "Bedroom", home: home)
        context.insert(parentLocation)
        
        // Create child location
        let childLocation = StorageLocation(name: "Closet", home: home, parentLocation: parentLocation)
        context.insert(childLocation)
        
        // Save context
        try context.save()
        
        // Verify parent has child
        #expect(parentLocation.childLocations?.count == 1)
        #expect(parentLocation.childLocations?.first?.name == "Closet")
        
        // Verify child has parent
        #expect(childLocation.parentLocation?.name == "Bedroom")
        
        // Verify depth calculation
        #expect(parentLocation.depth == 0)
        #expect(childLocation.depth == 1)
        
        // Verify full path
        #expect(childLocation.fullPath == "Bedroom > Closet")
    }
    
    @Test("Create deeply nested locations")
    @MainActor
    func testDeeplyNestedLocations() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        // Create home
        let home = Home(name: "Test Home")
        context.insert(home)
        
        // Create nested hierarchy
        let level1 = StorageLocation(name: "Level 1", home: home)
        let level2 = StorageLocation(name: "Level 2", home: home, parentLocation: level1)
        let level3 = StorageLocation(name: "Level 3", home: home, parentLocation: level2)
        
        context.insert(level1)
        context.insert(level2)
        context.insert(level3)
        
        try context.save()
        
        // Verify hierarchy
        #expect(level1.childLocations?.count == 1)
        #expect(level2.childLocations?.count == 1)
        #expect(level3.childLocations?.count == 0)
        
        // Verify parents
        #expect(level2.parentLocation?.id == level1.id)
        #expect(level3.parentLocation?.id == level2.id)
        
        // Verify depths
        #expect(level1.depth == 0)
        #expect(level2.depth == 1)
        #expect(level3.depth == 2)
        
        // Verify full path
        #expect(level3.fullPath == "Level 1 > Level 2 > Level 3")
    }
    
    @Test("Fetch nested locations after save")
    @MainActor
    func testFetchNestedLocationsAfterSave() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        // Create home and locations
        let home = Home(name: "Test Home")
        context.insert(home)
        
        let parent = StorageLocation(name: "Parent", home: home)
        let child1 = StorageLocation(name: "Child 1", home: home, parentLocation: parent)
        let child2 = StorageLocation(name: "Child 2", home: home, parentLocation: parent)
        
        context.insert(parent)
        context.insert(child1)
        context.insert(child2)
        
        try context.save()
        
        // Fetch parent location
        let fetchedLocations = try context.fetch(FetchDescriptor<StorageLocation>())
            .filter { $0.name == "Parent" && $0.parentLocation == nil }
        #expect(fetchedLocations.count == 1)
        
        let fetchedParent = fetchedLocations.first!
        #expect(fetchedParent.childLocations?.count == 2)
        
        let childNames = fetchedParent.childLocations?.map { $0.name }.sorted()
        #expect(childNames == ["Child 1", "Child 2"])
    }
    
    @Test("Prevent deletion of location with children")
    @MainActor
    func testPreventDeletionWithChildren() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let home = Home(name: "Test Home")
        let parent = StorageLocation(name: "Parent", home: home)
        let child = StorageLocation(name: "Child", home: home, parentLocation: parent)
        
        context.insert(home)
        context.insert(parent)
        context.insert(child)
        
        try context.save()
        
        // Parent should not be deletable
        #expect(parent.canDelete == false)
        
        // Child should be deletable
        #expect(child.canDelete == true)
    }
    
    @Test("Prevent deletion of location with items")
    @MainActor
    func testPreventDeletionWithItems() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let home = Home(name: "Test Home")
        let location = StorageLocation(name: "Location", home: home)
        let item = InventoryItem(title: "Test Item", storageLocation: location)
        
        context.insert(home)
        context.insert(location)
        context.insert(item)
        
        try context.save()
        
        // Location should not be deletable
        #expect(location.canDelete == false)
    }
    
    @Test("Validate unique names at same level")
    @MainActor
    func testUniqueNamesAtSameLevel() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let home = Home(name: "Test Home")
        let parent = StorageLocation(name: "Parent", home: home)
        let child1 = StorageLocation(name: "Child", home: home, parentLocation: parent)
        
        context.insert(home)
        context.insert(parent)
        context.insert(child1)
        
        try context.save()
        
        // Should not allow duplicate name at same level
        let siblings = parent.childLocations ?? []
        let hasDuplicate = siblings.contains { $0.name.lowercased() == "child" }
        #expect(hasDuplicate == true)
    }
    
    @Test("Prevent circular references")
    @MainActor
    func testPreventCircularReferences() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let home = Home(name: "Test Home")
        let parent = StorageLocation(name: "Parent", home: home)
        let child = StorageLocation(name: "Child", home: home, parentLocation: parent)
        let grandchild = StorageLocation(name: "Grandchild", home: home, parentLocation: child)
        
        context.insert(home)
        context.insert(parent)
        context.insert(child)
        context.insert(grandchild)
        
        try context.save()
        
        // Parent cannot move to child
        #expect(parent.canMoveTo(child) == false)
        
        // Parent cannot move to grandchild
        #expect(parent.canMoveTo(grandchild) == false)
        
        // Child cannot move to grandchild
        #expect(child.canMoveTo(grandchild) == false)
        
        // Grandchild can move to parent
        #expect(grandchild.canMoveTo(parent) == true)
    }
    
    @Test("Maximum nesting depth enforcement")
    @MainActor
    func testMaximumNestingDepth() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let home = Home(name: "Test Home")
        context.insert(home)
        
        var currentParent: StorageLocation? = nil
        
        // Create locations up to max depth
        for i in 0..<StorageLocation.maxNestingDepth {
            let location = StorageLocation(
                name: "Level \(i)",
                home: home,
                parentLocation: currentParent
            )
            context.insert(location)
            currentParent = location
        }
        
        try context.save()
        
        // Verify the deepest location has correct depth
        #expect(currentParent?.depth == StorageLocation.maxNestingDepth - 1)
        
        // Should not allow creating beyond max depth
        let tooDeep = StorageLocation(
            name: "Too Deep",
            home: home,
            parentLocation: currentParent
        )
        #expect(tooDeep.depth == StorageLocation.maxNestingDepth)
    }
}
