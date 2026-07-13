# Cubby JSON Import/Export Plan

## Goal

Build a hidden power-user Import/Export surface for the selected Cubby home.

The feature is primarily for agent-assisted batch inventory capture: Cubby exports the current home structure and inventory context, an external agent uses that context plus a transcript to produce JSON, and Cubby imports that JSON after a dry-run review.

Issue: https://github.com/barronlroth/Cubby/issues/16

## Product Decisions

- V1 includes both export and import because export gives the external agent enough context to map transcript references to existing Cubby locations and items.
- This is mostly for Barron/power users, not a mainstream onboarding path.
- Entry point: rename the current Cubby Pro menu item/sheet to `Options`, keep subscription management inside it, and add Import/Export actions there.
- Import targets the currently selected home only.
- Import is all-or-nothing: validate and preview the full plan before writing anything.
- Cubby performs strict matching only. No fuzzy location or item inference inside the app.
- Missing location paths are allowed and should be created during import.
- Existing items are upserted: match by normalized title plus normalized location path in the selected home. If matched, update only fields present in JSON; omitted fields stay unchanged.
- Same title in a different location is not a duplicate.
- Import should not create duplicate items for the same normalized title plus location path. Duplicates inside the JSON or ambiguous existing matches block import until fixed.
- No quantity field in v1.
- No photos in v1.
- Tags, description, and emoji are optional.
- New imported items without emoji should use the existing fallback/random emoji path.
- Collaborators with write access can import; read-only collaborators cannot.
- Ignore free/pro limits for this feature planning because the app is expected to move toward hard paywall.
- Review screen uses friendly labels, not developer/schema jargon.

## Recommended JSON Contract

Start with plain JSON. Do not create a ZIP, package, or custom `.cubbyhouse` file in v1. A custom UTType/file extension can wrap the same JSON later if file-opening polish becomes useful.

Export shape:

```json
{
  "schemaVersion": "cubby-home-context-v1",
  "exportedAt": "2026-07-05T00:00:00Z",
  "home": {
    "id": "UUID",
    "name": "Main Home"
  },
  "locations": [
    {
      "id": "UUID",
      "name": "Storage Closet",
      "path": ["Storage Closet"],
      "parentLocationId": null
    }
  ],
  "items": [
    {
      "id": "UUID",
      "title": "AA Batteries",
      "locationPath": ["Storage Closet", "Top Shelf"],
      "description": "AA only",
      "tags": ["batteries", "household"],
      "emoji": "🔋"
    }
  ],
  "instructions": {
    "importSchemaVersion": "cubby-import-v1",
    "matchingRule": "Items match by normalized title plus normalized locationPath in the selected home.",
    "photos": "Photos are not supported in v1."
  }
}
```

Import shape:

```json
{
  "schemaVersion": "cubby-import-v1",
  "items": [
    {
      "title": "AA Batteries",
      "locationPath": ["Storage Closet", "Top Shelf"],
      "description": "AA only",
      "tags": ["batteries", "household"],
      "emoji": "🔋"
    }
  ]
}
```

Optional future import fields, not required for v1:

- `locations`: explicit location declarations. V1 can infer missing locations from item `locationPath`.
- `clientId`: stable temporary external id for better preview diagnostics.
- `clearDescription` / `clearTags` / `clearEmoji`: explicit clearing behavior. V1 should not clear omitted fields.

## Blocking Import Errors

These should appear in the review screen and disable confirmation:

- Malformed JSON.
- Unsupported `schemaVersion`.
- Missing or empty item `title`.
- Missing or empty item `locationPath`.
- Title longer than existing item title limits.
- Description longer than existing description limits.
- Invalid tags after normalization, too many tags, or tags over length limits.
- Location path segment is empty or too long.
- Location path would exceed the app nesting depth limit.
- Selected home is read-only for the current user.
- The import JSON contains duplicate normalized item targets.
- The existing home already has multiple items matching the same normalized title plus normalized location path, making the upsert ambiguous.
- A location creation plan conflicts with existing sibling names after normalization in a way the importer cannot resolve.
- Core Data save fails during commit.

Non-blocking review buckets:

- New locations.
- New items.
- Updated items.
- Unchanged items.
- Skipped duplicates, only if the duplicate is exact and intentionally treated as unchanged. Otherwise duplicates should be blocking.

## TDD Strategy

Use Swift Testing for planner, schema, validation, export, and repository-level tests. Use XCTest only for UI automation. Keep tests isolated and parallel-safe with temporary Core Data stores and no simulator dependency unless testing UI.

The single available iOS simulator is a shared scarce resource, so only one thread should run UI tests at a time. Unit tests can run independently when they do not boot the simulator.

### Red-Green-Refactor Sequence

