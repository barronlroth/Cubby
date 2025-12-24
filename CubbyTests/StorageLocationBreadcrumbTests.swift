import Testing
@testable import Cubby

struct StorageLocationBreadcrumbTests {
    @Test func testBreadcrumbLeafToRootOrder() {
        let home = Home(name: "Test Home")

        let root = StorageLocation(name: "Under My Bed", home: home)
        let parent = StorageLocation(name: "Travel Bags", home: home, parentLocation: root)
        let leaf = StorageLocation(name: "Treasure Chest", home: home, parentLocation: parent)

        #expect(leaf.breadcrumbComponentsLeafToRoot == ["Treasure Chest", "Travel Bags", "Under My Bed"])
        #expect(leaf.breadcrumbLeafToRoot() == "Treasure Chest → Travel Bags → Under My Bed")
    }
}

