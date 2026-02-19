# Shared Homes Collaboration Architecture (Apple-Native)

Date: 2026-02-15  
Repository: `Cubby`  
Prepared by: Codex architecture pass (parallel codebase scans + Apple docs validation)

## 1) Goal

Enable a user to share a home (and its nested locations/items) with another iCloud user so both can:

- View the same home data
- Add/edit/delete items and locations
- See updates quickly across devices
- Manage participants and permissions with Apple-native UX

## 2) Current Cubby Baseline

Observed from the codebase:

- Persistence is SwiftData with `ModelContainer` in `Cubby/CubbyApp.swift`.
- Cloud sync is enabled via SwiftData `ModelConfiguration(..., cloudKitDatabase: .private("iCloud.com.barronroth.Cubby"))`.
- Models are `Home`, `StorageLocation`, `InventoryItem`.
- There is no current sharing implementation (`CKShare`, shared DB, invite acceptance handlers, sharing controller).
- Photos are local files (`Documents/ItemPhotos`) and are not cloud-synced.
- Sync status UI currently checks account availability and shows a simple status chip.

Important existing assumptions:

- App logic assumes a single homes list from one local store.
- Feature gating counts all homes/items for free-tier limits.
- Home selection state persists with `lastUsedHomeId`.

## 3) Apple Platform Constraints (validated)

### SwiftData managed CloudKit sync is for per-user device sync

Apple’s SwiftData sync article is explicitly framed as syncing “across a person’s devices,” and SwiftData CloudKit configuration exposes `.automatic`, `.private(...)`, and `.none` (no `.shared` scope control in SwiftData’s managed API surface).

Implication:

- SwiftData managed sync alone is not the right primitive for cross-account home collaboration.

### CloudKit collaboration is implemented via share records / shared database

Apple’s collaboration path uses:

- `CKShare`
- System sharing UI (`UICloudSharingController` / ShareLink-based flows)
- Accept-share flow via app/scene delegate callbacks
- Shared database scope (`CKDatabase.Scope.shared`)

### Core Data + NSPersistentCloudKitContainer has first-party sharing support

Apple’s Core Data sharing sample and APIs provide direct support:

- `shareManagedObjects(_:toShare:completion:)`
- `acceptShareInvitationsFromMetadata(_:into:completion:)`
- Private + shared store topology

### Near real-time expectation must be framed correctly

Apple states CloudKit sync timing is system-controlled and not app-configurable. In practice this is often fast (seconds), but not hard real-time.

## 4) Option Analysis

### Option A: Stay on SwiftData managed CloudKit only

What it gives:

- Keeps current stack mostly intact.

Problems:

- No first-party path for home-level cross-user collaboration using SwiftData managed sync alone.
- Would force custom workaround architecture around SwiftData abstractions.

Verdict:

- Do not pursue as the primary solution for shared homes.

### Option B: Migrate persistence layer to Core Data + NSPersistentCloudKitContainer (recommended)

What it gives:

- First-party collaboration model Apple documents and supports.
- Proper private + shared store handling.
- Built-in APIs for creating/managing/accepting shares.
- Most aligned with Notes-style Apple collaboration model.

Costs:

- Moderate/high migration effort from SwiftData.
- Requires data-layer refactor and migration testing.

Verdict:

- Pursue.

### Option C: Hybrid (keep SwiftData for core app, add manual CloudKit records for shared homes)

What it gives:

- Avoids full persistence migration initially.

Problems:

- Two data stacks, duplicate model mapping, high long-term complexity.
- More custom sync/conflict code and more failure modes.

Verdict:

- Not recommended unless migration risk is unacceptable short-term.

## 5) Recommendation

Pursue Option B: move to a Core Data + CloudKit sharing architecture.

Reason:

- It is the most Apple-native, maintainable, and feature-complete route for multi-user collaboration.
- It matches your “stay in Apple ecosystem” requirement and patterns seen in Apple collaboration products.

## 6) Proposed Target Architecture

### 6.1 Store Topology

Use one `NSPersistentCloudKitContainer` with two stores:

- Private store (`databaseScope = .private`) for owner-side data
- Shared store (`databaseScope = .shared`) for accepted shares

UI composes homes from both stores into one list.

### 6.2 Data Model

Keep existing domain shape:

- Home
- StorageLocation (hierarchical)
- InventoryItem

Add collaboration metadata:

- `isSharedHome` (derived/helper)
- `shareIdentifier` (optional, for diagnostics/indexing)
- `ownerName` / `ownerUserRecordName` (optional display metadata)
- `canEdit` (derived from share permissions)

Note:

- Enforce same-home relationship boundaries in app logic. Cross-share relationships are unsupported by Core Data CloudKit sharing.

### 6.3 Sharing Flows

Owner flow:

1. User opens Home menu > “Share Home”.
2. App creates or fetches share for the Home object graph.
3. Present system sharing UI.
4. User invites participants / sets read-only vs read-write.

Participant flow:

