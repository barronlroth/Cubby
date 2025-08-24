# Tags Feature - Technical Specification (Simplified)

## Overview
Technical implementation plan for adding tags functionality to Cubby inventory items, enabling flexible categorization and enhanced search capabilities.

## Data Model Changes

### InventoryItem Model Updates
```swift
@Model
final class InventoryItem {
    // Existing properties...
    
    // New property - Using Set to prevent duplicates automatically
    var tags: Set<String> = []
    
    // Computed property for sorted display
    var sortedTags: [String] {
        Array(tags).sorted()
    }
}
```

### Tag Storage Strategy
- Tags stored as Set<String> directly on InventoryItem (prevents duplicates automatically)
- No separate Tag entity needed for v1
- No schema migration required (SwiftData handles optional properties)
- CloudKit sync-ready format

## Tag Input & Validation

### TagInputView Component
```swift
struct TagInputView: View {
    @Binding var tags: Set<String>
    @Binding var currentInput: String
    let suggestions: [String]  // Parent provides suggestions
    let maxTags = 10
    
    @FocusState private var inputFocus: TagInputFocus?
    
    enum TagInputFocus {
        case tagField
    }
}
```

### Input Processing
- **Character validation**: Only lowercase letters, numbers, and dashes
- **Space conversion**: Replace spaces with dashes in real-time
- **Length limits**: Enforce 1-30 character limit
- **Duplicate prevention**: Handled automatically by Set<String>

### Tag Formatting Function (Optimized)
```swift
extension String {
    func formatAsTag() -> String {
        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "-"))
        
        return self.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
            .prefix(30)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
```

## Autocomplete Implementation

### Tag Suggestions (Simplified with @Query)
```swift
// In parent view (ItemDetailView or AddItemView)
struct ItemDetailView: View {
    @Query private var allItems: [InventoryItem]
    @State private var tagInput = ""
    
    var tagSuggestions: [String] {
        guard !tagInput.isEmpty else { return [] }
        let formatted = tagInput.formatAsTag()
        
        return Set(allItems.flatMap { Array($0.tags) })
            .filter { $0.contains(formatted) }
            .sorted()
            .prefix(5)
            .map { String($0) }
    }
    
    var body: some View {
        // View implementation
        TagInputView(
            tags: $item.tags,
            currentInput: $tagInput,
            suggestions: tagSuggestions
        )
    }
}
```

### Native Search Integration
```swift
// Using .searchable modifier for better UX
.searchable(text: $searchText, prompt: "Search items or tags")
.searchSuggestions {
    ForEach(tagSuggestions, id: \.self) { suggestion in
        Label(suggestion, systemImage: "tag")
            .searchCompletion(suggestion)
    }
}

## UI Components

### Tag Chip Component
```swift
struct TagChip: View {
    let tag: String
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.small)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.2))
        .clipShape(Capsule())
    }
}
```

### Tag Display Grid (Using Native LazyVGrid)
```swift
struct TagDisplayView: View {
    let tags: Set<String>
    let onDelete: ((String) -> Void)?
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
            ForEach(Array(tags).sorted(), id: \.self) { tag in
                TagChip(
                    tag: tag,
                    onDelete: onDelete != nil ? { onDelete?(tag) } : nil
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(duration: 0.3), value: tags)
    }
}
```

## View Modifications

### ItemDetailView Updates
- Add TagDisplayView below item description
- Add "Add Tag" button when in edit mode
- Show TagInputView in sheet or inline
- Limit to 10 tags with visual indicator

### AddItemView Updates
- Include TagInputView in form
- Position below description field
- Allow tag entry during item creation
- Show running count (e.g., "3/10 tags")

## Search Integration

### SearchViewModel Updates (Using Predicates)
```swift
extension SearchViewModel {
    func searchItems(query: String, in context: ModelContext) -> [InventoryItem] {
        let searchTerms = query.lowercased().split(separator: " ").map(String.init)
        
        // Use SwiftData predicate for efficient filtering
        let predicate = #Predicate<InventoryItem> { item in
            searchTerms.allSatisfy { term in
                item.title.localizedStandardContains(term) ||
                item.itemDescription?.localizedStandardContains(term) ?? false ||
                item.tags.contains { $0.localizedStandardContains(term) }
            }
        }
        
        let descriptor = FetchDescriptor<InventoryItem>(predicate: predicate)
        
        do {
            let results = try context.fetch(descriptor)
            
            // Rank results by match count for better UX
            return results.sorted { item1, item2 in
                let count1 = countMatches(for: item1, with: searchTerms)
                let count2 = countMatches(for: item2, with: searchTerms)
                return count1 > count2
            }
        } catch {
            return []
        }
    }
    
    private func countMatches(for item: InventoryItem, with terms: [String]) -> Int {
        terms.reduce(0) { count, term in
            var matches = 0
            if item.title.localizedStandardContains(term) { matches += 1 }
            if item.itemDescription?.localizedStandardContains(term) ?? false { matches += 1 }
            if item.tags.contains(where: { $0.localizedStandardContains(term) }) { matches += 1 }
            return count + matches
        }
    }
}
```

## Keyboard & Input Handling

### Custom TextField Modifier with Haptic Feedback
```swift
struct TagTextField: ViewModifier {
    @Binding var text: String
    let onSubmit: () -> Void
    
