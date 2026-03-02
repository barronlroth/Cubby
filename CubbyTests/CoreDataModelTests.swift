import CoreData
import Foundation
import Testing
@testable import Cubby

@Suite("Core Data Model Tests")
struct CoreDataModelTests {
    private func makeManagedObjectModel() throws -> NSManagedObjectModel {
        let bundles = Bundle.allBundles + Bundle.allFrameworks
        if let model = NSManagedObjectModel.mergedModel(from: bundles),
           model.entitiesByName["CDHome"] != nil {
            return model
        }

        throw NSError(
            domain: "CoreDataModelTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to find compiled model containing CDHome."]
        )
    }

    private func makeInMemoryContainer() throws -> NSPersistentContainer {
        let model = try makeManagedObjectModel()
        let container = NSPersistentContainer(name: "Cubby", managedObjectModel: model)

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let loadError {
            throw loadError
        }

        return container
    }

    @discardableResult
    private func createHome(in context: NSManagedObjectContext, name: String = "Test Home") -> NSManagedObject {
        let home = NSEntityDescription.insertNewObject(forEntityName: "CDHome", into: context)
        home.setValue(UUID(), forKey: "id")
        home.setValue(name, forKey: "name")
        home.setValue(Date(), forKey: "createdAt")
        home.setValue(Date(), forKey: "modifiedAt")
        return home
    }

    @discardableResult
    private func createLocation(
        in context: NSManagedObjectContext,
        name: String = "Test Location",
        home: NSManagedObject,
        parentLocation: NSManagedObject? = nil
    ) -> NSManagedObject {
        let location = NSEntityDescription.insertNewObject(forEntityName: "CDStorageLocation", into: context)
        location.setValue(UUID(), forKey: "id")
        location.setValue(name, forKey: "name")
        location.setValue(Int16(0), forKey: "depth")
        location.setValue(Date(), forKey: "createdAt")
        location.setValue(Date(), forKey: "modifiedAt")
        location.setValue(home, forKey: "home")
        location.setValue(parentLocation, forKey: "parentLocation")
        return location
    }

    @discardableResult
    private func createItem(
        in context: NSManagedObjectContext,
        title: String = "Test Item",
        location: NSManagedObject
    ) -> NSManagedObject {
        let item = NSEntityDescription.insertNewObject(forEntityName: "CDInventoryItem", into: context)
        item.setValue(UUID(), forKey: "id")
        item.setValue(title, forKey: "title")
        item.setValue(false, forKey: "isPendingAiEmoji")
        item.setValue(Date(), forKey: "createdAt")
        item.setValue(Date(), forKey: "modifiedAt")
        item.setValue([String](), forKey: "tags")
        item.setValue(location, forKey: "storageLocation")
        return item
    }

    @Test
    func test_CDHome_canBeCreatedAndFetched() throws {
        let container = try makeInMemoryContainer()
        let context = container.viewContext

        _ = createHome(in: context, name: "Primary Home")
        try context.save()

        let request = NSFetchRequest<NSManagedObject>(entityName: "CDHome")
        let homes = try context.fetch(request)

        #expect(homes.count == 1)
        #expect(homes.first?.value(forKey: "name") as? String == "Primary Home")
    }

    @Test
    func test_CDStorageLocation_relationshipToHome() throws {
        let container = try makeInMemoryContainer()
        let context = container.viewContext

        let home = createHome(in: context)
        _ = createLocation(in: context, home: home)
        try context.save()

        let request = NSFetchRequest<NSManagedObject>(entityName: "CDStorageLocation")
        let locations = try context.fetch(request)
        let fetchedHome = locations.first?.value(forKey: "home") as? NSManagedObject

        #expect(locations.count == 1)
        #expect(fetchedHome?.value(forKey: "id") as? UUID == home.value(forKey: "id") as? UUID)
    }

    @Test
    func test_CDStorageLocation_parentChildRelationship() throws {
        let container = try makeInMemoryContainer()
        let context = container.viewContext

        let home = createHome(in: context)
        let parent = createLocation(in: context, name: "Parent", home: home)
        _ = createLocation(in: context, name: "Child", home: home, parentLocation: parent)
        try context.save()

        let request = NSFetchRequest<NSManagedObject>(entityName: "CDStorageLocation")
        request.predicate = NSPredicate(format: "name == %@", "Parent")
        let parents = try context.fetch(request)
        let children = parents.first?.value(forKey: "childLocations") as? NSSet

        #expect(parents.count == 1)
        #expect(children?.count == 1)
    }

    @Test
    func test_CDInventoryItem_relationshipToLocation() throws {
        let container = try makeInMemoryContainer()
        let context = container.viewContext

        let home = createHome(in: context)
        let location = createLocation(in: context, home: home)
        _ = createItem(in: context, location: location)
        try context.save()

        let request = NSFetchRequest<NSManagedObject>(entityName: "CDInventoryItem")
        let items = try context.fetch(request)
        let fetchedLocation = items.first?.value(forKey: "storageLocation") as? NSManagedObject

        #expect(items.count == 1)
        #expect(fetchedLocation?.value(forKey: "id") as? UUID == location.value(forKey: "id") as? UUID)
    }

    @Test
    func test_CDHome_cascadeDeleteRemovesLocations() throws {
        let container = try makeInMemoryContainer()
        let context = container.viewContext

        let home = createHome(in: context)
        _ = createLocation(in: context, home: home)
        try context.save()

        context.delete(home)
        try context.save()

        let request = NSFetchRequest<NSManagedObject>(entityName: "CDStorageLocation")
        let remainingLocations = try context.fetch(request)

        #expect(remainingLocations.isEmpty)
    }

    @Test
    func test_CDStorageLocation_denyDeleteWithItems() throws {
        let container = try makeInMemoryContainer()
        let context = container.viewContext

        let home = createHome(in: context)
        let location = createLocation(in: context, home: home)
        _ = createItem(in: context, location: location)
        try context.save()

        context.delete(location)

        do {
            try context.save()
            Issue.record("Expected deny delete rule to prevent deleting a location with items.")
        } catch {
            #expect(true)
        }
    }

    @Test
    func test_allEntities_haveUUIDIdentifiers() throws {
        let model = try makeManagedObjectModel()
        let entities = ["CDHome", "CDStorageLocation", "CDInventoryItem"]

        for entityName in entities {
            guard let entity = model.entitiesByName[entityName] else {
                Issue.record("Missing entity \(entityName)")
                continue
            }

            guard let idAttribute = entity.attributesByName["id"] else {
                Issue.record("Missing id attribute for \(entityName)")
                continue
            }

            #expect(idAttribute.attributeType == .UUIDAttributeType)
            #expect(idAttribute.isOptional == false)
        }
    }
}
