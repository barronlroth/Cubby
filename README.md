# Cubby

<div align="center">
  <img src="Cubby/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="Cubby Logo" width="120" height="120">

  **A home inventory app for remembering where everything is stored**

  [![Swift](https://img.shields.io/badge/Swift-5-orange.svg)](https://swift.org)
  [![Platform](https://img.shields.io/badge/Platform-iOS%2026-blue.svg)](https://developer.apple.com/ios/)
  [![UI](https://img.shields.io/badge/UI-SwiftUI-blue.svg)](https://developer.apple.com/xcode/swiftui/)
  [![Persistence](https://img.shields.io/badge/Persistence-Core%20Data%20%2B%20CloudKit-green.svg)](https://developer.apple.com/icloud/cloudkit/)
  [![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
</div>

## Overview

Cubby helps you catalog belongings across homes, rooms, closets, shelves, and containers so you can quickly answer: "Do I already own this?" and "Where did I put it?"

The app is available on the App Store: [Cubby - Home Inventory](https://apps.apple.com/us/app/cubby-home-inventory/id6751732388?uo=4).

## Features

- Multiple homes and storage locations.
- Nested location hierarchy, such as `Home > Bedroom > Closet > Top Shelf`.
- Item photos, descriptions, emoji, and tags.
- Search across item titles, descriptions, and tags.
- CloudKit-backed shared home inventories.
- Cubby Pro via RevenueCat for unlimited homes/items and sharing.
- Undo support for item deletion.

## Getting Started

### Requirements

- macOS with Xcode 26 or newer.
- iOS 26 simulator or device.
- RevenueCat public SDK keys in `Cubby/Config/Debug.xcconfig` and `Cubby/Config/Release.xcconfig` for purchase flows.

### Run in Xcode

```bash
open Cubby.xcodeproj
```

Select the `Cubby` scheme and run on an iPhone simulator or device.

### Command Line

```bash
# Build
xcodebuild -project Cubby.xcodeproj -scheme Cubby build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Test
xcodebuild -project Cubby.xcodeproj -scheme Cubby test

# Clean
xcodebuild -project Cubby.xcodeproj -scheme Cubby clean
```

Useful simulator launch states:

```bash
# Seed normal mock data
xcrun simctl launch booted com.barronroth.Cubby SEED_MOCK_DATA

# UI-test mode: in-memory source data, seeded, onboarding skipped
xcrun simctl launch booted com.barronroth.Cubby UI-TESTING

# Paywall at the free item limit
xcrun simctl launch booted com.barronroth.Cubby UI-TESTING SEED_ITEM_LIMIT_REACHED FORCE_FREE_TIER

# Onboarding snapshot state
xcrun simctl launch booted com.barronroth.Cubby UI-TESTING SNAPSHOT_ONBOARDING

# Shared-home mock UX
xcrun simctl launch booted com.barronroth.Cubby SEED_MOCK_DATA MOCK_SHARED_HOMES_MIXED
```

See [AGENTS.md](AGENTS.md) for the full launch-argument matrix.

## Architecture

Cubby is a SwiftUI app with a Core Data runtime and CloudKit sharing support.

### Runtime Data Flow

1. `CubbyApp` creates a legacy SwiftData `ModelContainer` for previews, seed data, and migration compatibility.
2. `PersistenceController` initializes a Core Data `NSPersistentCloudKitContainer`.
3. `DataMigrationService` copies legacy/seeded SwiftData data into Core Data when needed.
4. `CoreDataAppRepository` reads/writes Core Data and maps entities to value models.
5. `AppStore` publishes homes, locations, and items to SwiftUI.
6. Views mutate app state through `AppStore`, not direct persistence objects.

### Core Pieces

- `Cubby/AppData/`: value models, repository protocols, `AppStore`, and Core Data repository implementation.
- `Cubby/Cubby.xcdatamodeld/`: Core Data schema for homes, storage locations, and inventory items.
- `Cubby/Models/`: legacy SwiftData models used for migration, previews, and seeds.
- `Cubby/Services/`: RevenueCat, feature gates, Core Data/CloudKit, sharing, migration, photos, cleanup, and undo.
- `Cubby/Views/`: SwiftUI screens for home, items, search, onboarding, Pro, and shared-home flows.
- `Cubby/Utils/`: validation, tags, image pickers, typography, mock data, and helper utilities.

### Persistence and Sync

- Core Data is the primary runtime store.
- CloudKit is enabled by default outside UI tests/XCTest.
- The Core Data stack uses separate private and shared stores for owned and collaborator data.
- Shared homes use `CKShare` and CloudKit share invitation handling.
- Item photo files are local device files under `Documents/ItemPhotos`; metadata can sync before the image exists locally.

### Pro and Purchases

- RevenueCat entitlement: `pro`.
- Products: `cubby_pro_annual` and `cubby_pro_monthly`.
- Free tier: 1 owned home and 10 owned items per owned home.
- Pro unlocks unlimited homes/items and shared home inventories.

## Testing

```bash
xcodebuild -project Cubby.xcodeproj -scheme Cubby test
```

- Unit tests use Swift Testing in `CubbyTests/`.
- UI and snapshot tests use XCTest in `CubbyUITests/`.
- SwiftData tests use in-memory containers with CloudKit disabled.
- Core Data tests use temporary store directories through `PersistenceController(storeDirectory:)`.
- CloudKit tests should use injected availability/sharing stubs rather than real iCloud state.

## Release Tooling

Current release work uses ASC CLI plus Xcode/XcodeBuildMCP/Xcode Cloud.

- Use XcodeBuildMCP or Xcode/xcodebuild for simulator build/run/test validation.
- Use `asc` for App Store Connect status, build/version staging, review submission, and release/distribution.
- Use Xcode Cloud when local archive/signing is blocked by keychain or certificate access.
- `.asc/export-options-app-store.plist` supports local App Store Connect export flows.

`fastlane/` remains in the repo as legacy tooling. It historically handled TestFlight beta uploads and screenshot capture, but it is not the current shipping path unless explicitly requested.

## Known Limits

- Photo bytes are not CloudKit-synced yet; only item metadata is synced.
- Very large inventories still need performance validation.
- Empty storage locations are hidden from the main item list by design.

## Contributing

1. Fork the project.
2. Create a feature branch.
3. Keep changes focused and tested.
4. Update docs when behavior or workflows change.
5. Open a pull request.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Contact

Barron Roth - [@barronlroth](https://github.com/barronlroth)

Project Link: [https://github.com/barronlroth/Cubby](https://github.com/barronlroth/Cubby)
