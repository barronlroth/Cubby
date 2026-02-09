# CloudKit Inventory Sync Plan (TDD-First)

## Goal
Keep inventory metadata synced via SwiftData + CloudKit private database while maintaining offline-first behavior and deterministic test coverage.

## Scope and Defaults
- Metadata-only sync for this release (`InventoryItem.photoFileName` syncs, photo bytes stay local).
- iCloud unavailable state remains non-blocking (local CRUD allowed).
- Existing SwiftData + CloudKit architecture is retained.
- `DISABLE_CLOUDKIT` remains available as rollback kill switch.

## Phase Status

### Phase 1: Startup and Schema Hardening
- [x] Added startup/config launch args:
  - `INIT_CLOUDKIT_SCHEMA`
  - `STRICT_CLOUDKIT_STARTUP`
  - `FORCE_CLOUDKIT_AVAILABILITY_*`
- [x] Added strict startup policy with debug fallback control.
- [x] Added debug-only schema bootstrap path.
- [x] Switched availability provider default to explicit container ID.
- [x] Added tests for settings, availability mapping, startup fallback, schema init policy.

### Phase 2: Sync-State Observability + UX
- [x] Added `CloudSyncState`.
- [x] Added `@MainActor` `CloudSyncCoordinator`.
- [x] Injected coordinator in `HomeSearchContainer`.
- [x] Added sync chip to main navigation with states:
  - Synced
  - Syncing
  - Offline
  - iCloud Off
- [x] Applied iOS 26 Liquid Glass styling on the sync chip with fallback.
- [x] Added unit tests for state transitions and coordinator lifecycle.
- [x] Added UI tests for sync chip forced-availability states.

### Phase 3: Metadata-Only Photo Behavior
- [x] Added `SyncedPhotoPresenceState` to model local-vs-synced photo presence.
- [x] Added explicit UI state: `"Photo not on this device yet"` in item detail/edit flows.
- [x] Added `SEED_MISSING_LOCAL_PHOTO` mock-seed launch path for deterministic UI validation.
- [x] Added tests for missing-local-photo behavior:
  - Unit: `SyncedPhotoPresenceStateTests`
  - UI: `MissingLocalPhotoUITests`

### Phase 4: Concurrency and Performance Guardrails
- [x] Kept sync coordination on `@MainActor`.
- [x] Used structured polling tasks with explicit cancellation on scene phase changes.
- [x] Added non-blocking refresh test coverage and cancellation tests.

### Phase 5: Acceptance and Release Gates
- [ ] Run full project test suite (`xcodebuild ... test`) before release branch cut.
- [ ] Execute manual two-device CloudKit matrix (create/edit/delete/offline/reconnect).
- [ ] Validate production CloudKit schema promotion procedure.
- [ ] Re-verify release entitlements and rollback path (`DISABLE_CLOUDKIT`).

## TDD Traceability
- Every implemented story in Phases 1-4 was delivered Red -> Green -> Refactor with targeted test execution before moving to the next story.

## Implemented/Updated Interfaces
- `CloudKitSyncSettings` additions:
  - `strictStartup`
  - `shouldInitializeCloudKitSchema`
  - `forcedAvailability`
- `CloudSyncState` (new).
- `CloudSyncCoordinator` (new, `@MainActor`).
- `CloudKitSchemaBootstrapper` (new).
- `CloudKitStartupPolicy` (new).
- `SyncedPhotoPresenceState` (new).

## Key Test Commands (targeted)
```bash
xcodebuild -project Cubby.xcodeproj -scheme Cubby \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1' \
  -parallel-testing-enabled NO CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO test \
  -only-testing:CubbyTests/CloudKitSyncSettingsTests \
  -only-testing:CubbyTests/CloudKitAvailabilityTests \
  -only-testing:CubbyTests/CloudKitStartupBehaviorTests \
  -only-testing:CubbyTests/CloudSyncStateTests \
  -only-testing:CubbyTests/CloudSyncCoordinatorTests \
  -only-testing:CubbyTests/SyncedPhotoPresenceStateTests \
  -only-testing:CubbyUITests/CloudSyncStatusUITests \
  -only-testing:CubbyUITests/MissingLocalPhotoUITests
```
