# Shared Homes Tech Design (Core Data + CloudKit Sharing)

Date: 2026-02-15  
Related issue: https://github.com/barronlroth/Cubby/issues/63  
Prerequisite architecture doc: `docs/260215-shared-homes-collab-architecture.md`

## 1) Decision

Implement shared homes using `NSPersistentCloudKitContainer` with:

- One private store (`CKDatabase.Scope.private`)
- One shared store (`CKDatabase.Scope.shared`)

Reason:

- Apple provides first-party APIs for share create/manage/accept in this stack.
- This matches the collaboration model required for cross-user homes.

## 2) Scope

In scope:

- Home-level sharing and participant collaboration
- Read-only vs read-write permission enforcement
- Share invitation acceptance in SwiftUI app lifecycle
- Private + shared homes unified in app UI
- Metadata collaboration (homes, locations, items, tags, emoji)

Out of scope (v1):

- Shared photo asset sync
- Custom conflict-resolution engine
- Web/admin collaboration tooling

## 2.1 Product Policy Decisions (Locked)

Subscription sharing model (v1):

- Use Apple-native Family Sharing for paid access.
- Do not implement custom "home sponsor unlocks all participants" logic in v1.
- Result: household members in the same Apple Family can share one subscription; non-family participants still need their own paid access where gated.

Migration policy:

- Use best-effort migration from existing local SwiftData data.
- If migration fails, fall back to a controlled reset path and recreate a clean store.
- Because current user count is near zero, fail-safe reset is acceptable for v1.

Rollout gate policy:

- Use a two-layer rollout gate:
  - Distribution gate: phased App Store/TestFlight rollout.
  - Runtime gate: server-driven feature flag (`sharedHomesEnabled`) fetched from a lightweight remote config source, defaulting to `false` when unavailable on first launch.
- Keep an emergency kill-switch path so shared-home UI and write paths can be disabled without waiting for a new binary.

## 3) High-Level Architecture

## 3.1 Persistence Layer

Introduce `PersistenceController` responsible for:

- Building `NSPersistentCloudKitContainer`
- Configuring two persistent stores:
  - `Private.sqlite` with `databaseScope = .private`
  - `Shared.sqlite` with `databaseScope = .shared`
- Enabling:
  - `NSPersistentHistoryTrackingKey = true`
  - `NSPersistentStoreRemoteChangeNotificationPostOptionKey = true`

## 3.2 Collaboration Layer

Introduce `HomeSharingService` responsible for:

- Creating a new share for a home graph
- Fetching existing share for a home
- Updating share metadata/title
- Exposing `canEdit` for selected home
- Accepting share invitations from metadata

Likely underlying APIs:

- `shareManagedObjects(_:to:completion:)`
- `fetchSharesMatchingObjectIDs`
- `persistUpdatedShare`
- `acceptShareInvitationsFromMetadata(_:into:completion:)`

## 3.3 App Lifecycle Integration

Add:

- `AppDelegate` + `SceneDelegate` bridge for SwiftUI app
- `windowScene(_:userDidAcceptCloudKitShareWith:)` handler

Requirements:

- `CKSharingSupported = true` in `Info.plist`

## 4) Data Model Strategy

## 4.1 Entity Mapping

Map current SwiftData models to Core Data entities:

- `Home`
- `StorageLocation`
- `InventoryItem`

Maintain current logical IDs:

- Preserve `UUID` id fields for app-level identity continuity.

## 4.2 Relationship Rules

Ensure:

- All relationships CloudKit-compatible
- No cross-home graph links
- No cross-share relationships in app logic

When sharing a home:

- Entire object graph for that home is moved into the share zone by API behavior.

## 4.3 Share Metadata Helpers

Add derived helpers (not necessarily persistent fields):

- `isSharedHome`
- `canEdit`
- `isOwnedByCurrentUser`

Optional persistent metadata fields (if needed for UI):

- `shareRecordName`
- `ownerDisplayName`

## 5) UI/UX Changes

## 5.1 Home Menu

Add actions:

- `Share Home` (owner)
- `Manage Share` (owner/participant context-sensitive)

Use system CloudKit sharing UI via SwiftUI wrapper for `UICloudSharingController`.

## 5.2 Home List

Show unified homes list (private + shared) with subtle badge:

- `Shared` badge for non-private homes
- Owner/permission hint in detail/settings UI

## 5.3 Mutation Controls

Before create/edit/delete operations:

