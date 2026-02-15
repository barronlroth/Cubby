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

## 8) Legacy User and Rollout Behavior

Given very low current user count:

- Prefer shipping this as next post-approval release.

Compatibility notes:

- Older clients (pre-sharing) won’t handle shared-home UX.
- Keep schema changes additive; avoid destructive model changes.
- Gate sharing UI and operations by minimum app version where necessary.

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