1. Add failing tests for decoding supported and unsupported import schema versions.
2. Add failing tests for export JSON from a seeded in-memory Core Data home.
3. Add failing tests for strict location path matching and missing-location planning.
4. Add failing tests for item upsert matching by normalized title plus normalized location path.
5. Add failing tests for omitted fields preserving existing item values.
6. Add failing tests for duplicate targets inside import JSON.
7. Add failing tests for ambiguous existing item matches.
8. Add failing tests for validation errors: title, description, tags, empty path segment, and max nesting depth.
9. Add failing tests for atomic commit: if one operation fails, no created locations/items/updates remain.
10. Add failing UI test for opening Options, pasting JSON, reviewing plan, and confirming import.

### Likely Test Files

- `CubbyTests/InventoryImportExportSchemaTests.swift`
- `CubbyTests/InventoryImportExportPlannerTests.swift`
- `CubbyTests/InventoryImportExportCommitTests.swift`
- `CubbyUITests/InventoryImportExportUITests.swift`

## Implementation Slices

### Thread A: Schema, Export, Planner

Owns:

- Import/export Codable DTOs.
- Export builder for selected home context.
- Import parser.
- Dry-run planner.
- Strict location path matching.
- Upsert matching rules.
- Validation error model.
- Unit tests for schema, export, and planning.

Does not own:

- SwiftUI screens.
- Commit/persistence mutation.
- Xcode project release/version changes.

Expected output:

- A plan model that UI can render.
- No writes during dry-run.
- Tests prove planning does not mutate state.

### Thread B: Options UI and Review Screen

Owns:

- Rename/reframe `ProStatusView` entry point as `Options`.
- Keep subscription status/restore/upgrade controls working.
- Add Import/Export actions inside Options.
- Add paste/import JSON screen.
- Add friendly review screen buckets.
- Add export copy/share affordance.
- UI tests or previews with mocked plan data where possible.

Does not own:

- Import matching rules.
- Repository batch mutation.
- Schema design beyond consuming Thread A DTOs.

Expected output:

- UI can display plan results from mocked or real planner.
- Confirmation is disabled when blocking errors exist.

### Thread C: Atomic Commit Path

Owns:

- Apply a reviewed plan all-or-nothing.
- Repository-level batch creation/update if needed.
- Preserve existing fields when import omits them.
- Create missing locations in correct private/shared store.
- Respect share permissions.
- Unit tests for rollback/no-partial-write behavior.

Does not own:

- UI.
- Export.
- JSON parsing beyond consuming the plan model.

Expected output:

- One commit API callable from `AppStore`.
- Tests prove successful batch import and rollback on failure.

### Thread D: Integration, Docs, Cleanup

Runs after A/B/C are integrated.

Owns:

- End-to-end UI test on the single simulator.
- Realistic JSON fixtures.
- Docs/example showing transcript-to-agent-to-Cubby flow.
- Issue/PR cleanup notes for #16.

Does not own:

- Core implementation decisions unless defects are found.

## Coordination Rules

- Do not use multi-agent sub-agents for implementation; use separate Codex CLI sessions and separate git worktrees.
- Worktree branches should use `codex/import-export-*`.
- Main worktree remains on `main`.
- Avoid project version/build-number changes until a branch is intended to trigger Xcode Cloud/TestFlight.
- Do not touch `.asc/artifacts/` or `artifacts/`.
- No broad refactors of `HomeView` or `ProStatusView` beyond the Options entry point unless needed.
- If UI work needs a simulator, coordinate so only one thread uses it at a time.
- Each worker must preserve unrelated local changes and avoid reverting another thread's work.

## Initial Delegation

Start Thread A first. Thread B can begin after Thread A has committed the DTO and plan model names. Thread C should wait for Thread A's plan model. Thread D waits until A/B/C have an integration branch.

Initial Thread A prompt:

```text
You are working in a dedicated worktree for /Users/barron/Developer/Cubby.

Task: implement the TDD-first schema/export/dry-run planner slice for issue #16. Do not build UI and do not implement persistence commit.

Read AGENTS.md, Cubby/Services/AGENTS.md, CubbyTests/AGENTS.md, and docs/plans/import-export.md before coding.

Start by writing failing Swift Testing unit tests for:
- decoding supported and unsupported import schema versions;
- exporting selected-home context with locations and existing items;
- strict location path matching;
- planning missing locations from item locationPath;
- upsert matching by normalized title plus normalized locationPath;
- preserving existing fields when import omits optional fields in an update plan;
- duplicate targets inside the import JSON;
- ambiguous existing matches in the selected home;
- validation errors for title, description, tags, empty path segment, and max nesting depth;
- proving dry-run planning does not mutate Core Data/AppStore state.

Then make those tests pass with narrowly scoped app code.

Use Swift Testing with #expect/#require. Keep tests isolated with temporary Core Data stores. Do not use the simulator. Do not change version/build numbers. Do not touch .asc/artifacts or artifacts.

Return a final summary with changed files and exact tests run.
```
