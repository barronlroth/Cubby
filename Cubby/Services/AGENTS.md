# Services Guide

This folder contains the runtime services for Pro access, hard-paywall and legacy free-tier guardrails, Core Data persistence, CloudKit sync/sharing, migration, photos, cleanup, and shared-home feature flags.

## RevenueCat Pro Integration

### Product configuration expected by the app
- Entitlement: `pro`
- Annual subscription product: `cubby_pro_annual`
- Monthly subscription product: `cubby_pro_monthly`
- RevenueCat must have a Current offering containing packages for the products above.
- `ProPaywallSheetView` filters displayed packages to subscriptions. Non-subscription/lifetime packages will not render unless that filter changes.

### API key wiring
- `Cubby/Info.plist` contains `RevenueCatPublicApiKey = $(REVENUECAT_PUBLIC_API_KEY)`.
- `Cubby/Config/Debug.xcconfig` should use a RevenueCat test Public SDK Key.
- `Cubby/Config/Release.xcconfig` must use the production RevenueCat Public SDK Key for TestFlight/App Store builds.
- In DEBUG, a missing or unexpanded key fatal-errors before the bypass return path; UI tests/previews/XCTest bypass RevenueCat network/configuration only after the key is usable.
- Release builds surface key/configuration problems as purchase-option availability errors instead of crashing.

### `ProAccessManager`
File: `Cubby/Services/ProAccessManager.swift`

- Owns RevenueCat state (`CustomerInfo`, `Offerings`) and derived `isPro`.
- Computes `isPro` via `customerInfo.entitlements["pro"]?.isActive == true`.
- Tracks annual/monthly product IDs and active product identifier.
- Configures RevenueCat once at app start and listens through `PurchasesDelegate`.
- Uses cached `CustomerInfo` first, then refreshes in the background.
- Skips RevenueCat network/configuration in UI tests, SwiftUI previews, and XCTest after key validation; defaults to Pro unless `FORCE_FREE_TIER` is present.
- In DEBUG manual runs, `FORCE_FREE_TIER` and `FORCE_PRO_TIER` can bypass RevenueCat.

### Paywall surfaces
- Cubby presents a hard paywall after onboarding when entitlement resolves to non-Pro.
- `PaywallContext` reasons are `subscriptionRequired`, `homeLimitReached`, `itemLimitReached`, `overLimit`, and `manualUpgrade`; `subscriptionRequired` is the only blocking reason.
- `HomeSearchContainer` owns the global paywall sheet and disables dismissal for blocking contexts.
- `ProPaywallSheetView` renders the native paywall and purchases the selected RevenueCat package.
- `OptionsView` owns subscription status, restore/manage actions, legal links, manual upgrade, and power-user import/export navigation.
- Paywall entry points include add-home, add-item, over-limit flows, manual upgrade, and shared-home Pro upsells.
- `HARD_PAYWALL_PREVIEW` forces the blocking wall in DEBUG.
- `FORCE_FREE_TRIAL_PREVIEW` forces trial copy with a seven-day fallback in DEBUG; it does not grant entitlement or StoreKit eligibility.

## Feature Gates

### `FeatureGate`
File: `Cubby/Services/FeatureGate.swift`

- The hard subscription paywall is the primary access model. These legacy limits remain as defense-in-depth creation/sharing checks and are normally unreachable for non-Pro users after onboarding:
  - max owned homes: `1`
  - max owned items per owned home: `10`
- In direct `FeatureGate` evaluation, a non-Pro user with more than 1 owned home is denied creation with `overLimit`; this does not imply normal production access past the hard wall.
- Core Data/AppStore paths should use `FeatureGateDataSource` so counts come from owner/private-store data and ignore collaborator shared homes.
- SwiftData overloads remain for legacy tests and seed/migration support.
- `USE_CORE_DATA_SHARING_STACK` controls the sharing stack and is default-on unless disabled through environment.
- `shareManagementAccess` returns:
  - `hidden` when sharing is disabled, home is missing, or current user is not owner
  - `upgradeRequired` for free owners
  - `allowed` for Pro owners

## Core Data Runtime

### `PersistenceController`
File: `Cubby/Services/PersistenceController.swift`

- Main runtime persistence stack.
- Uses `NSPersistentCloudKitContainer` and Core Data model `Cubby.xcdatamodeld`.
- Loads two stores:
  - `Private.sqlite` with CloudKit private database scope
  - `Shared.sqlite` with CloudKit shared database scope
- Enables persistent history tracking and remote-change notifications on both stores.
- Exposes helpers for `privatePersistentStore()`, `sharedPersistentStore()`, `fetchShares`, `isShared`, and `canEdit`.
- Tests should use `PersistenceController(storeDirectory:)` with a temporary directory.

### `CoreDataAppRepository`
File: `Cubby/AppData/CoreDataAppRepository.swift`

- Maps Core Data entities to app value models.
- Implements home, location, item, share, and feature-gate data-source protocols.
- Keeps collaborator/shared records in the shared store.
- Owner counts for gating should ignore shared-store records.

### `AppStore`
File: `Cubby/AppData/AppStore.swift`

- Main observable state used by SwiftUI views.
- Publishes `AppHome`, `AppStorageLocation`, and `AppInventoryItem`.
- Owns mutations through repository methods.
- Hides left/shared homes through `HiddenSharedHomeIDStore`.
- Runs post-save AI emoji enhancement when supported.

## Migration

