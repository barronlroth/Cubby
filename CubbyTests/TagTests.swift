import Testing
import Foundation
@testable import Cubby

struct TagTests {
    @Test func testTagFormatting() {
        #expect("Hello World".formatAsTag() == "hello-world")
        #expect("Tech 2024!".formatAsTag() == "tech-2024")
        #expect("  spaces  ".formatAsTag() == "spaces")
        #expect("UPPERCASE".formatAsTag() == "uppercase")
        #expect("special!@#$%chars".formatAsTag() == "specialchars")
        #expect("already-formatted".formatAsTag() == "already-formatted")
        #expect("--leading-trailing--".formatAsTag() == "leading-trailing")
        #expect("123numbers456".formatAsTag() == "123numbers456")
    }
    
    @Test func testTagValidation() {
        #expect(TagValidator.isValid("tech") == true)
        #expect(TagValidator.isValid("") == false)
        #expect(TagValidator.isValid("a") == true)
        #expect(TagValidator.isValid(String(repeating: "a", count: 31)) == false)
        #expect(TagValidator.isValid(String(repeating: "a", count: 30)) == true)
        #expect(TagValidator.isValid("valid-tag-123") == true)
    }
    
    @Test func testTagLengthLimit() {
        let longString = String(repeating: "a", count: 50)
        let formatted = longString.formatAsTag()
        #expect(formatted.count == 30)
        #expect(formatted == String(repeating: "a", count: 30))
    }
    
    @Test func testTagDuplicatePrevention() {
        var tags: Set<String> = ["tech", "electronics"]
        
        tags.insert("tech")
        #expect(tags.count == 2)
        #expect(tags.contains("tech"))
        
        tags.insert("new-tag")
        #expect(tags.count == 3)
        #expect(tags.contains("new-tag"))
    }
    
    @Test func testTagMaxLimit() {
        var tags: Set<String> = []
        
        for i in 1...TagValidator.maxTags {
            tags.insert("tag-\(i)")
        }
        
        #expect(tags.count == TagValidator.maxTags)
        
        tags.insert("tag-11")
        #expect(tags.count == TagValidator.maxTags + 1)
    }
    
    @Test func testSortedTags() {
        let tags: Set<String> = ["zebra", "alpha", "middle", "beta"]
        let sorted = Array(tags).sorted()
        
        #expect(sorted == ["alpha", "beta", "middle", "zebra"])
    }
}