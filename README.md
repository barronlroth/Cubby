# Cubby

<div align="center">
  <img src="Cubby/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="Cubby app icon" width="120" height="120">

  **A home inventory app for remembering where everything is stored**

  [![Platform](https://img.shields.io/badge/Platform-iOS%2026%2B-blue.svg)](https://developer.apple.com/ios/)
  [![UI](https://img.shields.io/badge/UI-SwiftUI-blue.svg)](https://developer.apple.com/xcode/swiftui/)
  [![Persistence](https://img.shields.io/badge/Persistence-Core%20Data%20%2B%20CloudKit-green.svg)](https://developer.apple.com/icloud/cloudkit/)
  [![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
</div>

Cubby catalogs belongings across homes, rooms, closets, shelves, and containers so you can answer "Do I already own this?" and "Where did I put it?" It is on the App Store as [Cubby - Home Inventory](https://apps.apple.com/us/app/cubby-home-inventory/id6751732388).

## Features

- Multiple homes with nested storage locations, such as `Home > Bedroom > Closet > Top Shelf`.
- Items with photos from the system photo picker or camera, descriptions, emoji, and tags.
- Search across item titles, descriptions, and tags.
- Shared homes over iCloud, with owner, read/write, and read-only collaborators.
- Siri and Shortcuts lookups ("Where is my passport in Cubby"), Spotlight indexing, and iOS 27 system open/search intents.
- JSON import and export for the selected home.
- Dynamic Type layouts and restrained haptics.
- Cubby Pro subscription through RevenueCat.

## Building

Requirements:

- Xcode 26 or newer. Xcode 27 also compiles the iOS 27 App Intents adapters, which are skipped by older compilers.
- An iPhone simulator or device on iOS 26 or newer.
- RevenueCat public SDK keys in `Cubby/Config/Debug.xcconfig` and `Cubby/Config/Release.xcconfig`.

Open `Cubby.xcodeproj`, select the `Cubby` scheme, and run. The scheme's Run action seeds mock data by default; see the launch-argument notes in [AGENTS.md](AGENTS.md) before running it on an installation whose data you want to keep.

From the command line:

```bash
xcodebuild -project Cubby.xcodeproj -scheme Cubby -destination 'generic/platform=iOS Simulator' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

```bash
xcodebuild -project Cubby.xcodeproj -scheme Cubby -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Unit tests use Swift Testing in `CubbyTests/`; UI and snapshot tests use XCTest in `CubbyUITests/`. Tests run against in-memory or temporary stores and mocked CloudKit and RevenueCat services.

## How it fits together

SwiftUI views read and mutate state through `AppStore`, which talks to a repository backed by Core Data. `NSPersistentCloudKitContainer` keeps separate private and shared stores so owned and collaborator homes sync to the right place. SwiftData remains only as a legacy migration source and for previews and seed data.

| Path | Contents |
| --- | --- |
| `Cubby/AppData/` | Value models, repository protocols, `AppStore`, and the Core Data repository |
| `Cubby/Services/` | Persistence, CloudKit sync and sharing, RevenueCat, feature gates, migration, photos, Siri indexing |
| `Cubby/Intents/` | App Intents, app shortcuts, and the inventory item entity |
| `Cubby/Views/`, `Cubby/DesignSystem/` | SwiftUI screens and shared design components |
| `Cubby/Models/` | Legacy SwiftData models |
| `docs/` | Design system, feature plans, and technical notes ([index](docs/README.md)) |

Cubby requires an active Pro subscription after onboarding. RevenueCat uses the `pro` entitlement with `cubby_pro_annual` and `cubby_pro_monthly` products.

## Known limits

- Item photos are stored on the device only. Synced items can show photo metadata before the image exists locally, and reinstalling can lose photos.
- Very large inventories have not been performance-tested.
- Empty storage locations are hidden from the main item list by design.

## Contributing and agents

[AGENTS.md](AGENTS.md) is the working guide for this repository, covering launch arguments, persistence rules, versioning, and release checks. [DESIGN.md](DESIGN.md) is the visual contract for UI changes. Agent skills live in `.agents/skills/` and are managed with the skills.sh CLI (`npx skills`), as described in AGENTS.md.

## License

MIT. See [LICENSE](LICENSE).
