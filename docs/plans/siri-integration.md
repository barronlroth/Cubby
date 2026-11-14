# Siri Inventory Integration

Tracking: [#103](https://github.com/barronlroth/Cubby/issues/103). Implementation started September 13, 2026. The app builds with Xcode 27 and has passed iOS 27 intent integration tests. Spoken Siri verification on an iPhone remains pending. This is separate from the 1.1.0 onboarding release.

## Implemented behavior

- Find a saved item and speak its current home and complete nested location path. Duplicate names retain separate identities and home/path subtitles for disambiguation.
- Open an item from Siri/Shortcuts, with a fresh access check before showing its details.
- Search names, descriptions, tags, homes, and location paths across accessible homes. Normal inventory rows, ordinary search results, and Siri search results expose eligible item identities to the system.
- Index eligible inventory with Core Spotlight and annotate visible item details. The index is protected while the device is locked and contains no photo files.
- Expose iOS 27 system open/search schemas. The ordinary app and explicit Shortcuts actions retain iOS 26 support.

The schema adapters require Xcode 27 / Swift 6.4 and runtime iOS 27. Home inventory has no dedicated Apple schema; system search/open plus custom lookup provide the supported integration. Siri's ability to route arbitrary questions, resolve onscreen references, and handle follow-ups still needs actual device evidence.

## Runtime boundaries

`CubbyApp` configures a single `ProAccessManager` and `SiriInventoryService` before scenes appear. App Intents use the existing primary Core Data repository; there is no separate inventory database, App Group copy, or migration.

Every query requires protected data to be available, waits for entitlement resolution and performs a fresh, saved Core Data read. Answers and text exports never use an entity's old indexed path or the UI's retained snapshot. Missing relationships, hidden homes, and unconfirmed shared-home access are excluded. Physically shared stores require an accepted participant with explicit read access. Offline behavior follows the latest entitlement and CloudKit state available on the device; it cannot establish an unseen server-side revocation.

AppStore publishes an inventory revision after refresh attempts. Revisions, entitlement changes, and foreground activation reconcile the search index. Index deletion/insertion is serialized so a stale in-flight insert is followed by the newer purge. Failures retry on the next event. Production indexes are not written during tests, design catalog runs, or seeded runs. Test Core Data stores have CloudKit explicitly disabled.

iOS 27 system reindex callbacks use that same writer and wait for the latest queued generation. They rebuild the complete saved snapshot, including deletion of missing IDs, and propagate access, storage, or index-write errors. The SDK's index description exposes its protection class; Cubby accepts its complete-protection index only.

Navigation requests carry UUIDs and are acknowledged after the destination handles them. An older acknowledgment cannot clear a newer request. Active editors hold a blocker until their sheet finishes dismissing. The presenter refreshes the UI snapshot only when it can navigate, preserving the editor's surrounding state while a request waits. Siri performs read-only inventory operations; no intent moves, creates, or deletes items.

## Verification

Toolchain verified September 14, 2026:

- Xcodes CLI installed Xcode 27.0 (27A266a), Swift 6.4, and the iOS 27 simulator runtime (24A434). The selected developer directory is `/Applications/Xcode-27.0.0.app/Contents/Developer`.
- Cubby builds for the iOS simulator. App Intents extraction produced five actions and `InventoryItemEntity`, including both iOS 27 system schema adapters. The Siri API source also typechecked with an iOS 26 deployment target.
- RevenueCat was raised from 5.52.0 to 5.78.0 for its [Xcode 27 compiler fix](https://github.com/RevenueCat/purchases-ios/pull/6949). Purchase/restore behavior still requires device testing with real StoreKit products.
- AppIntentsTesting requires a signed test app. Local simulator signing (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`) worked; disabling signing caused framework error 803 before any intent executed.
- Test startup avoids constructing the real CloudKit sharing service in isolated runs. Repository fixtures explicitly disable CloudKit. Tests do not use production inventory or publish test records to the system index.

Completed on the iOS 27 iPhone 18 Pro simulator:

- Across focused runs, the latest result for each selected test is passing: 45 unit tests and 16 UI tests. The queued-editor interaction passed three consecutive repetitions after the test verified that the draft remained editable and Cancel was hittable following intent execution.
- All 20 Siri unit tests passed. Fifteen service scenarios cover search, duplicate titles, moved/deleted records, entitlement gating, storage failures, navigation acknowledgment order, index replacement, revocation during a suspended insertion, independent presentation blockers, device locking, and system-requested reindex completion, failures, retry, and suppression. Five repository scenarios cover saved-only reads, exact paths, hidden homes, participant states, failed share lookup, and malformed relationships.
- All 25 selected onboarding, first-save, launch selection, recovery, and entitlement unit tests passed.
- Out-of-process AppIntentsTesting verified exact saved locations across homes, missing-item queries, system open/search, visible entity annotations, and denied subscription access. These tests execute the registered intents; they do not invoke Siri's language model.
- Ordinary home-search and dedicated-search rows expose the correct entity IDs. An unsaved editor preserves its draft during a queued Siri search; after cancellation, the search opens. A separate control verifies cancellation without any intent.
- Existing UI checks passed for onboarding, the forced-free trial wall, accessibility text size, global search, add/edit/delete/undo, moving items, and read-only shared-home permissions.

Pending device verification:

- Exercise a cold launch, duplicate-name disambiguation, missing items, and subscription loss on the device.
- Invoke a foreground search while editing an unsaved item. Confirm that the draft remains editable and the pending search opens after the user closes the editor.
- Verify Siri on an Apple Intelligence-capable iPhone running iOS 27. Start with “Where is [item] in Cubby?”, then test an unqualified request, “Where is this stored?” while details are visible, and follow-up questions. Record which behaviors the system actually supports.
- Move/delete an indexed item, leave/revoke a shared home, and remove subscription access. Confirm fresh answers and search-index cleanup on the device, including after foregrounding from a locked state.

Sources: [Xcode requirements](https://developer.apple.com/xcode/system-requirements), [system schemas](https://developer.apple.com/documentation/appintents/app-schema-domain-system-and-in-app-search), [App Intents testing](https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code).

## Physical-device report

September 18, 2026: the owner confirmed spoken item lookup worked in Cubby Dev on an iPhone 15 Pro running iOS 27.0. This confirms the tested lookup, not all unqualified requests or conversational follow-ups. Siri is prepared for release 1.2.0 after onboarding version 1.1.0 shipped. App Store submission is held while investigating the separately reported slow, incorrect AI emoji selection and blurry spinner.
