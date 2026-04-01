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

## Additional AGENTS
- `Cubby/Services/AGENTS.md` for service-layer notes (RevenueCat + CloudKit).
- `CubbyTests/AGENTS.md` for test conventions and SwiftData setup.

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

# Launch with seeded mock data (in-memory store, onboarding skipped)
xcrun simctl launch booted com.barronroth.Cubby SEED_MOCK_DATA
# UI tests/snapshot runs also pass UI-TESTING/-ui_testing to trigger seeding and a clean state
```

### Development Workflow
- Primary development is done through Xcode IDE
- Use Xcode's built-in SwiftUI preview for rapid UI development
- SwiftData models automatically generate database schema
- Test on iPhone 16 Pro simulator for best experience

## Runtime States and Launch Arguments

Cubby reads launch arguments in `Cubby/CubbyApp.swift` and `Cubby/Services/ProAccessManager.swift` to control seeding, onboarding, storage, and Pro gating.

### Data + Onboarding
- `UI-TESTING` / `-ui_testing`: uses an in-memory SwiftData store, clears `UserDefaults`, and seeds mock data unless `SNAPSHOT_ONBOARDING` or `SKIP_SEEDING`/`SEED_NONE` is present.
- `SEED_MOCK_DATA`: clears existing SwiftData data, seeds the full mock dataset, and sets `hasCompletedOnboarding = true` (persistent store unless `UI-TESTING` is also set).
- `SEED_ITEM_LIMIT_REACHED`: clears existing data, seeds 1 home + 10 items to hit the free item limit, and sets `hasCompletedOnboarding = true`.
- `SEED_FREE_TIER`: clears existing data, seeds 1 home named "Reach" with Halo-themed items (under the free limits), and sets `hasCompletedOnboarding = true`.
- `SEED_EMPTY_HOME`: clears existing data, seeds 1 empty home + "Unsorted", and sets `hasCompletedOnboarding = true`.
- `SKIP_SEEDING` / `SEED_NONE`: disables seeding even if `UI-TESTING` is present.
- `SNAPSHOT_ONBOARDING`: forces onboarding (`hasCompletedOnboarding = false`) and disables seeding, even in `UI-TESTING`.
- `hasCompletedOnboarding` gate: when false, `OnboardingView` is shown; when true, `HomeSearchContainer` is shown. Onboarding creates the first home + an "Unsorted" location.
- `lastUsedHomeId` is set during seeding so the UI lands on the primary mock home.
- Seeding priority: `SEED_ITEM_LIMIT_REACHED` → `SEED_FREE_TIER` → `SEED_EMPTY_HOME` → `SEED_MOCK_DATA`.

### Pro / Paywall Gating
- `ProAccessManager` uses RevenueCat entitlements in normal runs (`entitlement = pro`). Missing `REVENUECAT_PUBLIC_API_KEY` causes a debug-only crash; release builds show an error message.
- In UI tests, SwiftUI previews, and XCTest (`UI-TESTING`, `XCODE_RUNNING_FOR_PREVIEWS`, or `XCTestConfigurationFilePath`), RevenueCat is skipped and `isPro` defaults to `true`.
- `FORCE_FREE_TIER` / `FORCE_PRO_TIER` override `isPro` in UI tests, previews, and XCTest; in DEBUG builds they can also be used for manual runs to bypass RevenueCat.
- Free limits (`FeatureGate`): 1 home, 10 items per home. If `homeCount > 1` while free, all creation is denied with reason `overLimit` (view/search/edit remains allowed).
- Paywall reasons: `homeLimitReached`, `itemLimitReached`, `overLimit`. The global sheet is driven by `PaywallContext` in `HomeSearchContainer`; Add Home/Item also show an alert and can forward into the paywall.

### Shared Homes Mock UX Mode (Debug)
- `MOCK_SHARED_HOMES_OWNER`: forces mock sharing mode where shared homes behave as owner-access.
- `MOCK_SHARED_HOMES_READ_WRITE`: forces mock sharing mode where shared homes behave as read/write collaborator.
- `MOCK_SHARED_HOMES_READ_ONLY`: forces mock sharing mode where shared homes behave as read-only collaborator (add/edit/delete disabled in gated screens).
- `MOCK_SHARED_HOMES_MIXED`: mixed mode intended for quick UX review with seeded data; homes whose name contains `"Main"` behave as owner, other homes behave as read/write collaborator.
- `MOCK_SHARED_HOMES`: shorthand alias for mixed mode.
- Env var alternative: `MOCK_SHARED_HOMES=owner|readwrite|readonly|mixed|disabled`.
- Intended use: combine with `SEED_MOCK_DATA` to preview sharing badges, lock states, and collaborator UX without iCloud invite/accept flow.

### Example Launch Commands
```bash
# Normal run (persistent store, onboarding if first launch)
xcrun simctl launch booted com.barronroth.Cubby

# Seed mock data (persistent store)
xcrun simctl launch booted com.barronroth.Cubby SEED_MOCK_DATA