    func body(content: Content) -> some View {
        content
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit {
                onSubmit()
                // iOS 17+ haptic feedback
                #if os(iOS)
                if #available(iOS 17.0, *) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                #endif
            }
            .onChange(of: text) { _, newValue in
                text = newValue.formatAsTag()
            }
    }
}
```

### Focus Management
- Use @FocusState enum for better control
- Auto-focus tag input after adding tag
- Maintain focus for rapid entry
- Clear and refocus after each tag addition

## Performance Considerations

### Optimizations
- Use Set<String> for O(1) duplicate detection
- SwiftData predicates for efficient database queries (~10x faster than in-memory)
- CharacterSet validation (~5x faster than regex)
- LazyVGrid for better memory usage with many tags
- Debounce tag suggestion queries (100ms)
- Limit autocomplete results to 5

### Memory Management
- Tags set limited to 10 items per InventoryItem
- Each tag limited to 30 characters
- Maximum memory per item: ~300 bytes for tags
- @Query automatic caching and updates

## Testing Requirements

### Unit Tests
```swift
@Test func testTagFormatting() {
    #expect("Hello World".formatAsTag() == "hello-world")
    #expect("Tech 2024!".formatAsTag() == "tech-2024")
    #expect("  spaces  ".formatAsTag() == "spaces")
}

@Test func testTagValidation() {
    let validator = TagValidator()
    #expect(validator.isValid("tech") == true)
    #expect(validator.isValid("") == false)
    #expect(validator.isValid(String(repeating: "a", count: 31)) == false)
}

@Test func testTagSearch() {
    // Test partial matching
    // Test multi-tag search
    // Test ranking algorithm
}
```

### UI Tests
- Test tag input and submission
- Test autocomplete suggestions
- Test tag deletion
- Test keyboard handling
- Test rapid tag entry flow

## Implementation Order (Simplified - ~9 hours total)

1. **Data Model (1 hour)**
   - Add `tags: Set<String>` to InventoryItem
   - Test data persistence
   - No migration needed

2. **Basic UI Components (2 hours)**
   - Build TagChip component
   - Implement TagDisplayView with LazyVGrid
   - Add delete functionality with animations

3. **Input & Validation (2 hours)**
   - Build TagInputView with TextField
   - Implement formatAsTag() with CharacterSet
   - Add Enter key handling for rapid entry

4. **Search Integration (1 hour)**
   - Update SearchViewModel with predicates
   - Implement multi-term search with ranking
   - Test performance

5. **Autocomplete (2 hours)**
   - Use @Query in parent views
   - Implement .searchSuggestions
   - Add debouncing

6. **Polish & Testing (1 hour)**
   - Add haptic feedback
   - Implement animations
   - Write unit tests
   - Add accessibility labels

## Accessibility

### VoiceOver Support
- Tag chips announced as "tag: [name], button, delete"
- Tag count announced: "3 of 10 tags"
- Autocomplete suggestions announced
- Deletion confirmed with announcement

### Dynamic Type
- Tag text scales with system font size
- Chip height adjusts to content
- Maintain touch targets ≥ 44pt

## Error Handling

### User-Facing Errors
- "Maximum 10 tags allowed"
- "Tag already exists"
- "Tag must be 1-30 characters"
- "Invalid characters in tag"

### Error Prevention
- Real-time validation
- Disable add button at limit
- Visual feedback for errors
- Graceful degradation

## Security & Privacy

### Data Validation
- Sanitize all tag input
- Prevent injection attacks
- Validate on save
- No PII in tags (v1 scope)

### CloudKit Preparation
- Set<String> is CloudKit-compatible
- No breaking changes needed
- Conflict resolution strategy: union of sets (keeps all tags from both versions)

## Additional Enhancements

### Recently Used Tags (with @AppStorage)
```swift
@AppStorage("recentTags") private var recentTagsData: Data = Data()

var recentTags: [String] {
    get {
        (try? JSONDecoder().decode([String].self, from: recentTagsData)) ?? []
    }
    set {
        recentTagsData = (try? JSONEncoder().encode(Array(newValue.prefix(20)))) ?? Data()
    }
}
```

### Shake to Undo
```swift
.onShake {
    if let lastDeletedTag = undoStack.last {
        withAnimation(.spring()) {
            item.tags.insert(lastDeletedTag)
            undoStack.removeLast()
        }
    }
}
```