### `DataMigrationService`
File: `Cubby/Services/DataMigrationService.swift`

- Migrates legacy SwiftData data into the Core Data private store.
- Records completion with `coreDataMigrationComplete`.
- Startup uses the live SwiftData container when seeding or running in-memory UI/test flows.
- Seed flags regenerate the SwiftData source, but Core Data imports it only while `coreDataMigrationComplete` is false. `SEED_MOCK_DATA` alone does not reset persistent Core Data stores or the migration marker.
- Keep migration idempotent: retries should upsert existing objects and recover after copy failures.
- When adding persistent fields, update both mapping and migration if legacy data should survive.

## CloudKit Sync and Sharing

### `CloudKitSyncSettings`
File: `Cubby/Services/CloudKitSyncSettings.swift`

- Container identifier: `iCloud.com.barronroth.CubbyV2`.
- `CloudKitSyncSettings` enables CloudKit for the legacy SwiftData container by default outside tests; UI tests and XCTest use an in-memory SwiftData source with CloudKit disabled.
- The primary `PersistenceController` separately attaches CloudKit options to both Core Data stores. `DISABLE_CLOUDKIT` does not remove those options, so it is not a fully local-only Core Data mode.
- Launch flags:
  - `DISABLE_CLOUDKIT`
  - `INIT_CLOUDKIT_SCHEMA`
  - `STRICT_CLOUDKIT_STARTUP`
  - `FORCE_CLOUDKIT_AVAILABILITY_AVAILABLE`
  - `FORCE_CLOUDKIT_AVAILABILITY_NO_ACCOUNT`
  - `FORCE_CLOUDKIT_AVAILABILITY_RESTRICTED`
  - `FORCE_CLOUDKIT_AVAILABILITY_UNKNOWN`
  - `FORCE_CLOUDKIT_AVAILABILITY_TEMP_UNAVAILABLE`
  - `FORCE_CLOUDKIT_AVAILABILITY_ERROR`

### Startup policy
- `CloudKitSchemaBootstrapper` initializes the development schema when requested.
- `CloudKitStartupPolicy` allows DEBUG fallback only for legacy SwiftData `ModelContainer` creation errors unless `STRICT_CLOUDKIT_STARTUP` is present.
- Release fallback is local-only if SwiftData container creation fails; Core Data startup failures show `RuntimeInitializationFailureView`.

## Inventory Import / Export

- `InventoryImportExport.swift` owns schemas, parsing, selected-home export construction, validation, matching, and dry-run plans.
- `InventoryImportExportOptionsModel` maps parser/planner output into review UI state.
- `OptionsView` owns JSON/file input, export copy/share, review, and explicit confirmation.
- `CoreDataAppRepository.commitInventoryImportPlan` revalidates permissions and plan freshness, performs one Core Data batch, and rolls back on failure.
- `AppStore.commitInventoryImportPlan` refreshes observable state and starts post-save emoji enhancement.
- Import schema `cubby-import-v1` matches items by normalized title plus normalized location path; photos are unsupported.

### `CloudSyncCoordinator` and `CloudSyncState`
- Model user-facing sync state: checking, syncing, synced, offline, iCloud unavailable, disabled.
- Polls account availability and reacts to remote-change merge notifications.
- Keep tests deterministic by injecting an availability checker.

### `RemoteChangeHandler`
- Observes `.NSPersistentStoreRemoteChange`.
- Merges private and shared store changes into the view context.
- Posts app-level notifications so `AppStore`/sync state can refresh.

### `HomeSharingService`
- Creates and configures `CKShare` for owned homes.
- Resolves stable share URLs.
- Accepts incoming share invitations into the shared persistent store.
- Allows collaborators to leave shared homes.
- Rejects owner leave and already-shared creation cases with `HomeSharingServiceError`.
- `DebugMockHomeSharingService` supports local UX review without real iCloud invites.

### `SharedHomesGateService`
- Runtime gate for shared-home UI.
- `SHARED_HOMES_ENABLED` controls runtime enablement and defaults to true when distribution is enabled.
- `FORCE_ENABLE_SHARED_HOMES` / `FORCE_DISABLE_SHARED_HOMES` are local DEBUG/test overrides.
- `SHARED_HOMES_LOCAL_OVERRIDE` supports env-driven local override.

### `SharingErrorHandler`
- Converts CloudKit/share errors into user-facing presentation copy.
- Handles revoked share cleanup by removing the home from local visible state.

## Photos and Cleanup

### `PhotoService`
- Saves item photos as JPEGs under `Documents/ItemPhotos/`.
- Uses 0.7 compression.
- Maintains an in-memory cache with count and memory limits.
- Photo files are local device data; CloudKit currently syncs metadata, not image bytes.

### `DataCleanupService`
- Cleans orphaned local photos on app startup.
- Reads active file names from Core Data `CDInventoryItem.photoFileName`.
- Do not rewrite this to SwiftData unless the runtime persistence path changes.

### `SyncedPhotoPresenceState`
- Distinguishes no photo, loading, available, and missing-on-device states.
- Missing local files should show explicit UI copy rather than a generic empty image.

## Testing Guidance

- Unit tests must not hit real CloudKit sync.
- SwiftData tests should use `ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)`.
- Core Data tests should use temporary store directories through `PersistenceController(storeDirectory:)`.
- Use injected/stubbed CloudKit availability providers and sharing services.
- Keep RevenueCat tests behind UI-test/debug overrides unless explicitly testing integration wiring.
