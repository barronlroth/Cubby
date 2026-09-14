# Siri Inventory Integration

Tracking: [#103](https://github.com/barronlroth/Cubby/issues/103). Implementation started September 13, 2026. Full iOS 27 SDK and device verification remains pending; this is not part of the 1.1.0 onboarding release.

## Implemented behavior

- Find a saved item and speak its current home and complete nested location path. Duplicate names retain separate identities and home/path subtitles for disambiguation.
- Open an item from Siri/Shortcuts, with a fresh access check before showing its details.
- Search names, descriptions, tags, homes, and location paths across accessible homes. Search results expose their item identities to the system.
- Index eligible inventory with Core Spotlight and annotate visible item details. The index is protected while the device is locked and contains no photo files.
- Expose iOS 27 system open/search schemas. The ordinary app and explicit Shortcuts actions retain iOS 26 support.

The schema adapters require Xcode 27 / Swift 6.4 and runtime iOS 27. Home inventory has no dedicated Apple schema; system search/open plus custom lookup provide the supported integration. Siri's ability to route arbitrary questions, resolve onscreen references, and handle follow-ups still needs actual device evidence.

## Runtime boundaries

`CubbyApp` configures a single `ProAccessManager` and `SiriInventoryService` before scenes appear. App Intents use the existing primary Core Data repository; there is no separate inventory database, App Group copy, or migration.

Every query requires protected data to be available, waits for entitlement resolution and performs a fresh, saved Core Data read. Answers and text exports never use an entity's old indexed path or the UI's retained snapshot. Missing relationships, hidden homes, and unconfirmed shared-home access are excluded. Physically shared stores require an accepted participant with explicit read access. Offline behavior follows the latest entitlement and CloudKit state available on the device; it cannot establish an unseen server-side revocation.

AppStore publishes an inventory revision after refresh attempts. Revisions, entitlement changes, and foreground activation reconcile the search index. Index deletion/insertion is serialized so a stale in-flight insert is followed by the newer purge. Failures retry on the next event. Production indexes are not written during tests, design catalog runs, or seeded runs. Test Core Data stores have CloudKit explicitly disabled.

Navigation requests carry UUIDs and are acknowledged after the destination handles them. An older acknowledgment cannot clear a newer request. Siri performs read-only inventory operations; no intent moves, creates, or deletes items.

## Verification

Completed locally before installing Xcode:

- Baseline service, entity, intents, and Core Spotlight APIs typechecked against the installed Swift 6.2.3/macOS 26 SDK with app dependency stubs. This excludes the iOS 27 schema branch and the iOS UI.
- Ten service scenarios passed in an executable macOS harness using the actual service source: search, duplicate titles, moved/deleted records, entitlement gating, storage failures, navigation acknowledgment order, index replacement, revocation during a suspended insertion, independent presentation blockers, and device locking before/during a query.
- Five repository scenarios passed against isolated SQLite stores in a macOS harness, with CloudKit disabled. It uses the snapshot/controller code and a model assembled from the repository schema XML; this does not replace iOS test-target execution.
- Swift syntax parsing and whitespace checks passed.

Pending with Xcode 27:

- Build Cubby for an isolated iOS simulator, including App Intents metadata extraction and both system schema adapters.
- Run `SiriInventoryServiceTests` (ten scenarios), `SiriInventoryRepositoryTests` (five scenarios), plus affected onboarding/access tests. Repository fixtures cover saved-only reads, exact paths, hidden homes, participant states, failed share lookup, and malformed relationships.
- Exercise search/open presentation, including a cold launch, duplicate names, missing items, active forms, and subscription loss. Confirm onscreen entity identifiers with system integration tooling.
- Verify Siri on an Apple Intelligence-capable iPhone running iOS 27. Start with “Where is [item] in Cubby?”, then test an unqualified request, “Where is this stored?” while details are visible, and follow-up questions. Record which behaviors the system actually supports.
- Move/delete an indexed item, leave/revoke a shared home, and remove subscription access. Confirm fresh answers and search-index cleanup on the device, including after foregrounding from a locked state.

Sources: [Xcode requirements](https://developer.apple.com/xcode/system-requirements), [system schemas](https://developer.apple.com/documentation/appintents/app-schema-domain-system-and-in-app-search), [App Intents testing](https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code).
