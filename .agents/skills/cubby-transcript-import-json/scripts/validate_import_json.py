#!/usr/bin/env python3
"""Validate Cubby import JSON generated from transcripts."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


IMPORT_SCHEMA_VERSION = "cubby-import-v1"
EXPORT_SCHEMA_VERSION = "cubby-home-context-v1"
MAX_NESTING_DEPTH = 10
MAX_TITLE_LENGTH = 200
MAX_LOCATION_SEGMENT_LENGTH = 100
MAX_DESCRIPTION_LENGTH = 1000
MAX_TAGS = 10
MAX_TAG_LENGTH = 30


def read_json(path: str) -> Any:
    if path == "-":
        text = sys.stdin.read()
    else:
        text = Path(path).read_text(encoding="utf-8")
    return json.loads(text)


def clean_display(value: str) -> str:
    return " ".join(value.strip().split())


def normalize_key(value: str) -> str:
    return clean_display(value).lower()


def path_key(path: list[str]) -> tuple[str, ...]:
    return tuple(normalize_key(segment) for segment in path)


def target_key(title: str, path: list[str]) -> tuple[str, tuple[str, ...]]:
    return normalize_key(title), path_key(path)


def format_tag(value: str) -> str:
    lowered = value.lower().replace(" ", "-")
    filtered = "".join(ch for ch in lowered if ("a" <= ch <= "z") or ch.isdigit() or ch == "-")
    return filtered[:MAX_TAG_LENGTH].strip("-")


def as_object(value: Any, label: str, errors: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        errors.append(f"ERROR: {label} must be a JSON object.")
        return {}
    return value


def validate_import(document: Any) -> tuple[list[str], list[str], list[dict[str, Any]]]:
    errors: list[str] = []
    warnings: list[str] = []
    items_for_context: list[dict[str, Any]] = []

    root = as_object(document, "root", errors)
    if root.get("schemaVersion") != IMPORT_SCHEMA_VERSION:
        errors.append(f"ERROR: schemaVersion must be {IMPORT_SCHEMA_VERSION!r}.")

    raw_items = root.get("items")
    if not isinstance(raw_items, list):
        errors.append("ERROR: items must be an array.")
        return errors, warnings, items_for_context

    seen_targets: dict[tuple[str, tuple[str, ...]], int] = {}

    for index, raw_item in enumerate(raw_items):
        prefix = f"items[{index}]"
        if not isinstance(raw_item, dict):
            errors.append(f"ERROR: {prefix} must be an object.")
            continue

        title = raw_item.get("title")
        if not isinstance(title, str):
            errors.append(f"ERROR: {prefix}.title must be a string.")
            cleaned_title = ""
        else:
            cleaned_title = clean_display(title)
            if not cleaned_title:
                errors.append(f"ERROR: {prefix}.title cannot be empty.")
            if len(cleaned_title) > MAX_TITLE_LENGTH:
                errors.append(f"ERROR: {prefix}.title must be {MAX_TITLE_LENGTH} characters or fewer.")
            if cleaned_title != title:
                warnings.append(f"WARN: {prefix}.title will be cleaned to {cleaned_title!r}.")

        raw_path = raw_item.get("locationPath")
        cleaned_path: list[str] = []
        if not isinstance(raw_path, list):
            errors.append(f"ERROR: {prefix}.locationPath must be an array of strings.")
        else:
            if not raw_path:
                errors.append(f"ERROR: {prefix}.locationPath cannot be empty.")
            if len(raw_path) > MAX_NESTING_DEPTH:
                errors.append(f"ERROR: {prefix}.locationPath has more than {MAX_NESTING_DEPTH} segments.")
            for path_index, segment in enumerate(raw_path):
                if not isinstance(segment, str):
                    errors.append(f"ERROR: {prefix}.locationPath[{path_index}] must be a string.")
                    continue
                cleaned_segment = clean_display(segment)
                cleaned_path.append(cleaned_segment)
                if not cleaned_segment:
                    errors.append(f"ERROR: {prefix}.locationPath[{path_index}] cannot be empty.")
                if len(cleaned_segment) > MAX_LOCATION_SEGMENT_LENGTH:
                    errors.append(
                        f"ERROR: {prefix}.locationPath[{path_index}] must be "
                        f"{MAX_LOCATION_SEGMENT_LENGTH} characters or fewer."
                    )
                if cleaned_segment != segment:
                    warnings.append(
                        f"WARN: {prefix}.locationPath[{path_index}] will be cleaned to {cleaned_segment!r}."
                    )

        if "description" in raw_item and raw_item["description"] is not None:
            description = raw_item["description"]
            if not isinstance(description, str):
                errors.append(f"ERROR: {prefix}.description must be a string when present.")
            else:
                cleaned_description = clean_display(description)
                if len(cleaned_description) > MAX_DESCRIPTION_LENGTH:
                    errors.append(
                        f"ERROR: {prefix}.description must be {MAX_DESCRIPTION_LENGTH} characters or fewer."
                    )
                if cleaned_description != description:
                    warnings.append(f"WARN: {prefix}.description has extra whitespace.")

        if "tags" in raw_item and raw_item["tags"] is not None:
            tags = raw_item["tags"]
            if not isinstance(tags, list):
                errors.append(f"ERROR: {prefix}.tags must be an array when present.")
            else:
                if len(tags) > MAX_TAGS:
                    errors.append(f"ERROR: {prefix}.tags has more than {MAX_TAGS} tags.")
                formatted_tags: list[str] = []
                for tag_index, tag in enumerate(tags):
                    if not isinstance(tag, str):
                        errors.append(f"ERROR: {prefix}.tags[{tag_index}] must be a string.")
                        continue
                    formatted = format_tag(tag)
                    if not formatted:
                        errors.append(f"ERROR: {prefix}.tags[{tag_index}] normalizes to an empty tag.")
                    elif len(formatted) > MAX_TAG_LENGTH:
                        errors.append(f"ERROR: {prefix}.tags[{tag_index}] is too long after normalization.")
                    formatted_tags.append(formatted)
                    if formatted != tag:
                        warnings.append(f"WARN: {prefix}.tags[{tag_index}] should be {formatted!r}.")
                if len(set(formatted_tags)) != len(formatted_tags):
                    warnings.append(f"WARN: {prefix}.tags contains duplicates after normalization.")

        if "emoji" in raw_item and raw_item["emoji"] is not None:
            emoji = raw_item["emoji"]
            if not isinstance(emoji, str):
                errors.append(f"ERROR: {prefix}.emoji must be a string when present.")
            elif not clean_display(emoji):
                warnings.append(f"WARN: {prefix}.emoji is empty and will behave like omitted.")

        if cleaned_title and cleaned_path:
            target = target_key(cleaned_title, cleaned_path)
            if target in seen_targets:
                errors.append(
                    f"ERROR: {prefix} duplicates normalized title plus locationPath from "
                    f"items[{seen_targets[target]}]."
                )
            else:
                seen_targets[target] = index
            items_for_context.append(
                {
                    "index": index,
                    "title": cleaned_title,
                    "locationPath": cleaned_path,
                    "targetKey": target,
                }
            )

    return errors, warnings, items_for_context


def validate_against_export(
    export_document: Any,
    import_items: list[dict[str, Any]],
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    export = as_object(export_document, "export root", errors)

    if export.get("schemaVersion") != EXPORT_SCHEMA_VERSION:
        errors.append(f"ERROR: export schemaVersion should be {EXPORT_SCHEMA_VERSION!r}.")

    locations = export.get("locations", [])
    items = export.get("items", [])
    if not isinstance(locations, list):
        errors.append("ERROR: export.locations must be an array.")
        locations = []
    if not isinstance(items, list):
        errors.append("ERROR: export.items must be an array.")
        items = []

    location_keys: set[tuple[str, ...]] = set()
    final_segment_index: dict[str, set[tuple[str, ...]]] = {}
    for raw_location in locations:
        if not isinstance(raw_location, dict):
            continue
        raw_path = raw_location.get("path")
        if not isinstance(raw_path, list) or not all(isinstance(segment, str) for segment in raw_path):
            continue
        cleaned_path = [clean_display(segment) for segment in raw_path]
        key = path_key(cleaned_path)
        location_keys.add(key)
        if cleaned_path:
            final_segment_index.setdefault(normalize_key(cleaned_path[-1]), set()).add(key)

    existing_targets: dict[tuple[str, tuple[str, ...]], list[str]] = {}
    title_index: dict[str, set[tuple[str, ...]]] = {}
    for raw_item in items:
        if not isinstance(raw_item, dict):
            continue
        title = raw_item.get("title")
        raw_path = raw_item.get("locationPath")
        item_id = str(raw_item.get("id", "unknown-id"))
        if not isinstance(title, str) or not isinstance(raw_path, list):
            continue
        if not all(isinstance(segment, str) for segment in raw_path):
            continue
        cleaned_path = [clean_display(segment) for segment in raw_path]
        key = target_key(title, cleaned_path)
        existing_targets.setdefault(key, []).append(item_id)
        title_index.setdefault(normalize_key(title), set()).add(path_key(cleaned_path))

    create_count = 0
    update_count = 0
    unchanged_or_update_count = 0

    for item in import_items:
        index = item["index"]
        title = item["title"]
        path = item["locationPath"]
        current_path_key = path_key(path)
        current_target = item["targetKey"]

        if current_path_key not in location_keys:
            final_segment_matches = final_segment_index.get(normalize_key(path[-1]), set()) if path else set()
            if len(final_segment_matches) > 1:
                warnings.append(
                    f"WARN: items[{index}] uses a path not in export, and the final segment "
                    f"{path[-1]!r} exists in multiple exported paths. Confirm the full path."
                )
            else:
                warnings.append(f"WARN: items[{index}] locationPath is new and will create missing locations.")

        matches = existing_targets.get(current_target, [])
        if len(matches) > 1:
            errors.append(
                f"ERROR: items[{index}] matches multiple exported items with the same title and locationPath."
            )
        elif len(matches) == 1:
            update_count += 1
            unchanged_or_update_count += 1
        else:
            create_count += 1
            exported_paths_for_title = title_index.get(normalize_key(title), set())
            if exported_paths_for_title and current_path_key not in exported_paths_for_title:
                warnings.append(
                    f"WARN: items[{index}] title exists in export at a different path; Cubby will create a new item."
                )

    warnings.append(
        f"WARN: context summary: {create_count} new item(s), {update_count} exact existing target(s)."
    )
    if unchanged_or_update_count and create_count:
        warnings.append("WARN: mixed create/update import; verify this matches the transcript.")

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Cubby cubby-import-v1 JSON.")
    parser.add_argument("import_json", help="Path to Cubby import JSON, or '-' for stdin.")
    parser.add_argument("--export", help="Optional Cubby home-context export JSON for matching checks.")
    args = parser.parse_args()

    try:
        document = read_json(args.import_json)
        errors, warnings, items_for_context = validate_import(document)
        if args.export:
            export_document = read_json(args.export)
            export_errors, export_warnings = validate_against_export(export_document, items_for_context)
            errors.extend(export_errors)
            warnings.extend(export_warnings)
    except json.JSONDecodeError as error:
        print(f"ERROR: malformed JSON: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    for warning in warnings:
        print(warning)
    for error in errors:
        print(error)

    if errors:
        return 1

    print("OK: Cubby import JSON passes validation.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
