# Technical Specification: Home Inventory App

## Executive Summary

This document provides a comprehensive technical specification for building a home inventory iOS application using SwiftUI and SwiftData. The app allows users to catalog their belongings across multiple homes with a hierarchical storage location system. This specification is designed for a developer with no prior context of the project.

## Architecture Overview

### Technology Stack
- **UI Framework**: SwiftUI (iOS 17.0+)
- **Data Persistence**: SwiftData with VersionedSchema
- **Navigation**: NavigationSplitView (adaptive for iPhone/iPad)
- **Image Storage**: Local Documents directory with JPEG compression
- **Image Caching**: NSCache-based LRU with 50MB limit
- **Minimum iOS Version**: iOS 17.0
- **Device Support**: Universal (iPhone and iPad adaptive)

### Architecture Pattern
- **MVVM-lite**: Views backed by SwiftData `@Query` and `@Model` objects
- **SwiftData models serve as ViewModels** for simple CRUD operations
- **Dedicated ViewModels required for**:
  - Search operations with multiple filters
  - Moving items between locations (transaction handling)
  - Bulk operations (future V2)
  - Complex validation logic
  - Any operation requiring multiple model updates

### Project Structure
```
Cubby/
├── Models/
│   ├── Home.swift
│   ├── StorageLocation.swift
│   └── InventoryItem.swift
├── Views/
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── StorageLocationRow.swift
│   │   └── StorageLocationPicker.swift
│   ├── Items/
│   │   ├── AddItemView.swift
│   │   ├── ItemDetailView.swift
│   │   └── ItemRow.swift
│   └── Search/
│       └── SearchView.swift
├── Services/
│   ├── PhotoService.swift
│   └── DataCleanupService.swift
├── ViewModels/
│   ├── SearchViewModel.swift
│   └── ItemManagementViewModel.swift
├── Utils/
│   ├── Extensions.swift
│   └── ValidationHelpers.swift
└── CubbyApp.swift
```

## Data Models

### 1. Home Model
```swift
@Model
class Home {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    
    // Computed property for all storage locations in this home
    @Relationship(deleteRule: .cascade, inverse: \StorageLocation.home)
    var storageLocations: [StorageLocation]? = []
    
    init(name: String) {
        self.name = name
    }
}
```

### 2. StorageLocation Model
```swift
@Model
class StorageLocation {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var depth: Int = 0 // Track nesting depth for performance
    
    // Bidirectional relationships for proper SwiftData management
    var home: Home?
    
    @Relationship(inverse: \StorageLocation.childLocations)
    var parentLocation: StorageLocation?
    
    @Relationship(deleteRule: .deny, inverse: \StorageLocation.parentLocation)
    var childLocations: [StorageLocation]? = []
    
    // Items stored directly in this location
    @Relationship(deleteRule: .deny, inverse: \InventoryItem.storageLocation)
    var items: [InventoryItem]? = []
    
    // Helper to build full path (e.g., "Bedroom > Closet > Top Shelf")
    var fullPath: String {
        var path = [String]()
        var current: StorageLocation? = self
        while let location = current {
            path.insert(location.name, at: 0)
            current = location.parentLocation
        }
        return path.joined(separator: " > ")
    }
    
    // Check if location can be deleted (must have no items and no child locations)
    var canDelete: Bool {
        (items?.isEmpty ?? true) && (childLocations?.isEmpty ?? true)
    }
    
    // Prevent circular references
    func canMoveTo(_ targetLocation: StorageLocation?) -> Bool {
        guard let target = targetLocation else { return true }
        
        // Can't move to self
        if target.id == self.id { return false }
        
        // Can't move to own descendant
        var current = target.parentLocation
        while current != nil {
            if current?.id == self.id { return false }
            current = current?.parentLocation
        }
        return true
    }
    
    init(name: String, home: Home, parentLocation: StorageLocation? = nil) {
        self.name = name
        self.home = home
        self.parentLocation = parentLocation
        self.depth = (parentLocation?.depth ?? -1) + 1
    }
    
    static let maxNestingDepth = 10 // Performance limit
}
```

