# Shared Homes Production Epic Plan

Date: 2026-03-22
Repository: `Cubby`
Audience: product + engineering

## Goal

Ship shared homes as a production-ready feature so two iCloud users can invite, accept, view, and collaboratively edit the same home using Apple's native CloudKit sharing model.

This plan is intentionally high level. It explains what has already been built, why the current hybrid state cannot ship yet, and the remaining work to move from an architecture spike to a reliable production feature.

Update on 2026-03-23:

- The runtime UI/CRUD path has since moved onto the Core Data sharing stack.
- The remaining blockers are migration safety, correct store routing for shared-home writes, and CloudKit production validation.
- Treat any references below to the UI still being SwiftData-driven as historical context, not current branch-workspace behavior.

## Plain-English Summary

Cubby's old single-user architecture was driven by SwiftData models and SwiftData queries. That works for one-user device sync, but it is not the right foundation for cross-account collaboration. Apple's first-party collaboration APIs live in Core Data via `NSPersistentCloudKitContainer`, `CKShare`, and the shared CloudKit database.

So the plan is not "add an old model for fun." The plan is:

1. Keep the existing SwiftData data only long enough to migrate users safely.
2. Use the Core Data + CloudKit sharing stack as the long-term source of truth.
3. Migrate existing user data into the Core Data private store.
4. Point the full app read/write path at that Core Data stack.
5. Harden share creation, acceptance, permissions, and operational behavior.
6. Validate the feature with real users on TestFlight, then ship.

## Why SwiftData Alone Cannot Ship Collaboration

- SwiftData-managed CloudKit sync is appropriate for syncing one user's data across that same user's devices.
- Shared homes require first-party CloudKit sharing primitives:
  - `CKShare`
  - shared database scope
  - share invitation acceptance callbacks
  - owner vs participant permissions
- Apple exposes those collaboration primitives directly in Core Data via `NSPersistentCloudKitContainer`.
- Because of that, shared homes must ultimately run on the Core Data sharing stack, not on the current SwiftData-only runtime path.

## Scope for v1

In scope:
- Home-level sharing
- Invite and accept flow with Apple-native UI
- Read-write collaborators
- Shared metadata sync for homes, locations, items, tags, and emoji
- Migration of existing user data into the collaboration-capable persistence layer
- Production validation and rollback-by-new-build if needed

Out of scope for v1:
- Shared photo asset sync
- Read-only collaborator invitations
- Custom conflict-resolution engine
- Non-iCloud collaboration
- Web/admin collaboration tooling

## Locked Product Decisions

- Use Apple-native iCloud sharing, not a custom invite system.
- Shared homes are an owner-paid premium feature.
- A Pro owner can invite free collaborators into shared homes.
- Shared homes and shared items do not count against collaborator free-tier limits.
- Collaborators do not get Pro globally; they only get access inside homes owned by a Pro owner.
- Free users can still keep and use their own personal free home(s) within normal free-tier limits.
- v1 ships with read-write collaborators only; do not expose read-only invites yet.
- Treat sync as eventual consistency, not hard real-time.
- Ship metadata collaboration first; shared photos remain a later phase.
- If access is revoked, the shared home should disappear on sync with no custom removal UX in v1.
- No remote kill switch is required for the first launch; rollback-by-new-build is acceptable while the app has no real user base.

## Current State

### What Has Been Done

- [x] Architecture decision made: shared homes will use Core Data + CloudKit sharing, not SwiftData-only sync.
- [x] Technical design and collaboration architecture docs are in place.
- [x] Core Data model exists for `Home`, `StorageLocation`, and `InventoryItem`.
- [x] `PersistenceController` exists with private and shared CloudKit-backed stores.
- [x] One-time migration service exists to copy existing SwiftData data into the Core Data private store.
- [x] `HomeSharingService` exists for share creation, fetching shares, permission lookup, participant access, and invite acceptance.
- [x] App lifecycle wiring exists for CloudKit share acceptance.
- [x] Share UI exists in the home screen and uses the system sharing controller.
- [x] Debug mock sharing modes exist for owner/read-write/read-only UX review.
- [x] Read-only permission gating exists across add/edit/delete item and location flows.
- [x] Remote change handling and basic sharing error handling exist.
- [x] Targeted unit tests exist for migration, sharing service behavior, permission gating, remote change handling, and error handling.

