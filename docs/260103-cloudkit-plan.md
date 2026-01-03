# Plan

Integrate CloudKit-backed SwiftData sync for Cubby with an always-on, private-database approach that falls back to local data when iCloud is unavailable. Scope focuses on metadata-only sync (no photo assets yet), TDD with Swift Testing for pure logic, and relying on CloudKit's default merge behavior in v1 (use `modifiedAt` for UI ordering only).

## Scope
- In: SwiftData + CloudKit configuration, model compatibility audit with explicit constraints, migration/merge behavior, conflict handling expectations, offline edits and error handling, tests and validation.
- Out: Shared database/collaboration, photo asset sync (tracked in issue #53), export/import tooling, analytics, custom merge engine, sync status UI (tracked in issue #54).

## Action items
[ ] Audit SwiftData models for CloudKit constraints: optional relationships, no `@Attribute(.unique)`, and default values for all non-optional properties in `Cubby/Models/`.
[ ] Add a debug-friendly kill switch at `ModelContainer` creation time (launch arg or build flag) to select CloudKit vs local configuration before initialization.
[ ] Configure CloudKit container `iCloud.com.barronroth.Cubby` in app entitlements and initialize the SwiftData store with CloudKit enabled in `Cubby/CubbyApp.swift`.
[ ] Implement always-on sync behavior with local fallback when iCloud is unavailable (use the same CloudKit-backed store offline; do not switch to a separate local-only store).
[ ] Define migration policy: silently merge local and cloud records on first sync (even if both exist) and rely on CloudKit's default conflict resolution; use `modifiedAt` for UI ordering only.
[ ] Write Swift Testing unit tests first (TDD) for model invariants and account-status gating / "iCloud unavailable" behavior in `CubbyTests/` (no CloudKit in unit tests).
[ ] Validate with simulator flows: signed-in iCloud, signed-out, iCloud storage full, offline mode; capture any DebugLogger output.
[x] Track future photo asset sync in GitHub issue #53 (compressed images as CloudKit assets).
[x] Track future sync status UI surface in GitHub issue #54.

## Open questions
- None (silent merge on first sync).

## Response
- Merge policy updated to rely on CloudKit's default conflict resolution; `modifiedAt` is for UI ordering only in v1.
- Kill switch moved to `ModelContainer` initialization so config is chosen before the store is created.
- TDD scope clarified to invariants and account-status gating; CloudKit behavior validated via manual flows.
- Model audit item expanded to explicitly list CloudKit constraints.
- Deferred the sync status UI surface to issue #54.
- Clarified "local fallback" as offline use of the same CloudKit-backed store (no separate local-only store).