### 3. InventoryItem Model
```swift
@Model
class InventoryItem {
    var id: UUID = UUID()
    var title: String
    var itemDescription: String?
    var photoFileName: String? // Stored in Documents/ItemPhotos/
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    
    var storageLocation: StorageLocation?
    
    // Photo is loaded asynchronously via PhotoService
    // Use AsyncImage in views or @State for caching
    
    init(title: String, description: String? = nil, storageLocation: StorageLocation) {
        self.title = title
        self.itemDescription = description
        self.storageLocation = storageLocation
    }
}
```

## Service Layer

### PhotoService
```swift
protocol PhotoServiceProtocol {
    func savePhoto(_ image: UIImage) async throws -> String
    func loadPhoto(fileName: String) async -> UIImage?
    func deletePhoto(fileName: String) async
    func clearCache()
}

class PhotoService: PhotoServiceProtocol {
    static let shared = PhotoService()
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let photosDirectory: URL
    
    // NSCache for LRU image caching
    private let imageCache = NSCache<NSString, UIImage>()
    private let maxCacheSize = 50 * 1024 * 1024 // 50MB limit
    
    init() {
        photosDirectory = documentsDirectory.appendingPathComponent("ItemPhotos")
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        
        // Configure cache
        imageCache.totalCostLimit = maxCacheSize
        imageCache.countLimit = 100 // Max 100 images cached
    }
    
    func savePhoto(_ image: UIImage) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        
        // Compress to 70% quality
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw PhotoError.compressionFailed
        }
        
        try await Task.detached(priority: .background) {
            try data.write(to: fileURL)
        }.value
        
        // Cache the image
        imageCache.setObject(image, forKey: fileName as NSString, cost: data.count)
        
        return fileName
    }
    
    func loadPhoto(fileName: String) async -> UIImage? {
        // Check cache first
        if let cachedImage = imageCache.object(forKey: fileName as NSString) {
            return cachedImage
        }
        
        // Load from disk
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        
        return await Task.detached(priority: .background) {
            guard let data = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: data) else { return nil }
            
            // Add to cache
            self.imageCache.setObject(image, forKey: fileName as NSString, cost: data.count)
            return image
        }.value
    }
    
    func deletePhoto(fileName: String) async {
        // Remove from cache
        imageCache.removeObject(forKey: fileName as NSString)
        
        // Delete from disk
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func clearCache() {
        imageCache.removeAllObjects()
    }
}

enum PhotoError: Error {
    case compressionFailed
    case saveFailed
}
```

### DataCleanupService
```swift
class DataCleanupService {
    static let shared = DataCleanupService()
    
    func performCleanup(modelContext: ModelContext) async {
        await cleanupOrphanedPhotos(modelContext: modelContext)
    }
    
    private func cleanupOrphanedPhotos(modelContext: ModelContext) async {
        // Get all photo filenames from items
        let descriptor = FetchDescriptor<InventoryItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return }
        
        let activePhotoNames = Set(items.compactMap { $0.photoFileName })
        
        // Get all photos in directory
        let photosURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ItemPhotos")
        
        guard let photoFiles = try? FileManager.default.contentsOfDirectory(at: photosURL, includingPropertiesForKeys: nil) else { return }
        
        // Delete orphaned photos
        for photoURL in photoFiles {
            let fileName = photoURL.lastPathComponent
            if !activePhotoNames.contains(fileName) {
                try? FileManager.default.removeItem(at: photoURL)
            }
        }
    }
}
```

## UI Specifications

### 1. App Entry Point (CubbyApp.swift)
```swift
@main
struct CubbyApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var modelContainer: ModelContainer?
    
    init() {
        // Set up versioned schema for future migrations
        do {
            let schema = Schema([
                Home.self,
                StorageLocation.self,
                InventoryItem.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainNavigationView()
                } else {
                    OnboardingView()
                }
            }
            .modelContainer(modelContainer!)
            .task {
                // Run cleanup on app launch
                await DataCleanupService.shared.performCleanup(
                    modelContext: modelContainer!.mainContext
                )
            }
        }
    }
}
```

### 2. Onboarding View
**Purpose**: First-time setup to create initial home

**UI Elements**:
- Welcome title: "Welcome to Cubby"
- Subtitle: "Let's set up your first home"
- Text field for home name
- "Get Started" button (disabled until name entered)

**Behavior**:
- Validates non-empty home name
- Creates first Home object
- Creates default "Unsorted" storage location for the home
- Sets `hasCompletedOnboarding` to true
- Navigates to HomeView

### 3. Home View (Main Screen)
**Purpose**: Primary interface showing storage locations and items

