# AGENTS.md

This file provides guidance for coding agents working in this repository.

## Project Overview

Cubby is an iPhone home-inventory app that helps users track belongings across homes and storage locations. It emphasizes fast search, photos, tags, nested storage locations, and Pro features for larger or shared inventories.

### Purpose
- Track belongings across multiple homes and storage locations.
- Prevent duplicate purchases by making existing inventory searchable.
- Support visual organization with item photos, emoji, tags, and location paths.
- Model hierarchical storage such as `Home > Bedroom > Closet > Top Shelf`.
- Support shared home inventories through CloudKit sharing.

### Target Users
- People with multiple homes or storage locations.
- Households that need a shared inventory.
- Users who forget where items are stored.
- Users who want to avoid duplicate purchases and clutter.

## Additional AGENTS
- `Cubby/Services/AGENTS.md` for service-layer notes, including RevenueCat, Core Data, CloudKit, sharing, migration, photos, and feature gates.
- `CubbyTests/AGENTS.md` for unit-test conventions, SwiftData/Core Data test setup, and CloudKit test boundaries.

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

# Launch with seeded mock data; persistent unless combined with UI-TESTING
xcrun simctl launch booted com.barronroth.Cubby SEED_MOCK_DATA
```

### Development Workflow
- Primary development is done through Xcode.
- Current app target is iPhone, deployment target iOS 26.0.
- SwiftUI previews remain useful, but the production runtime is `AppStore` + Core Data, not direct SwiftData queries.
- Test on a current iPhone simulator. Legacy Fastlane snapshot config targets iPhone 17 Pro Max.

## Runtime States and Launch Arguments

Cubby reads launch arguments in `Cubby/CubbyApp.swift`, `Cubby/Services/CloudKitSyncSettings.swift`, `Cubby/Services/FeatureGate.swift`, `Cubby/Services/SharedHomesGateService.swift`, `Cubby/Services/HomeSharingService.swift`, and `Cubby/Services/ProAccessManager.swift`.

### Data + Onboarding
- `UI-TESTING` / `-ui_testing`: uses an in-memory SwiftData source, clears `UserDefaults`, and seeds data unless `SNAPSHOT_ONBOARDING` or `SKIP_SEEDING`/`SEED_NONE` is present.
- `SEED_MOCK_DATA`: clears SwiftData source data, seeds the full mock dataset, and sets `hasCompletedOnboarding = true`; it is persistent unless `UI-TESTING`/XCTest is also active.
- `SEED_ITEM_LIMIT_REACHED`: seeds 1 home + 10 items to hit the free item limit.
- `SEED_FREE_TIER`: seeds 1 home named `Reach` with under-limit Halo-themed items.
- `SEED_EMPTY_HOME`: seeds 1 empty home + `Unsorted`.
- `SEED_MISSING_LOCAL_PHOTO`: seeds an item with photo metadata but no local image file for missing-photo UI tests.
- `SKIP_SEEDING` / `SEED_NONE`: disables seeding even if `UI-TESTING` is present.
- `SNAPSHOT_ONBOARDING`: forces onboarding (`hasCompletedOnboarding = false`) and disables seeding.
- `hasCompletedOnboarding` gate: when false, `OnboardingView` is shown; when true, `HomeSearchContainer` is shown.
- Onboarding creates the first home through `AppStore.createHome`; the Core Data repository creates the default `Unsorted` location.
- `lastUsedHomeId` is set during seeding so the UI lands on the primary mock home.
- Seeding priority: `SEED_ITEM_LIMIT_REACHED` -> `SEED_FREE_TIER` -> `SEED_EMPTY_HOME` -> `SEED_MISSING_LOCAL_PHOTO` -> `SEED_MOCK_DATA`.

### Core Data + CloudKit
- `USE_CORE_DATA_SHARING_STACK`: enables the Core Data sharing stack; it is currently enabled by default unless explicitly disabled through the environment.
- `DISABLE_CLOUDKIT`: uses a local non-CloudKit store.
- `INIT_CLOUDKIT_SCHEMA`: initializes the development CloudKit schema for the active stack.
- `STRICT_CLOUDKIT_STARTUP`: disables DEBUG fallback after CloudKit container creation errors.
- `FORCE_CLOUDKIT_AVAILABILITY_AVAILABLE`
- `FORCE_CLOUDKIT_AVAILABILITY_NO_ACCOUNT`
- `FORCE_CLOUDKIT_AVAILABILITY_RESTRICTED`
- `FORCE_CLOUDKIT_AVAILABILITY_UNKNOWN`
- `FORCE_CLOUDKIT_AVAILABILITY_TEMP_UNAVAILABLE`
- `FORCE_CLOUDKIT_AVAILABILITY_ERROR`

### Shared Homes
- `SHARED_HOMES_ENABLED`: runtime flag for shared homes; enabled by default when the Core Data sharing stack is enabled.
- `FORCE_ENABLE_SHARED_HOMES`: local/debug override to enable shared-home UI.
- `FORCE_DISABLE_SHARED_HOMES`: local/debug override to disable shared-home UI.
- `MOCK_SHARED_HOMES_OWNER`: mock shared homes as owner-access.
- `MOCK_SHARED_HOMES_READ_WRITE`: mock shared homes as read/write collaborator.
- `MOCK_SHARED_HOMES_READ_ONLY`: mock shared homes as read-only collaborator.
- `MOCK_SHARED_HOMES_MIXED`: mock `Main` homes as owner and other homes as read/write collaborator.
- `MOCK_SHARED_HOMES`: shorthand alias for mixed mode.
- Env var alternative: `MOCK_SHARED_HOMES=owner|readwrite|readonly|mixed|disabled`.
- Intended use: combine with `SEED_MOCK_DATA` to preview sharing badges, permissions, and collaborator UX without real iCloud invites.

### Pro / Paywall Gating
- `ProAccessManager` uses RevenueCat entitlement `pro` in normal runs.
- Product IDs are `cubby_pro_annual` and `cubby_pro_monthly`.
- `RevenueCatPublicApiKey` comes from `$(REVENUECAT_PUBLIC_API_KEY)` in `Info.plist`; Debug uses a RevenueCat test public SDK key and Release/TestFlight/App Store must use the production public SDK key.
- UI tests, SwiftUI previews, and XCTest skip RevenueCat network/configuration after a usable key is present and default to `isPro = true`; a missing/unexpanded key still fatal-errors in DEBUG.
- `FORCE_FREE_TIER` / `FORCE_PRO_TIER` override `isPro` in UI tests, previews, XCTest, and DEBUG manual runs.
- Free limits (`FeatureGate`): 1 owned home, 10 owned items per owned home. Shared/collaborator homes are excluded from owner counts.
- If a free user has more than 1 owned home, creation is denied with `overLimit`; view/search/edit remains allowed.
- Paywall reasons: `homeLimitReached`, `itemLimitReached`, `overLimit`, and `manualUpgrade`.

### Example Launch Commands
```bash
# Normal run: persistent store, CloudKit enabled by default
xcrun simctl launch booted com.barronroth.Cubby