### What Is True Right Now

- The runtime UI and CRUD path are Core Data-backed.
- The sharing stack and the normal app path now use the same persistence layer.
- SwiftData remains only as a legacy migration source and debug seed source.
- Migration hardening and CloudKit/container validation are still incomplete.

### Why It Still Cannot Ship

The main blockers are now correctness and validation, not architecture:

- migration must not silently mark success from an unavailable or fallback legacy source
- shared-home writes must always target the correct persistent store
- real CloudKit production sharing still needs end-to-end validation on the chosen container

## Production Blockers

- [x] Replace the current dual-stack runtime with a single source of truth for app data.
- [x] Ensure every home, location, and item visible in the app comes from the collaboration-capable Core Data stack.
- [ ] Ensure migration is retry-safe and source-aware for real user data.
- [ ] Ensure all create/edit/delete flows write to the same store that CloudKit sharing uses.
- [ ] Ensure accepted shared homes appear in the main homes list without any bridging gaps.
- [ ] Finish the billing and gating policy for shared homes on the production runtime path.
- [ ] Validate the feature with real Apple IDs and real CloudKit production behavior.

## Epic Plan

### Phase 0: Freeze the Direction

Status: mostly done

Objective:
- Lock the decision that Core Data + CloudKit sharing is the permanent collaboration architecture.
- Stop treating the current Core Data stack as an experiment.

Exit criteria:
- No remaining ambiguity about whether production shared homes will ship on SwiftData or Core Data.
- Product and engineering both align on metadata-only v1 scope.

### Phase 1: Make Core Data the Source of Truth

Status: mostly done on the current branch workspace

Objective:
- Keep the app on a single persistence runtime.
- Ensure the same store powers normal CRUD and shared-home collaboration.

Work:
- [x] Introduce a repository/data-access layer so views are no longer tightly coupled to SwiftData `@Query`.
- [x] Rework home, location, and item fetching to come from Core Data-backed repositories or adapters.
- [ ] Rework the remaining shared-home mutation edge cases so every write targets the correct store.
- [x] Remove the current mismatch where SwiftData drives the UI while Core Data drives sharing.

Exit criteria:
- A home created in the app is immediately shareable because it already exists in the collaboration-capable store.
- An accepted shared home appears in the same home list as private homes because the UI is reading the correct store.

### Phase 2: Complete Data Migration

Status: partial

Objective:
- Migrate existing users cleanly from the current SwiftData world to the Core Data world.

Work:
- [ ] Harden one-shot migration behavior for real user datasets.
- [ ] Define and test idempotent migration behavior for retries, partial failure, and app relaunch.
- [ ] Ensure migration completion markers and reset fallback behavior are production-safe.
- [ ] Validate that `lastUsedHomeId`, onboarding state, and other persisted app assumptions survive migration cleanly where appropriate.

Exit criteria:
- Existing users keep their homes, locations, and items after upgrade.
- Migration failures fail safe with a recovery path instead of leaving users in a broken split-store state.

### Phase 3: Finish End-to-End Share Flows

Status: partial

Objective:
- Make share creation, invite acceptance, and share management reliable for real users.

Work:
- [ ] Verify owner share creation against real CloudKit production containers.
- [ ] Verify invite acceptance on a second Apple ID.
- [ ] Validate manage-share and stop-sharing behavior through the system sharing UI.
- [ ] Confirm participant changes propagate correctly into the app state.
- [ ] Handle revocation/removal cleanly when a shared home is no longer available.

Exit criteria:
- User A can share a home with User B.
- User B can accept the invite and see the home.
- Owner and collaborator both see expected participant state and permission behavior.

### Phase 4: Finish Permission and Billing Semantics

Status: partial

Objective:
- Make sure collaboration rules and monetization rules are coherent.

Work:
- [x] Lock and document the production billing policy for shared homes.
- [ ] Update `FeatureGate` behavior so only owners pay for shared homes and collaborator-visible homes/items do not consume collaborator limits.
- [ ] Ensure the owner must be Pro to initiate sharing.
- [ ] Ensure read-write collaborators can fully use allowed mutation paths without hitting owner-only free-tier limits.
- [ ] Ensure owner-specific actions are limited to owners.