**UI Structure**:
```swift
NavigationSplitView {
    // Sidebar (iPhone: primary view, iPad: persistent sidebar)
    List {
        ForEach(rootStorageLocations) { location in
            OutlineGroup(location, children: \.childLocations) { loc in
                StorageLocationRow(location: loc)
            }
        }
    }
    .navigationTitle(currentHome.name)
    .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
            HomePicker(currentHome: $currentHome)
        }
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Add Location", systemImage: "folder.badge.plus") {
                // Add root location
            }
        }
    }
} detail: {
    // Detail view (selected location's items or empty state)
    if let selectedLocation {
        LocationDetailView(location: selectedLocation)
    } else {
        Text("Select a location")
            .foregroundStyle(.secondary)
    }
}
.overlay(alignment: .bottomTrailing) {
    // Floating Add Item Button
    AddItemFloatingButton()
        .padding()
}
.overlay(alignment: .top) {
    // Floating Search Pill
    SearchPillButton()
        .padding(.top, 8)
}
```

**Performance Optimizations**:
- Lazy loading for locations with > 50 child locations
- Maximum nesting depth of 10 levels enforced
- Cached expand/collapse states using @AppStorage

**Home Picker**:
- Dropdown picker in navigation bar
- Shows current home name
- Menu lists all homes + "Add New Home" option

**Storage Location Row**:
- Disclosure indicator for expandable locations
- Location name
- Item count badge
- Swipe actions: "Add Nested Location", "Delete" (if empty)
- Tap to view location details

**Empty State**:
- Illustration/icon
- Text: "No storage locations yet"
- "Add your first location" button

**Floating Search Pill**:
- Rounded rectangle button with search icon
- Sits below navigation bar
- Taps to present SearchView as sheet

**Floating Add Button**:
- Circular button with + icon
- Bottom-right corner
- Primary action color
- Presents AddItemView as sheet

### 4. Add Item View
**Purpose**: Form to create new inventory item

**UI Structure**:
```swift
NavigationStack {
    Form {
        Section("Item Details") {
            TextField("Title", text: $title)
            TextField("Description", text: $description, axis: .vertical)
        }
        
        Section("Location") {
            NavigationLink {
                StorageLocationPicker(selectedLocation: $selectedLocation)
            } label: {
                HStack {
                    Text("Storage Location")
                    Spacer()
                    Text(selectedLocation?.fullPath ?? "Select")
                        .foregroundColor(.secondary)
                }
            }
        }
        
        Section("Photo") {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                
                Button("Remove Photo", role: .destructive) {
                    selectedImage = nil
                }
            } else {
                Button("Add Photo") {
                    showingImagePicker = true
                }
            }
        }
    }
    .navigationTitle("Add Item")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { saveItem() }
                .disabled(title.isEmpty || selectedLocation == nil)
        }
    }
}
```

**Validation**:
- Title is required (non-empty)
- Storage location is required
- Save button disabled until requirements met

### 5. Storage Location Picker
**Purpose**: Hierarchical picker for selecting/creating storage locations

**UI Structure**:
- List showing all locations in selected home
- Indentation to show hierarchy
- Search bar to filter locations
- "Create New Location" button at top
- Tapping location selects it and dismisses

**Create New Location Flow**:
- Text field for location name
- Optional parent location picker
- Creates location and auto-selects it

### 6. Search View
**Purpose**: Full-screen search interface with optimized performance

**Implementation**: Uses dedicated SearchViewModel
```swift
@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedHome: Home?
    @Published var searchResults: [InventoryItem] = []
    
    private var searchTask: Task<Void, Never>?
    private let modelContext: ModelContext
    
    func performSearch() {
        // Cancel previous search
        searchTask?.cancel()
        
        // Debounce search by 300ms
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard !Task.isCancelled else { return }
            
            let searchTerm = searchText.lowercased()
            if searchTerm.isEmpty {
                searchResults = []
                return
            }
            
            // Use SwiftData predicate for efficient search
            var predicate = #Predicate<InventoryItem> { item in
                item.title.localizedStandardContains(searchTerm) ||
                (item.itemDescription != nil && 
                 item.itemDescription!.localizedStandardContains(searchTerm))
            }
            
            if let home = selectedHome {
                predicate = #Predicate<InventoryItem> { item in
                    item.storageLocation?.home?.id == home.id &&
                    (item.title.localizedStandardContains(searchTerm) ||
                     (item.itemDescription != nil && 
                      item.itemDescription!.localizedStandardContains(searchTerm)))
                }
            }
            
            let descriptor = FetchDescriptor<InventoryItem>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
            )
            
            searchResults = (try? modelContext.fetch(descriptor)) ?? []
        }
    }
}
```