# UI testing defaults (in-memory, seeded)
xcrun simctl launch booted com.barronroth.Cubby UI-TESTING

# Force onboarding snapshot state
xcrun simctl launch booted com.barronroth.Cubby UI-TESTING SNAPSHOT_ONBOARDING

# Force paywall at the item limit (free tier)
xcrun simctl launch booted com.barronroth.Cubby UI-TESTING SEED_ITEM_LIMIT_REACHED FORCE_FREE_TIER

# Seed a free-tier Halo dataset (1 home "Reach", <10 items)
xcrun simctl launch booted com.barronroth.Cubby SEED_FREE_TIER

# Preview shared-home UX without iCloud (owner + collaborator mix)
xcrun simctl launch booted com.barronroth.Cubby SEED_MOCK_DATA MOCK_SHARED_HOMES_MIXED

# Preview read-only collaborator experience
xcrun simctl launch booted com.barronroth.Cubby SEED_MOCK_DATA MOCK_SHARED_HOMES_READ_ONLY
```

### Gotchas
- Changing seed behavior requires rebuilding and reinstalling the app on the simulator (new code won’t apply to an old build).
- Seeding clears existing SwiftData data, but only when the app actually runs the seeding path; if data already exists and seeding isn’t triggered, you’ll still see prior content.

### Release & Distribution
- Fastlane is configured in `fastlane/Fastfile` with a `beta` lane that builds `Cubby.xcodeproj`/`Cubby` and uploads to TestFlight using App Store Connect API keys.
- To ship a beta: export `APP_STORE_CONNECT_API_KEY_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID` (and optionally `APP_STORE_CONNECT_API_KEY_KEYFILE_PATH` or `APP_STORE_CONNECT_API_KEY_KEY_CONTENT_BASE64`), then run `fastlane beta` from the repo root.
- The lane increments `CFBundleVersion`, produces an App Store export build, uploads via TestFlight, and skips waiting for processing.
- Fastlane snapshot setup:
  - `fastlane/Snapfile` targets iPhone 17 Pro Max and iPhone 17 (en-US) and writes to `fastlane/screenshots`.
  - Snapshots use the UI test target (`CubbyUITests`) which launches with `UI-TESTING` + `SEED_MOCK_DATA` for seeded in-memory data and onboarding skipped.
  - To run snapshots: `FASTLANE_SKIP_UPDATE_CHECK=1 fastlane snapshot` (optional: set `concurrent_simulators(false)` or narrow `devices` if needed).

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
│   │   ├── HomeView.swift         # Main screen with flat list of items grouped by location
│   │   ├── StorageLocationRow.swift # Recursive location display (for location management)
│   │   ├── LocationDetailView.swift # Shows items in a location
│   │   ├── LocationSectionHeader.swift # Section headers for grouped items display
│   │   ├── StorageLocationPicker.swift # Location selector with hierarchy
│   │   └── AddLocationView.swift  # Form to create new storage locations
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
    ├── MockDataGenerator.swift    # Test data generation
    └── DebugLogger.swift          # Debug logging infrastructure
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

### Data Passing Pattern
- **Pass IDs, not objects**: When passing data between views (especially sheets), pass UUID instead of model objects
- **Fetch locally**: Each view should fetch its required data using @Query or FetchDescriptor
- **Prevents reference detachment**: Avoids SwiftData model context issues across sheet presentations
- Example: `AddItemView(selectedHomeId: home?.id)` instead of `AddItemView(selectedHome: home)`

### Key Features Implementation

#### Home Page Design (Recently Redesigned)
- Flat list view showing all items grouped by storage location
- Section headers display full location path with item counts
- Items sorted alphabetically within sections
- Empty locations are hidden (only locations with items shown)
- Navigation menu only appears when a home is selected

#### Storage Location Management
- Hierarchical structure maintained for location organization
- Uses recursive `StorageLocationRow` for location management views
- Proper inverse relationships: `parentLocation` ↔ `childLocations`
- Maximum nesting depth of 10 levels

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
1. **Performance**: Not tested with 1000+ items
2. **Empty Locations**: Storage locations without items don't appear in the home view (by design)

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
5. **Use FetchDescriptor for direct queries** when @Query doesn't update
6. **Pass IDs instead of objects** to avoid reference detachment
7. **Check if selectedHome is nil** before allowing actions
8. **Use DebugLogger** to track state changes and fetch results

### Performance Optimization
1. Use lazy loading for large lists
2. Implement pagination for 50+ items
3. Cache expensive computations
4. Profile with Instruments

### Debug Infrastructure
- **DebugLogger utility**: Provides consistent logging with visual markers (🔍, ❌, ⚠️, ✅)
- **Usage**: `DebugLogger.info("message")`, `DebugLogger.error("message")`
- **Monitor logs**: Run from Xcode to see console output
- **Helps diagnose**: SwiftData context issues, state synchronization problems

## Code Style Guidelines
- Use descriptive variable names
- Keep views focused and decomposed
- Validate all user inputs
- Handle errors gracefully
- Add empty states for all screens
- Use SwiftUI's built-in components when possible
