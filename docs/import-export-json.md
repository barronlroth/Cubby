# Cubby JSON Import/Export

Cubby supports a local JSON import/export flow for agent-assisted batch inventory entry. The intended workflow is:

1. Export the selected home from Cubby.
2. Give the exported context and a transcript or notes to an external agent.
3. Have the agent produce `cubby-import-v1` JSON.
4. Paste or open that JSON in Cubby.
5. Review the dry-run buckets, then confirm the import.

Cubby does not send inventory data to an AI service in this flow. The JSON is local, user-provided input.

## Export Format

Exports use `cubby-home-context-v1` and include the selected home, existing locations, existing items, and instructions for the agent.

```json
{
  "schemaVersion": "cubby-home-context-v1",
  "exportedAt": "2026-07-05T12:00:00Z",
  "home": {
    "id": "00000000-0000-0000-0000-000000000001",
    "name": "Main Home"
  },
  "locations": [
    {
      "id": "00000000-0000-0000-0000-000000000002",
      "name": "Storage Closet",
      "path": ["Storage Closet"],
      "parentLocationId": null
    },
    {
      "id": "00000000-0000-0000-0000-000000000003",
      "name": "Top Shelf",
      "path": ["Storage Closet", "Top Shelf"],
      "parentLocationId": "00000000-0000-0000-0000-000000000002"
    }
  ],
  "items": [
    {
      "id": "00000000-0000-0000-0000-000000000004",
      "title": "AA Batteries",
      "locationPath": ["Storage Closet", "Top Shelf"],
      "description": "AA only",
      "tags": ["batteries", "household"],
      "emoji": "\uD83D\uDD0B"
    }
  ],
  "instructions": {
    "importSchemaVersion": "cubby-import-v1",
    "matchingRule": "Items match by normalized title plus normalized locationPath in the selected home.",
    "photos": "Photos are not supported in v1."
  }
}
```

## Import Format

Imports target the currently selected home. The only required item fields are `title` and `locationPath`.

```json
{
  "schemaVersion": "cubby-import-v1",
  "items": [
    {
      "title": "AA Batteries",
      "locationPath": ["Storage Closet", "Top Shelf"],
      "description": "Rechargeables only",
      "tags": ["batteries", "rechargeable"],
      "emoji": "\uD83D\uDD0B"
    },
    {
      "title": "USB-C Chargers",
      "locationPath": ["Office", "Blue Bin"],
      "tags": ["electronics", "chargers"]
    }
  ]
}
```

Optional fields may be omitted. When updating an existing item, omitted optional fields preserve the existing Cubby value. Explicit JSON `null` for `description`, `tags`, or `emoji` is also treated as omitted in v1.

Photos and quantity are not supported in v1.

## Matching Rules

- Location paths are strict and complete. `["Top Shelf"]` does not match `["Storage Closet", "Top Shelf"]`.
- Missing locations are created from item `locationPath` values.
- Existing items are matched by normalized `title` plus normalized `locationPath` in the selected home.
- Same title in a different location is a different item.
- Duplicate item targets inside one import block confirmation.
- Ambiguous existing duplicate items block confirmation.
- Read-only shared homes block confirmation.

## Review Buckets

Before writing, Cubby shows:

- Needs fixing
- New locations
- New items
- Updated items
- Unchanged

The import is all-or-nothing. If commit fails, Cubby rolls back the batch instead of leaving partial records.

## Agent Prompt Example

```text
Use the Cubby export JSON as current context. Convert this transcript into cubby-import-v1 JSON.
Match existing items only when the title and full location path clearly refer to the same thing.
Do not invent fuzzy matches. If a location is new, include the full new locationPath.
Do not include photos or quantity.

Transcript:
"Batteries are in the storage closet on the top shelf. The USB-C chargers are in the blue bin in the office."
```
