---
name: cubby-transcript-import-json
description: Convert rambling user inventory transcripts, notes, voice memos, or chat messages into Cubby's import JSON. Use when a user wants an AI agent to turn natural language about belongings, storage locations, descriptions, tags, or emoji into `cubby-import-v1`, with or without a `cubby-home-context-v1` export as matching context.
---

# Cubby Transcript Import JSON

## Output Contract

Return valid JSON for Cubby's importer:

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

Use `emoji` as an actual emoji character in real output. Omit optional fields when unknown or unchanged.

Required per item:
- `title`: non-empty string, 200 characters or fewer.
- `locationPath`: non-empty array of location names, max 10 segments, each segment non-empty and 100 characters or fewer.

Optional per item:
- `description`: string, 1000 characters or fewer.
- `tags`: array of up to 10 normalized tags.
- `emoji`: string.

Do not include IDs, home data, `locations`, quantities, photos, comments, markdown, or trailing commas in the import JSON.

## Transcript-Only Mode

Use this when no Cubby export is provided.

1. Extract each distinct physical item the user wants tracked.
2. Infer a complete `locationPath` from the transcript. Use path arrays, not a single `"A > B"` string.
3. Create missing locations freely by using the desired path; Cubby will create the location chain during import.
4. Merge repeated mentions of the same title at the same location into one item.
5. Ask a concise clarification instead of producing JSON if an item has no usable location.

Prefer stable, simple names:
- Titles: human display names such as `"Socket Set"`, `"Passport"`, `"Label Maker"`.
- Locations: display names such as `["Garage", "Tool Wall"]`.
- Tags: lower-kebab tags like `"tools"`, `"travel-documents"`, `"batteries"`.
- Descriptions: factual details the user said, not inferred filler.

## Export-Basis Mode

Use this when the user provides Cubby's export JSON (`schemaVersion: "cubby-home-context-v1"`).

The export is context, not the output. Read:
- `locations[].path` as the source of existing full location paths.
- `items[]` as existing item targets.
- `instructions.matchingRule`: items match by normalized title plus normalized `locationPath` in the selected home.

For every transcript item:
1. Match existing locations only by the full path from the export after trimming/collapsing whitespace and ignoring case. Do not use fuzzy or partial matching.
2. If the transcript clearly refers to an exported item, reuse its exact exported `title` and `locationPath` unless the user explicitly renames it.
3. If a location reference is partial but maps unambiguously to exactly one exported full path, use the full exported path.
4. If a partial location is ambiguous, ask a clarification before emitting JSON.
5. If the transcript says a new item belongs in a path not present in the export, use that path; Cubby will create it.
6. If an item title exists in the export but at a different path, this import creates a new item. Only treat it as an update when title plus full location path match.

For updates to existing items:
- Include `description`, `tags`, or `emoji` only when the transcript actually changes or adds that field.
- If adding tags to an existing item, include the full desired tag set, including exported tags that should remain.
- Omit optional fields to preserve existing values.
- Do not use `null`; omitted fields are clearer and preserve existing values.

## Normalization Rules

Cubby will trim leading/trailing whitespace and collapse internal whitespace for titles, locations, and descriptions. Do that before output.

Tags are normalized by the app:
- Lowercase.
- Spaces become `-`.
- Only lowercase letters, digits, and `-` survive.
- Leading/trailing `-` are removed.
- Max length is 30.

Normalize tags yourself and remove duplicates. If a tag would normalize to empty, drop it.

## Blocking Cases

Do not emit final import JSON when:
- Any item lacks a location.
- Two import items normalize to the same title plus same `locationPath`.
- A provided export has multiple existing items with the same normalized title and path, and the transcript targets that duplicate.
- A partial location reference could map to more than one exported path.

In those cases, ask the smallest set of questions needed to make valid import JSON.

## Validation

After drafting JSON, save it to a temporary file and run:

```bash
python3 .agents/skills/cubby-transcript-import-json/scripts/validate_import_json.py /tmp/cubby-import.json
```

With an export basis:

```bash
python3 .agents/skills/cubby-transcript-import-json/scripts/validate_import_json.py /tmp/cubby-import.json --export /tmp/cubby-export.json
```

Fix all `ERROR` lines before presenting final JSON. `WARN` lines are acceptable only when they match the user's intent, such as creating a new location.
