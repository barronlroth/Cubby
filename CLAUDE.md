# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cubby is a home inventory management app for iOS/macOS that helps users track their belongings across multiple homes and storage locations. The app solves the common problem of forgetting where items are stored, preventing duplicate purchases and reducing clutter.

### Purpose
- **Track belongings** across multiple homes and storage locations
- **Prevent duplicate purchases** by knowing what you already own
- **Visual organization** with photos of items
- **Hierarchical storage** with nested locations (e.g., Home > Bedroom > Closet > Top Shelf)
- **Quick search** to find any item across all locations

### Target Users
- People with multiple homes or storage locations
- Anyone who struggles to remember where they've stored belongings
- Users who want to avoid buying duplicate items
- People seeking better organization of their possessions

## Essential Commands

### Building and Running
```bash
# Build the project
xcodebuild -project Cubby.xcodeproj -scheme Cubby build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Run tests
xcodebuild -project Cubby.xcodeproj -scheme Cubby test

# Clean build folder
xcodebuild -project Cubby.xcodeproj -scheme Cubby clean

# Install on simulator
xcrun simctl install booted /path/to/Cubby.app

# Launch on simulator
xcrun simctl launch booted com.barronroth.Cubby
```

### Development Workflow
- Primary development is done through Xcode IDE
- Use Xcode's built-in SwiftUI preview for rapid UI development
- SwiftData models automatically generate database schema
- Test on iPhone 16 Pro simulator for best experience

## Architecture

### Core Technologies
- **SwiftUI**: Declarative UI framework for all views
- **SwiftData**: Modern persistence framework with automatic CloudKit sync capability
- **Swift Testing**: New testing framework for unit tests
- **PhotosUI**: For image selection and capture
- **NSCache**: For efficient photo caching (50MB limit)

### Project Structure
```
Cubby/
├── Models/
│   ├── Home.swift                 # Top-level home model
│   ├── StorageLocation.swift      # Hierarchical storage locations
│   └── InventoryItem.swift        # Individual items with photos
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift         # Main screen with location hierarchy
│   │   ├── StorageLocationRow.swift # Recursive location display
│   │   └── LocationDetailView.swift # Shows items in a location
│   ├── Items/
│   │   ├── AddItemView.swift      # Form to create new items
│   │   ├── ItemDetailView.swift   # View/edit individual items
│   │   └── ItemRow.swift          # List row for items
│   ├── Search/
│   │   └── SearchView.swift       # Global search across all items
│   └── Onboarding/
│       └── OnboardingView.swift   # First-time setup
├── Services/
│   ├── PhotoService.swift         # Photo storage and caching
│   ├── DataCleanupService.swift   # Orphaned photo cleanup
│   └── UndoManager.swift          # Undo/redo for deletions
├── ViewModels/
│   └── SearchViewModel.swift      # Search logic with debouncing
└── Utils/
    ├── ValidationHelpers.swift    # Input validation
    └── MockDataGenerator.swift    # Test data generation
```

### Key Models and Relationships

#### Home Model
- Top-level container for storage locations
- One-to-many relationship with StorageLocation
- Users can have multiple homes

#### StorageLocation Model
- **Hierarchical structure** with parent-child relationships
- **Bidirectional relationships** using SwiftData's @Relationship
- Maximum nesting depth of 10 levels
- Contains both child locations and items
- Validates against circular references

#### InventoryItem Model
- Belongs to a single StorageLocation
- Optional photo stored in Documents directory
- Title and description fields
- Timestamps for creation and modification

### Data Flow
1. **SwiftData ModelContainer** created in CubbyApp with versioned schema
2. **Container injected** into SwiftUI environment
3. **Views use @Query** for reactive data fetching
4. **@Environment(\.modelContext)** provides access for mutations
5. **Automatic UI updates** when data changes

### Key Features Implementation

#### Nested Locations (Recently Fixed)
- Uses recursive `StorageLocationRow` component
- Proper inverse relationships: `parentLocation` ↔ `childLocations`
- DisclosureGroup for expand/collapse functionality
- Swipe actions properly scoped to prevent duplicates

#### Photo Management
- Photos compressed to 70% JPEG quality
- Stored in `Documents/ItemPhotos/` directory
- NSCache with 50MB limit for performance
- Orphaned photos cleaned on app launch

#### Search System
- In-memory filtering for performance
- 300ms debounce to prevent excessive queries
- Searches title and description fields
- Optional home filtering for multi-home users

#### Undo/Redo System
- Session-based undo stack (max 10 items)
- Only supports item deletion currently
- Floating UI button appears after deletion
- Photos preserved during undo period

## Important Considerations

### SwiftData Requirements
- Requires iOS 17.0+ / macOS 14.0+
- Models must use @Model macro
- Relationships need proper inverse configuration
- Avoid circular references in self-referential relationships

### Known Issues
1. **UI Refresh**: New storage locations don't always appear immediately after creation
2. **Performance**: Not tested with 1000+ items
3. **Edge Cases**: App may crash if all homes are deleted

### SwiftUI Best Practices
- Use @Query for reactive data fetching
- Leverage environment injection for model context
- NavigationSplitView for iPad/Mac compatibility
- ContentUnavailableView for empty states
- Proper view identity with `.id()` for recursive views

### Testing Strategy
- Unit tests use Swift Testing framework (@Test macro)
- Test models with in-memory containers
- UI tests use XCTest framework
- Tests located in CubbyTests/ directory

### CloudKit Integration (Future)
- App has CloudKit entitlements configured
- Remote notification background mode enabled
- Ready for sync implementation in V2

## Common Tasks

### Adding a New Feature
1. Update relevant SwiftData models if needed
2. Create new views in appropriate directory
3. Add validation in ValidationHelpers if needed
4. Update empty states if applicable
5. Add unit tests for new functionality

### Debugging SwiftData Issues
1. Check relationship configurations (especially inverse)
2. Verify model context saves
3. Look for circular references
4. Check for proper @Query usage in views

### Performance Optimization
1. Use lazy loading for large lists
2. Implement pagination for 50+ items
3. Cache expensive computations
4. Profile with Instruments

## Code Style Guidelines
- Use descriptive variable names
- Keep views focused and decomposed
- Validate all user inputs
- Handle errors gracefully
- Add empty states for all screens
- Use SwiftUI's built-in components when possible