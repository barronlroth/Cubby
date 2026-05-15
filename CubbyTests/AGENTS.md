# CubbyTests Guide

This folder contains unit tests for Cubby using Swift Testing. UI and snapshot tests live in `CubbyUITests/` and use XCTest.

## Test Targets

- `CubbyTests`: Swift Testing unit tests for models, services, repositories, migration, feature gates, CloudKit state, sharing permissions, tags, and storage-location behavior.
- `CubbyUITests`: XCTest UI tests and snapshot tests.
- The shared `Cubby` scheme includes both test targets.

## SwiftData Test Containers

Use in-memory containers with CloudKit disabled when testing legacy SwiftData models or seed/migration sources:

```swift
let configuration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: true,
    cloudKitDatabase: .none
)
```

Do not use production SwiftData containers in tests.

## Core Data / Sharing Stack Tests

- Use `PersistenceController(storeDirectory:)` with a unique temporary directory.
- Do not use `PersistenceController.shared` or the default app store location.
- Tests that inspect private/shared-store behavior should create records in the intended store and assert store placement.
- Repository tests should exercise `CoreDataAppRepository` through value models where possible.
- Migration tests should keep the SwiftData source and Core Data target isolated per test.

## CloudKit-Related Tests

- Do not depend on real iCloud account state or network sync.
- Use injected `CloudKitAccountStatusProviding` / `CloudKitAvailabilityChecking` stubs.
- Use `CloudKitSyncSettings.resolve(..., isRunningTestsOverride: ...)` to simulate non-test startup modes.
- Home-sharing tests should use fake/mock `HomeSharingServiceProtocol` implementations unless the test is specifically about `NSPersistentCloudKitContainer` sharing behavior.

## UI Test Launch Arguments

Common UI/snapshot args:

- `UI-TESTING` / `-ui_testing`
- `SEED_MOCK_DATA`
- `SNAPSHOT_ONBOARDING`
- `SEED_ITEM_LIMIT_REACHED`
- `SEED_MISSING_LOCAL_PHOTO`
- `FORCE_FREE_TIER`
- `FORCE_PRO_TIER`
- `MOCK_SHARED_HOMES_MIXED`

The Fastlane-compatible snapshot helper injects `-FASTLANE_SNAPSHOT YES -ui_testing` only when snapshots are run through that legacy path.

## Running Tests

```bash
xcodebuild -project Cubby.xcodeproj -scheme Cubby test
```

For focused work, prefer the smallest relevant unit or UI test selection before running the full scheme.