# Seed mock data in the normal persistent flow
xcrun simctl launch booted com.barronroth.Cubby SEED_MOCK_DATA

# UI testing defaults: in-memory source, seeded, onboarding skipped
xcrun simctl launch booted com.barronroth.Cubby UI-TESTING

# Force onboarding snapshot state
xcrun simctl launch booted com.barronroth.Cubby UI-TESTING SNAPSHOT_ONBOARDING

# Force paywall at the item limit
xcrun simctl launch booted com.barronroth.Cubby UI-TESTING SEED_ITEM_LIMIT_REACHED FORCE_FREE_TIER

# Preview missing local photo state
xcrun simctl launch booted com.barronroth.Cubby UI-TESTING SEED_MISSING_LOCAL_PHOTO

# Preview shared-home UX without iCloud
xcrun simctl launch booted com.barronroth.Cubby SEED_MOCK_DATA MOCK_SHARED_HOMES_MIXED

# Preview read-only collaborator experience
xcrun simctl launch booted com.barronroth.Cubby SEED_MOCK_DATA MOCK_SHARED_HOMES_READ_ONLY

# Run local-only without CloudKit
xcrun simctl launch booted com.barronroth.Cubby DISABLE_CLOUDKIT
```

### Gotchas
- Changing seed behavior requires rebuilding and reinstalling the app on the simulator.
- Seeding clears SwiftData source data, then the Core Data migration path copies seeded data into the runtime repository when the sharing stack is active.
- `SEED_MOCK_DATA` alone does not imply in-memory storage.
- Debug RevenueCat test keys are not valid for TestFlight/App Store builds.

## Release & Distribution

- Current release tooling is ASC CLI plus Xcode/XcodeBuildMCP/Xcode Cloud, not Fastlane.
- Use XcodeBuildMCP or Xcode/xcodebuild for simulator build/run/test validation.
- Use `asc` for App Store Connect status, build/version staging, review submission, and release/distribution operations.
- Use Xcode Cloud when local archive/signing is blocked by keychain or certificate access.
- `.asc/export-options-app-store.plist` contains App Store Connect export options for local `asc`/Xcode export flows.
- Current project settings should be verified before release; as of this update, marketing version is `1.0.4`, build is `70`, and deployment target is iOS `26.0`.
- `fastlane/` is legacy. Historically it provided:
  - `fastlane beta`: increment build number, build an App Store export, upload to TestFlight, wait for processing, distribute externally.
  - `fastlane beta_internal`: same upload path without external distribution.
  - `fastlane snapshot`: App Store screenshot capture using the Fastlane snapshot helper.
- Do not assume Fastlane is the active shipping path unless the user explicitly asks to use it.

### Snapshots
- Legacy `fastlane/Snapfile` targets iPhone 17 Pro Max, iOS 26.0, language `en-US`, and writes to `fastlane/screenshots`.
- Snapshots use `CubbyUITests`.
- `CubbySnapshotTests` captures:
  - `00-Onboarding` with `UI-TESTING SNAPSHOT_ONBOARDING`
  - `01-Home` with `UI-TESTING SEED_MOCK_DATA`
  - `02-ItemDetail` with `UI-TESTING SEED_MOCK_DATA`
  - `03-AddItem` with `UI-TESTING SEED_MOCK_DATA`
- When run through Fastlane snapshot, the helper injects `-FASTLANE_SNAPSHOT YES -ui_testing`.

## Architecture

### Core Technologies
- **SwiftUI**: UI framework for all app screens.
- **Core Data + NSPersistentCloudKitContainer**: Primary runtime persistence and CloudKit sharing stack.
- **CloudKit sharing**: Shared home invites, private/shared stores, and share acceptance.
- **SwiftData**: Legacy model container used for migration compatibility, previews, and seed-source generation.
- **RevenueCat**: Pro entitlement, offerings, purchase, and restore flows.
- **PhotosUI/UIKit**: Image selection and capture.
- **Foundation Models**: Optional AI emoji suggestion path when available.
- **Swift Testing + XCTest**: Unit tests and UI/snapshot tests.

### Project Structure
```
Cubby/
|-- AppData/
|   |-- AppModels.swift              # Value models consumed by SwiftUI
|   |-- AppRepositories.swift        # Repository protocols
|   |-- AppStore.swift               # Main observable app state
|   `-- CoreDataAppRepository.swift  # Core Data repository implementation
|-- Models/                          # Legacy SwiftData models used for migration/seeding
|-- Services/
|   |-- PersistenceController.swift  # Core Data private/shared CloudKit stores
|   |-- HomeSharingService.swift     # CKShare create/accept/leave behavior
|   |-- ProAccessManager.swift       # RevenueCat state and purchase/restore
|   |-- FeatureGate.swift            # Pro/free/share gates
|   |-- DataMigrationService.swift   # SwiftData -> Core Data migration
|   |-- RemoteChangeHandler.swift    # Core Data remote-change merge notifications
|   `-- PhotoService.swift           # Photo storage and cache
|-- Views/
|   |-- MainNavigationView.swift
|   |-- Home/
|   |-- Items/
|   |-- Pro/
|   |-- Search/
|   |-- Components/
|   `-- Onboarding/
|-- Utils/                           # Validation, tags, image pickers, typography, mock data
|-- ViewModels/                      # Legacy SwiftData search view model
|-- Cubby.xcdatamodeld/              # Core Data CDHome/CDStorageLocation/CDInventoryItem schema
|-- Config/                          # Build xcconfigs, including RevenueCat public SDK key
`-- Info.plist
```

### Data Flow
1. `CubbyApp` creates a SwiftData `ModelContainer` for legacy data, preview data, and seed generation.
2. `CubbyApp` initializes `PersistenceController` when the Core Data sharing stack is enabled.
3. `DataMigrationService` copies legacy/seeded SwiftData records into the Core Data private store when needed.
4. `CoreDataAppRepository` reads/writes Core Data entities and maps them into value models.
5. `AppStore` publishes `AppHome`, `AppStorageLocation`, and `AppInventoryItem` arrays.
6. Views use `@EnvironmentObject AppStore` and call `AppStore` methods for mutations.
7. `RemoteChangeHandler` listens for persistent-store remote changes and refreshes app state.

### Data Passing Pattern
- Prefer value models (`AppHome`, `AppStorageLocation`, `AppInventoryItem`) and IDs across SwiftUI boundaries.
- Avoid passing SwiftData model objects or `NSManagedObject` instances into sheets.
- Mutations should flow through `AppStore` and repository methods.
- When adding persistent fields, update the Core Data model, `AppModels`, `CoreDataAppRepository`, migration, seeds, and tests. Update SwiftData legacy models only when migration/seed compatibility requires it.

### Key Models and Relationships

#### Runtime Core Data
- `CDHome`: top-level home, private or shared store.
- `CDStorageLocation`: hierarchical storage location with parent/child relationships.
- `CDInventoryItem`: item with title, optional description, photo metadata, emoji, pending AI emoji flag, and tags.
- `PersistenceController` maintains separate private and shared SQLite stores.

#### Legacy SwiftData
- `Home`, `StorageLocation`, and `InventoryItem` remain for seed generation, previews, and migration.
- `InventoryItem` includes `photoFileName`, `emoji`, `isPendingAiEmoji`, and `tags`.

## Key Features Implementation

### Home Page
- Main UI is driven by `HomeSearchContainer`, `MainNavigationView`, `HomeView`, and `AppStore`.
- Items are grouped by storage location path.
- Empty locations are hidden from the item list but available in location management/pickers.
- Home selection uses `lastUsedHomeId` and falls back when homes are removed.

### Storage Location Management
- Supports nested locations up to `StorageLocation.maxNestingDepth` in the legacy model and mirrored Core Data depth logic.
- Location deletion is blocked when a location has child locations or items.
- Moving or creating content in shared homes must preserve the correct private/shared store.

### Photo Management
- Photos are compressed JPEGs stored in `Documents/ItemPhotos/`.
- `PhotoService` uses an in-memory cache.
- `DataCleanupService` removes orphaned local photos by reading Core Data item photo metadata.
- Photos are not CloudKit-synced yet; metadata may exist while the local file is missing.

### Search and Tags
- `AppStore.searchItems` searches title, description, and tags.
- Home inline search filters currently use title/description.
- `SearchViewModel` is legacy SwiftData search support.
- Tags are normalized through `TagHelpers` and shown with `TagInputView`, `TagDisplayView`, and `TagChip`.

### Pro and Paywall
- The global paywall sheet is driven by `PaywallContext` from `HomeSearchContainer`.
- `ProPaywallSheetView` renders the custom paywall and only shows RevenueCat subscription packages.
- Annual packages are ranked before monthly packages and show monthly equivalent detail when possible.
- `ProStatusView` handles status, restore, legal links, and upgrade entry.

### Shared Homes
- `SharedHomesGateService` gates shared-home UI.
- `HomeSharingService` creates and configures `CKShare`, resolves share URLs, accepts invitations into the shared store, and leaves collaborator shares.
- `AppDelegate` receives CloudKit share invitation metadata on iOS and forwards it into the sharing service.
- Debug mock modes allow sharing UX review without a real iCloud invite flow.

### Undo/Redo
- `UndoManager` is session-based and currently supports item deletion restore.
- Deleted item snapshots include tags, emoji, photo metadata, and pending emoji state.

## Important Considerations

### Persistence Requirements
- Current app target is iOS 26.0.
- Core Data runtime uses `NSPersistentCloudKitContainer` with private and shared stores.
- SwiftData still exists; do not remove or change it without considering migration, previews, and seeded UI tests.
- CloudKit is enabled by default outside tests unless `DISABLE_CLOUDKIT` is present.

### Known Issues / Limits
- Photos are local-only; issue #53 tracks syncing compressed photo assets.
- Performance is not validated for very large inventories.
- Empty locations intentionally do not appear in the main item list.

### SwiftUI Best Practices
- Keep views focused and decomposed.
- Prefer `AppStore` methods for mutations.
- Use `ContentUnavailableView` for empty/error states.
- Keep paywall and shared-home gating checks both at entry points and save-time guard rails.
- Use stable IDs and value models for sheet/navigation handoff.

## Testing Strategy
- Unit tests use Swift Testing in `CubbyTests/`.
- UI and snapshot tests use XCTest in `CubbyUITests/`.
- The `Cubby` scheme includes both unit and UI test targets.
- SwiftData tests should use in-memory `ModelContainer` with `cloudKitDatabase: .none`.
- Core Data tests should use temporary directories and `PersistenceController(storeDirectory:)`; do not use the default production store.
- CloudKit-related tests should mock availability/sharing behavior and avoid real network sync.

## Common Tasks

### Adding a Persistent Field
1. Update `Cubby/Cubby.xcdatamodeld`.
2. Update `AppModels` value types.
3. Update `CoreDataAppRepository` mapping and persistence.
4. Update `DataMigrationService` if legacy SwiftData data must be copied.
5. Update SwiftData legacy models and mock seeds if previews/UI seeds need the field.
6. Add focused unit tests for repository and migration behavior.

### Adding a UI Feature
1. Prefer `AppStore` state and methods over direct persistence access in views.
2. Add or update views in the appropriate `Views/` subfolder.
3. Add validation helpers or user-facing error types when needed.
4. Add empty/loading/error states.
5. Add unit tests for logic and UI tests when the workflow is user-critical.

### Debugging Persistence Issues
1. Check whether the path is Core Data runtime or legacy SwiftData seed/migration.
2. Check private/shared store placement for shared-home data.
3. Verify `AppStore.refresh()` sees repository changes.
4. Check `RemoteChangeHandler` for merge notifications.
5. Use `DebugLogger` for startup, migration, CloudKit, and RevenueCat diagnostics.

### Debug Infrastructure
- `DebugLogger` provides consistent logging helpers.
- Use direct repository/app-store assertions in tests before relying on UI state.
- For CloudKit startup issues, try `DISABLE_CLOUDKIT` or `STRICT_CLOUDKIT_STARTUP` depending on whether you want fallback or hard failure.

## Code Style Guidelines
- Use descriptive variable names.
- Keep views focused and decomposed.
- Validate user input.
- Handle errors gracefully with user-facing copy where appropriate.
- Add empty states for all screens.
- Use SwiftUI built-in components when possible.