**Performance Targets**:
- Search returns in < 100ms for 1,000 items
- < 500ms for 10,000 items
- Debounced at 300ms to prevent excessive queries

### 7. Item Detail View
**Purpose**: View and edit individual item

**UI Elements**:
- Photo (if exists)
- Title (editable)
- Description (editable)
- Storage location with full path
- "Move Item" button
- "Delete Item" button
- Created/Modified dates

## Implementation Epics

### Epic 1: Project Setup & Data Layer
**Goal**: Establish foundation with SwiftData models and services

**Tasks**:
1. **Configure SwiftData Schema** (2 hours)
   - Set up modelContainer with all three models
   - Define relationships and delete rules
   - Add computed properties for hierarchy

2. **Implement PhotoService** (2 hours)
   - Create Documents/ItemPhotos directory
   - Implement save with compression
   - Implement load and delete methods
   - Handle errors gracefully

3. **Create Mock Data Generator** (1 hour)
   - Generate sample homes, locations, items for testing
   - Add to debug menu

### Epic 2: Onboarding & Home Management
**Goal**: Allow users to set up and manage homes

**Tasks**:
1. **Build OnboardingView** (2 hours)
   - Create welcome UI
   - Implement home name input
   - Save first home to SwiftData
   - Set onboarding completion flag

2. **Implement Home Picker** (2 hours)
   - Create dropdown picker component
   - Query all homes from SwiftData
   - Handle home switching
   - Implement "Add New Home" flow