- Check `canEdit` for selected home
- Disable/hide mutation actions for read-only participants
- Keep view/search enabled

## 6) Service and Code Touchpoints

Expected high-impact files:

- `Cubby/CubbyApp.swift`
- `Cubby/Models/*` (migration target)
- `Cubby/Views/Home/HomeView.swift`
- `Cubby/Views/MainNavigationView.swift`
- `Cubby/Views/Items/AddItemView.swift`
- `Cubby/Services/FeatureGate.swift`
- `Cubby/Services/CloudSyncCoordinator.swift`

New files likely:

- `Cubby/Services/PersistenceController.swift`
- `Cubby/Services/HomeSharingService.swift`
- `Cubby/AppDelegate.swift`
- `Cubby/SceneDelegate.swift`
- `Cubby/Views/Home/CloudSharingControllerRepresentable.swift`

## 7) Migration Plan

## 7.1 Phase 0: Skeleton + Feature Flag

- Build Core Data stack behind runtime flag (`USE_CORE_DATA_SHARING_STACK`).
- Keep existing SwiftData path available during development.

## 7.2 Phase 1: Data Parity

- Implement repository operations for homes/locations/items on Core Data stack.
- Validate parity for non-sharing workflows.

## 7.3 Phase 2: Sharing Flows

- Implement share create/manage UI
- Implement share invitation acceptance
- Merge private + shared homes in queries/view models

## 7.4 Phase 3: Hardening

- Permission gating in all mutation paths
- Remote-change/state sync polish
- Error handling and recovery UX

## 7.5 Migration Execution Policy (Best Effort)

- Attempt one-shot migration at first launch on the new stack.
- On success: mark migration complete and continue normally.
- On failure:
  - Capture structured error telemetry/logging.
  - Show a concise user-facing recovery message.
  - Execute reset fallback and continue with clean data store.

## 8) Legacy User and Rollout Behavior

Given very low current user count:

- Prefer shipping this as next post-approval release.

Compatibility notes:

- Older clients (pre-sharing) won’t handle shared-home UX.
- Keep schema changes additive; avoid destructive model changes.
- Gate sharing UI and operations by minimum app version where necessary.

## 8.1 Rollout Gate Details

Definition:

- "Rollout gate" means controlling exposure of shared homes independently from code shipping.

Recommended implementation:

- Gate read/write entry points behind `SharedHomesGateService`.
- `SharedHomesGateService` resolves enabled state from:
  1. Remote flag (`sharedHomesEnabled`) with cached value + TTL.
  2. Local emergency override for internal builds/tests.
  3. Safe default `false` when no remote value exists yet.

Why this is recommended:

- Lets us ship dark, enable for a small cohort, and instantly disable if production issues appear.
- Reduces blast radius during first collaboration rollout.

## 9) Test Strategy

## 9.1 Unit Tests

- Permission matrix tests:
  - owner
  - read-write participant
  - read-only participant
- Share acceptance routing tests
- Home graph mutation constraints

## 9.2 Integration Tests

- Two real Apple IDs on TestFlight:
  - invite/accept
  - add/edit/delete convergence
  - participant removal/revocation
- Offline/online transitions and eventual convergence

## 9.3 Regression Tests

- Existing onboarding/home/item flows
- Feature-gate counts and paywall triggers
- Last-used home and location restore behavior

## 9.4 TDD Quality Gate (Required)

- Every implementation slice must follow Red -> Green -> Refactor:
  1. Add/modify tests first and run suite to confirm failures for the new behavior.
  2. Implement minimal code to make tests pass.
  3. Refactor while keeping tests green.
- PRs must include evidence of both states:
  - failing test output before implementation
  - passing test output after implementation
- Shared-homes feature work is blocked from merge without this evidence.

## 10) Risks and Mitigations

Risk: Migration regressions in existing CRUD  
Mitigation: feature-flag rollout + parity test suite before enabling sharing UI

Risk: Perceived sync lag  
Mitigation: communicate “syncing” state and avoid “instant” language

Risk: Shared photo expectations in v1  
Mitigation: explicit placeholder UX + roadmap callout

Risk: Free-tier logic ambiguity with shared homes  
Mitigation: document policy in code/tests (recommend owner-based limits)

## 11) Exit Criteria for v1

- Share home end-to-end works between two TestFlight users
- Read-only mode enforced correctly
- No blocker regressions in existing non-sharing user journeys
- Monitoring/logging sufficient to diagnose share accept/sync failures
- TDD gate evidence present for all merged shared-home slices