Exit criteria:
- Free-tier behavior is documented, tested, and defensible.
- No mutation path bypasses share permissions.

### Phase 5: Hardening and Observability

Status: partial

Objective:
- Make the feature diagnosable, safe to roll out, and recoverable when CloudKit behaves badly.

Work:
- [ ] Improve user-facing error messages for share acceptance, revocation, and CloudKit failures.
- [ ] Add structured logging around share creation, acceptance, participant changes, and migration outcomes.

Exit criteria:
- Engineering can diagnose whether failures are migration, permissions, CloudKit account state, or invite-flow issues.

### Phase 6: Production Validation

Status: not done

Objective:
- Prove the feature works in real-world conditions before broad rollout.

Work:
- [ ] Run a real two-Apple-ID TestFlight matrix:
  - invite
  - accept
  - read-write collaborator
  - owner edits
  - participant edits
  - revoke/remove participant
  - app relaunch persistence
- [ ] Run offline/online and eventual-convergence checks.
- [ ] Validate CloudKit production schema and entitlements.
- [ ] Verify upgrade behavior from pre-sharing builds.

Exit criteria:
- Shared homes work end-to-end on TestFlight between real users.
- No blocker regressions appear in normal non-sharing user journeys.

### Phase 7: Rollout

Status: not started

Objective:
- Ship safely.

Work:
- [ ] Enable for internal testers first.
- [ ] Expand to a small TestFlight cohort.
- [ ] Review logs, error rates, acceptance success rate, and migration outcomes.
- [ ] Roll forward gradually to full production availability.

Exit criteria:
- Shared homes can be enabled broadly with confidence.
- Rollback path is documented as "ship a fix build" for the initial release.

## Remaining Product Questions

- What should happen if the owner loses Pro after already sharing homes?
  - Option A: existing shared homes keep working for v1, and downgrade enforcement comes later.
  - Option B: existing shared homes stop allowing collaboration.
  - Option C: existing shared homes become read-only.

This is the main remaining product-policy question that still affects implementation.

## Ship-Risk Ranking

Must fix or validate before production:
- Existing-user migration works safely and repeatably.
- Two real users can invite, accept, edit, move, delete, and relaunch successfully.
- Owner-only billing semantics are enforced correctly in shared homes.
- Revoke/remove participant flow removes access cleanly.
- Offline edits converge sanely after reconnect.

Can accept for v1:
- No remote kill switch.
- No read-only collaborator invitations.
- No custom participant-management UI.
- No shared photos.
- No custom "access removed" messaging.

## Milestones

- Milestone A: single-source-of-truth runtime
- Milestone B: migration proven
- Milestone C: two-user TestFlight collaboration proven
- Milestone D: rollout controls proven
- Milestone E: production launch

## Risks

- Dual-store bugs during the transition period
- Migration edge cases for existing users
- CloudKit environment/schema surprises between development and production
- Permission edge cases that allow a mutation path incorrectly
- Monetization ambiguity if shared-home counting is not finalized before ship

## Validation Checklist

- [ ] Unit tests cover repository/runtime data path, migration behavior, permission matrix, and feature gating.
- [ ] Integration tests cover share creation, acceptance, revocation, and remote changes where practical.
- [ ] Manual TestFlight validation covers at least two real Apple IDs.
- [ ] Existing onboarding, add home, add item, edit item, delete item, and location-management flows are re-verified.

## Work Explicitly Deferred Until After v1

- [ ] Shared photo asset sync
- [ ] Rich presence / real-time collaboration indicators
- [ ] Non-Family custom sponsor billing logic
- [ ] Custom conflict resolution beyond the default CloudKit/Core Data behavior

## Definition of Done

Shared homes is ready for production when all of the following are true:

- The app runs on a single collaboration-capable persistence path.
- Existing users migrate safely.
- A real owner can invite a real participant on TestFlight.
- The participant can accept and use the shared home according to permission level.
- Billing and feature-gate behavior are final and tested.
- Runtime rollout controls and rollback behavior are in place.
- Non-sharing users do not regress.