3. **Create Home Management** (1 hour)
   - Edit home name
   - Delete home (with cascade to locations/items)
   - Handle edge cases (can't delete last home)

### Epic 3: Storage Location System
**Goal**: Implement hierarchical storage location management

**Tasks**:
1. **Build StorageLocationRow Component** (3 hours)
   - Display location name and item count
   - Implement disclosure for children
   - Add swipe actions
   - Handle indentation for hierarchy

2. **Implement OutlineGroup Integration** (2 hours)
   - Set up data source with parent-child relationships
   - Handle expand/collapse state
   - Implement proper indentation

3. **Create Add Location Flow** (2 hours)
   - Build location creation form
   - Implement parent location picker
   - Validate unique names within parent
   - Save to SwiftData

4. **Implement Location Deletion** (2 hours)
   - Check for items and child locations
   - Show appropriate error messages
   - Implement confirmation dialog

5. **Build Location Detail View** (1 hour)
   - Show all items in location
   - Display child locations
   - Edit location name

### Epic 4: Item Management
**Goal**: Complete CRUD operations for inventory items

**Tasks**:
1. **Build AddItemView Form** (3 hours)
   - Create multi-section form
   - Implement text inputs
   - Add form validation
   - Handle save operation

2. **Implement StorageLocationPicker** (3 hours)
   - Build hierarchical location picker
   - Add search/filter capability
   - Implement "Create New" inline
   - Show full path for each location

3. **Create Image Picker Integration** (2 hours)
   - Integrate PhotosUI picker
   - Handle image selection
   - Compress and save using PhotoService
   - Display selected image

4. **Build ItemDetailView** (2 hours)
   - Display all item properties
   - Implement inline editing
   - Add move item functionality
   - Implement delete with photo cleanup

5. **Create ItemRow Component** (1 hour)
   - Show thumbnail if photo exists
   - Display title and location
   - Handle tap to detail view

### Epic 5: Search & Discovery
**Goal**: Enable users to quickly find items

**Tasks**:
1. **Build Search UI** (2 hours)
   - Create floating search pill button
   - Implement expandable search view
   - Auto-focus search field
   - Add clear button

2. **Implement Search Logic** (2 hours)
   - Query items across all homes
   - Search in title and description
   - Implement home filter
   - Sort by relevance/date

3. **Create Search Results View** (1 hour)
   - Display items with location path
   - Show home name if multiple homes
   - Navigate to item detail on tap

4. **Add Search Optimizations** (1 hour)
   - Debounce search input
   - Cache recent searches
   - Optimize SwiftData queries

### Epic 6: Empty States & Polish
**Goal**: Improve UX with guided empty states and polish

**Tasks**:
1. **Design Empty State Components** (2 hours)
   - Create reusable EmptyStateView
   - Add appropriate icons/illustrations
   - Write contextual copy
   - Add action buttons

2. **Implement Empty States** (1 hour)
   - No homes state
   - No storage locations state
   - No items in location state
   - No search results state

3. **Add Loading States** (1 hour)
   - Show spinners during data fetch
   - Implement skeleton screens
   - Handle slow operations

4. **Polish Animations** (2 hours)
   - Add view transitions
   - Implement smooth expand/collapse
   - Add haptic feedback
   - Polish floating button animations

### Epic 7: Error Handling & Edge Cases
**Goal**: Handle all error scenarios gracefully

**Tasks**:
1. **Implement Error Handling** (2 hours)
   - Photo save failures
   - SwiftData errors
   - Invalid data states
   - Show user-friendly error messages

2. **Handle Edge Cases** (2 hours)
   - Very long names (truncation)
   - Deep nesting (performance)
   - Large photo handling
   - Circular references prevention

3. **Add Data Validation** (1 hour)
   - Validate all user inputs
   - Prevent duplicate names at same level
   - Ensure required fields

## Technical Considerations

### Performance Optimizations
1. **Lazy Loading**: Use SwiftData's lazy loading for large datasets
2. **Image Caching**: NSCache with 50MB limit, 100 image max count
3. **Search Debouncing**: 300ms delay before executing search
4. **Pagination**: Load items in chunks if location has >50 items
5. **Nesting Depth**: Maximum 10 levels to prevent performance degradation
6. **Target Scale**: Support 10,000+ items with responsive UI

### Data Integrity & Validation

#### Validation Rules
```swift
struct ValidationHelpers {
    static func validateLocationName(_ name: String, in parent: StorageLocation?, home: Home) -> ValidationResult {
        // Check empty
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure("Location name cannot be empty")
        }
        
        // Check duplicates at same level
        let siblings = parent?.childLocations ?? home.storageLocations
        let isDuplicate = siblings?.contains { $0.name.lowercased() == name.lowercased() } ?? false
        
        if isDuplicate {
            return .failure("A location with this name already exists at this level")
        }
        
        return .success
    }
    
    static func validateNestingDepth(_ parent: StorageLocation?) -> Bool {
        guard let parent else { return true }
        return parent.depth < StorageLocation.maxNestingDepth - 1
    }
}
```

#### Transaction Handling
1. **Item Creation with Photo**: Rollback item if photo save fails
2. **Bulk Operations**: Use ModelContext transactions for atomicity
3. **Cascade Deletes**: Handled automatically by SwiftData relationships
4. **Move Operations**: Validate circular references before committing

### UI/UX Guidelines
1. **Typography**: Use Dynamic Type for accessibility
2. **Colors**: Respect system light/dark mode
3. **Haptics**: Light impact for actions, success for saves
4. **Keyboard**: Dismiss on scroll, proper keyboard avoidance
5. **Empty States**: Every empty view has guidance text and action button
6. **Loading States**: Show progress indicators for operations > 500ms

### Undo/Redo Support

#### Implementation for Delete Operations
```swift
struct UndoManager {
    private var deletedItems: [(item: InventoryItem, locationId: UUID)] = []
    private let maxUndoItems = 10
    
    mutating func recordDeletion(item: InventoryItem) {
        deletedItems.append((item, item.storageLocation?.id ?? UUID()))
        if deletedItems.count > maxUndoItems {
            deletedItems.removeFirst()
        }
    }
    
    func canUndo() -> Bool {
        !deletedItems.isEmpty
    }
    
    mutating func undo(in context: ModelContext) -> Bool {
        guard let lastDeleted = deletedItems.popLast() else { return false }
        
        // Recreate item and reassign to location
        let newItem = InventoryItem(
            title: lastDeleted.item.title,
            description: lastDeleted.item.itemDescription,
            storageLocation: nil // Will be set next
        )
        
        // Find and assign location
        if let location = try? context.fetch(
            FetchDescriptor<StorageLocation>(
                predicate: #Predicate { $0.id == lastDeleted.locationId }
            )
        ).first {
            newItem.storageLocation = location
        }
        
        context.insert(newItem)
        return true
    }
}
```

**Scope**: Session-only undo (cleared on app restart)
**Supported Operations**: Item deletion only in V1

### Future V2 Considerations

#### Batch Operations Planning
```swift
// V2 Interface preparation
protocol BatchOperationCapable {
    var isSelected: Bool { get set }
    var canBatchMove: Bool { get }
    var canBatchDelete: Bool { get }
}

// UI would use:
// - Edit mode with checkboxes
// - Toolbar with batch action buttons
// - Confirmation dialogs for destructive operations
```

#### Multi-User Sync Preparation
- Keep all models with UUID identifiers
- Add `lastSyncedAt` timestamps to models
- Design with conflict resolution in mind
- Use CloudKit-compatible data types

### Testing Strategy

#### Unit Testing Setup
```swift
class TestPhotoService: PhotoServiceProtocol {
    var savePhotoCallCount = 0
    var shouldFailSave = false
    
    func savePhoto(_ image: UIImage) async throws -> String {
        savePhotoCallCount += 1
        if shouldFailSave { throw PhotoError.saveFailed }
        return "test-photo-\(UUID().uuidString).jpg"
    }
    
    func loadPhoto(fileName: String) async -> UIImage? {
        return UIImage(systemName: "photo")
    }
    
    func deletePhoto(fileName: String) async {}
    func clearCache() {}
}

// Test with in-memory container
func createTestContainer() -> ModelContainer {
    let schema = Schema([Home.self, StorageLocation.self, InventoryItem.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try! ModelContainer(for: schema, configurations: [config])
}
```

#### Preview Support
```swift
extension ModelContainer {
    static var preview: ModelContainer {
        let container = createTestContainer()
        let context = container.mainContext
        
        // Generate sample data
        let home = Home(name: "Sample Home")
        context.insert(home)
        
        let bedroom = StorageLocation(name: "Bedroom", home: home)
        let closet = StorageLocation(name: "Closet", home: home, parentLocation: bedroom)
        context.insert(bedroom)
        context.insert(closet)
        
        let item = InventoryItem(title: "Watch", description: "Rolex", storageLocation: closet)
        context.insert(item)
        
        try? context.save()
        return container
    }
}
```

#### Test Coverage Requirements
1. **Unit Tests**: Model logic, validation, photo service (80% coverage)
2. **Integration Tests**: SwiftData operations, search performance
3. **UI Tests**: Critical user flows (onboarding, add item, search)
4. **Performance Tests**: 10,000 items benchmark
5. **Device Testing**: iPhone SE to iPhone 15 Pro Max, iPad

## Delivery Milestones

### Week 1: Foundation
- Complete Epic 1 (Data Layer with caching)
- Complete Epic 2 (Onboarding with default "Unsorted" location)
- NavigationSplitView shell working
- Photo service with NSCache implementation

### Week 2: Core Features  
- Complete Epic 3 (Storage Locations with validation)
- Complete Epic 4 (Item Management with async photo loading)
- Undo support for deletions
- Basic navigation working on iPhone and iPad

### Week 3: Search & Polish
- Complete Epic 5 (Search with debouncing)
- Complete Epic 6 (Empty States)
- Complete Epic 7 (Error Handling)
- Data cleanup service
- Performance testing with 10,000 items
- Final testing and bug fixes

## Success Criteria

1. **Functional Requirements Met**: All PRD features implemented
2. **Performance Targets**:
   - App launch: < 2 seconds
   - Search response: < 100ms for 1,000 items
   - Photo loading: < 500ms with cache
   - Support for 10,000+ items without UI lag
3. **Reliability**: 
   - No data loss
   - Graceful photo save failure handling
   - Circular reference prevention
   - Orphaned photo cleanup
4. **Usability**: 
   - Intuitive navigation on iPhone and iPad
   - Clear visual hierarchy with 10-level nesting limit
   - Guided empty states
   - Undo for deletions
5. **Code Quality**: 
   - SwiftUI best practices
   - Protocol-based services for testability
   - 80% unit test coverage
   - Clear separation of concerns with ViewModels

## Appendix: SwiftUI Components Reference

### Key Components Used
- `NavigationStack`: Main navigation container
- `OutlineGroup`: Hierarchical list display
- `@Query`: SwiftData fetching
- `@Model`: SwiftData model definition
- `PhotosPicker`: Image selection
- `Form`: Data input screens
- `.searchable`: Search functionality
- `.swipeActions`: List row actions
- `.overlay`: Floating button positioning

### State Management
- `@State`: Local view state
- `@Binding`: Two-way data binding
- `@Environment`: Access model context
- `@AppStorage`: Persistent user preferences
- `@Query`: Reactive data fetching

## Open Questions from iOS Dev

### Critical Architecture Questions

1. **SwiftData Relationship Modeling**: The `StorageLocation` model shows `childLocations` as a computed property that returns an empty array. How will you actually query child locations? Options:
   - Add a proper `@Relationship(deleteRule: .cascade, inverse: \StorageLocation.parentLocation) var childLocations: [StorageLocation]?`
   - Use `@Query` in views with predicates filtering by `parentLocation`
   - Which approach is preferred for performance? - **Answered**

2. **Hierarchical Data Performance**: With unlimited nesting depth for storage locations, how should we handle deep hierarchies? `OutlineGroup` with SwiftData queries could cause performance issues. Should we:
   - Implement a maximum depth limit (e.g., 5 levels)?
   - Add lazy loading with pagination for large location trees?
   - Cache expanded/collapsed states? - **Answered**

3. **Photo Memory Management**: The `InventoryItem.photo` computed property loads UIImage on-demand but has no caching mechanism. This will cause repeated disk reads when scrolling lists. Should we:
   - Implement an LRU cache in PhotoService?
   - Use SwiftUI's `AsyncImage` with caching?
   - What's the maximum cache size/count? - **Answered**

4. **Delete Rule Enforcement**: `StorageLocation` has `.deny` delete rule for items, but how do we enforce the "no child locations" rule since children aren't a proper relationship? Need clarification on:
   - Should we add childLocations as a proper relationship?
   - Or manually check in delete logic? - **Answered**

### Technical Implementation Questions

5. **Search Implementation**: For "real-time" search across potentially thousands of items:
   - Should we implement search indexing?
   - Use SwiftData predicates or in-memory filtering?
   - Consider Core Data's FTS (Full Text Search) capabilities?
   - What's the exact debouncing strategy (mentioned as 300ms but not implemented)? - **Answered**

6. **State Management Clarity**: The spec mentions "MVVM-lite" but doesn't clarify when to use ViewModels vs direct `@Query`. Which operations need dedicated ViewModels:
   - Moving items between locations?
   - Bulk operations?
   - Complex search filtering? - **Answered**

7. **Navigation Architecture**: Using `NavigationStack` seems limiting for future iPad support:
   - Should we use `NavigationSplitView` with adaptive behavior?
   - How to handle deep linking to search results?
   - State restoration strategy? - **Answered**

### Data Integrity & Edge Cases

8. **Conflict Resolution**: 
   - What happens if user creates duplicate location names at the same hierarchy level?
   - How to prevent moving a location into its own child (circular reference)?
   - If photo save fails after item creation, should we roll back the entire operation? - **Answered**

9. **Data Migration Strategy**: 
   - How will we handle schema changes in future versions?
   - Should we implement SwiftData's `VersionedSchema` from the start?
   - Backup strategy before migrations? - **Answered**

10. **Orphaned Photos**: 
    - If an item is deleted, PhotoService deletes the photo file. What if deletion fails?
    - Should we implement a cleanup service for orphaned photos?
    - How to handle photos if app is deleted and reinstalled? - **Answered**

### Testing & Development Questions

11. **SwiftData Testing**: 
    - Should we use in-memory model containers for tests?
    - How to mock PhotoService for unit tests?
    - Strategy for generating test data? - **Answered**

12. **Preview Providers**: 
    - How to create preview data with SwiftData models?
    - Should we have a separate preview model container? - **Answered**

13. **Performance Benchmarks**: 
    - What's the target number of items/locations to support?
    - Performance requirements for search (mentioned <500ms but for how many items)?
    - Memory budget for photo caching? - **Answered**

### UI/UX Clarifications

14. **Empty Location Handling**: 
    - Can users create items without any storage locations?
    - Should we auto-create a "Default" location per home? - **Answered**

15. **Batch Operations**: 
    - Should users be able to select multiple items for bulk move/delete?
    - Multi-select UI pattern? - **Answered**

16. **Undo/Redo Support**: 
    - Should we implement undo for destructive operations?
    - How long to keep undo history? - **Answered**