1. User taps share URL (Messages/Mail/etc.).
2. App receives `CKShare.Metadata` via scene/app delegate.
3. App accepts invitation into shared persistent store.
4. Shared home appears in home list.

Management flow:

- Re-open share UI from Home settings to add/remove participants or stop sharing.

### 6.4 Permissions

Map share permissions to UI actions:

- Read-only participant: no create/edit/delete actions.
- Read-write participant: full mutations allowed.
- Owner: full control + participant management.

### 6.5 Sync Semantics

- Treat collaboration as eventual consistency (not hard real-time).
- Keep UI optimistic for local edits, with reconciliation on import.
- Preserve current status chip but relabel messaging to avoid “instant” promises.

### 6.6 Photos

Current state: local-only files.

Phase recommendation:

- Phase 1 of sharing: metadata collaboration only (title/description/tags/location/emoji).
- Phase 2: move shared-home photos to CloudKit assets with background fetch/cache and missing-photo placeholders.

## 7) Cubby Impact Map

High-impact areas:

- `Cubby/CubbyApp.swift`: replace SwiftData container bootstrap with Core Data container bootstrap and shared-store support.
- `Cubby/Models/*`: migrate `@Model` entities to Core Data model classes/schema.
- `Cubby/Views/Home/HomeView.swift` + `Cubby/Views/MainNavigationView.swift`: combined private/shared homes list and share actions.
- `Cubby/Views/Items/AddItemView.swift` and edit/delete flows: permission-aware mutation gating.
- `Cubby/Services/FeatureGate.swift`: decide billing behavior for shared homes (count owner-created homes only is usually fairest).
- `Cubby/Services/PhotoService.swift` + `Cubby/Services/DataCleanupService.swift`: shared-photo storage strategy and cleanup safety.
- `Cubby/Services/CloudSyncCoordinator.swift`: evolve status from account-only polling to import/export/share-aware events.

New required integration:

- `CKSharingSupported = true` in `Info.plist`.
- App/scene delegate wiring to handle accepted share metadata and route to accept API.

## 8) Migration Strategy

Recommended migration approach:

1. Introduce repository protocol abstraction first (decouple views from SwiftData direct queries where practical).
2. Build Core Data stack behind feature flag.
3. Add one-time data migration from current local store into Core Data store.
4. Validate parity for non-sharing flows.
5. Enable share flows for internal testing.
6. Roll out progressively (TestFlight cohorts).

Fallback plan:

- Keep local-only mode available behind a runtime kill switch for rapid rollback.

## 9) Testing Strategy

Unit tests:

- Permission matrix (owner vs read-write participant vs read-only participant)
- Share acceptance handling
- Deletion/move invariants in shared homes
- Feature-gate counting rules with shared homes

Integration/device tests:

- Two Apple IDs, invite/accept/edit/delete flows
- Offline edits and later convergence
- Participant removal and access revocation behavior
- Shared-home visibility across app relaunch

Operational checks:

- CloudKit Console monitoring
- Conflict and import/export event telemetry
- User-facing error taxonomy for invite/accept/sync failures

## 10) Risks and Mitigations

Risk: Migration scope may delay roadmap  
Mitigation: Phase by feature flag and ship parity before enabling sharing broadly

Risk: Users expect true real-time behavior  
Mitigation: set UX expectations (“syncing…”, “updated moments ago”), avoid instant guarantees

Risk: Photos are inconsistent at launch if not included  
Mitigation: explicitly mark shared-photo support as later phase and show deterministic placeholders

Risk: Billing model confusion for shared homes  
Mitigation: define and ship clear policy before launch (recommended: ownership-based limits)

## 11) Pursue / Not Pursue Summary

- Pursue: Core Data + CloudKit sharing (Option B)
- Do not pursue as primary path: SwiftData-only managed CloudKit sharing workaround (Option A)
- Avoid unless forced: Hybrid dual-sync architecture (Option C)

## 12) Suggested Implementation Phases

Phase 0 (1 week): architecture spike + prototype share create/accept on minimal model  
Phase 1 (2-3 weeks): Core Data stack + parity migration for existing non-sharing flows  
Phase 2 (2 weeks): sharing UI, invite acceptance, participant permissions  
Phase 3 (1-2 weeks): hardening, telemetry, UX polish, TestFlight rollout  
Phase 4 (later): shared photo assets

---

## References

- SwiftData device-sync guidance: https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices
- SwiftData CloudKit database options: https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct
- CloudKit share sample: https://developer.apple.com/documentation/cloudkit/shared_records/sharing_cloudkit_data_with_other_icloud_users
- Core Data sharing sample: https://developer.apple.com/documentation/coredata/sharing_core_data_objects_between_icloud_users
- Share acceptance in SwiftUI apps: https://developer.apple.com/documentation/coredata/accepting-share-invitations-in-a-swiftui-app
- `UICloudSharingController`: https://developer.apple.com/documentation/uikit/uicloudsharingcontroller
- `CKSharingSupported`: https://developer.apple.com/documentation/bundleresources/information-property-list/cksharingsupported
