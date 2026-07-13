#!/usr/bin/env python3
"""Preflight Cubby App Store versioning before Xcode Cloud/TestFlight."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


CLOSED_VERSION_STATES = {
    "READY_FOR_DISTRIBUTION",
    "READY_FOR_SALE",
    "DEVELOPER_REMOVED_FROM_SALE",
    "REMOVED_FROM_SALE",
}


def run_json(command: list[str]) -> dict[str, Any]:
    env = os.environ.copy()
    env.setdefault("ASC_BYPASS_KEYCHAIN", "1")
    proc = subprocess.run(
        command,
        check=False,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"{' '.join(command)} failed with exit {proc.returncode}:\n{proc.stderr.strip()}"
        )
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"{' '.join(command)} did not return JSON: {exc}") from exc


def parse_project(project_file: Path) -> tuple[str, str, list[str]]:
    if not project_file.exists():
        raise RuntimeError(f"Project file not found: {project_file}")

    values: dict[str, set[str]] = {
        "MARKETING_VERSION": set(),
        "CURRENT_PROJECT_VERSION": set(),
    }
    pattern = re.compile(r"\b(MARKETING_VERSION|CURRENT_PROJECT_VERSION)\s*=\s*([^;]+);")

    for line in project_file.read_text(encoding="utf-8").splitlines():
        match = pattern.search(line)
        if match:
            key, value = match.groups()
            values[key].add(value.strip().strip('"'))

    notes: list[str] = []
    for key, found in values.items():
        if not found:
            raise RuntimeError(f"{key} was not found in {project_file}")
        if len(found) > 1:
            notes.append(f"BLOCKED: {key} has multiple values: {', '.join(sorted(found))}")

    marketing = next(iter(values["MARKETING_VERSION"]))
    build = next(iter(values["CURRENT_PROJECT_VERSION"]))
    return marketing, build, notes


def version_sort_key(version: str) -> tuple[int, ...]:
    parts = []
    for part in version.split("."):
        try:
            parts.append(int(part))
        except ValueError:
            parts.append(0)
    return tuple(parts)


def next_patch_version(version: str) -> str:
    parts = version.split(".")
    if not parts:
        return version
    try:
        parts[-1] = str(int(parts[-1]) + 1)
    except ValueError:
        return f"{version}.1"
    return ".".join(parts)


def app_store_versions(app_id: str) -> list[dict[str, Any]]:
    payload = run_json(
        [
            "asc",
            "versions",
            "list",
            "--app",
            app_id,
            "--platform",
            "IOS",
            "--limit",
            "200",
            "--paginate",
            "--output",
            "json",
        ]
    )
    data = payload.get("data", [])
    return data if isinstance(data, list) else []


def builds(app_id: str) -> tuple[list[dict[str, Any]], dict[str, str]]:
    payload = run_json(
        [
            "asc",
            "builds",
            "list",
            "--app",
            app_id,
            "--sort",
            "-uploadedDate",
            "--limit",
            "200",
            "--paginate",
            "--output",
            "json",
        ]
    )
    data = payload.get("data", [])
    included = payload.get("included", [])
    prerelease_versions: dict[str, str] = {}
    for item in included if isinstance(included, list) else []:
        if item.get("type") == "preReleaseVersions":
            attrs = item.get("attributes", {})
            version = attrs.get("version")
            if version:
                prerelease_versions[item["id"]] = version
    return (data if isinstance(data, list) else []), prerelease_versions


def build_numbers_for_version(
    build_items: list[dict[str, Any]],
    prerelease_versions: dict[str, str],
    marketing_version: str,
) -> list[int]:
    numbers: list[int] = []
    for item in build_items:
        attrs = item.get("attributes", {})
        relationships = item.get("relationships", {})
        prerelease = relationships.get("preReleaseVersion", {}).get("data", {})
        prerelease_id = prerelease.get("id")
        if prerelease_versions.get(prerelease_id) != marketing_version:
            continue
        raw_version = attrs.get("version")
        try:
            numbers.append(int(str(raw_version)))
        except (TypeError, ValueError):
            continue
    return sorted(numbers)


def int_or_none(value: str) -> int | None:
    try:
        return int(value)
    except ValueError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check Cubby project versioning against App Store Connect before Xcode Cloud/TestFlight."
    )
    parser.add_argument("--app", default="6751732388", help="App Store Connect app ID.")
    parser.add_argument(
        "--project",
        default="Cubby.xcodeproj/project.pbxproj",
        help="Path to Cubby's project.pbxproj.",
    )
    parser.add_argument(
        "--direct-upload",
        action="store_true",
        help="Fail if CURRENT_PROJECT_VERSION is not greater than existing builds for this marketing version.",
    )
    parser.add_argument(
        "--skip-asc",
        action="store_true",
        help="Only validate local project version consistency.",
    )
    args = parser.parse_args()

    project_file = Path(args.project)
    marketing_version, build_version, messages = parse_project(project_file)
    print(f"Project MARKETING_VERSION: {marketing_version}")
    print(f"Project CURRENT_PROJECT_VERSION: {build_version}")

    if not args.skip_asc:
        versions = app_store_versions(args.app)
        matching_versions = [
            item
            for item in versions
            if item.get("attributes", {}).get("versionString") == marketing_version
        ]
        latest_app_store_version = max(
            (
                item.get("attributes", {}).get("versionString", "0")
                for item in versions
                if item.get("attributes", {}).get("versionString")
            ),
            key=version_sort_key,
            default=None,
        )

        if latest_app_store_version:
            print(f"Latest App Store version record: {latest_app_store_version}")

        for item in matching_versions:
            attrs = item.get("attributes", {})
            states = {
                str(attrs.get("appVersionState", "")),
                str(attrs.get("appStoreState", "")),
            }
            states.discard("")
            print(f"ASC version train {marketing_version}: {', '.join(sorted(states))}")
            if states & CLOSED_VERSION_STATES:
                suggested = next_patch_version(marketing_version)
                messages.append(
                    "BLOCKED: MARKETING_VERSION points at a closed App Store version train. "
                    f"Bump MARKETING_VERSION to {suggested} or the next intended release train."
                )

        build_items, prerelease_versions = builds(args.app)
        current_builds = build_numbers_for_version(
            build_items, prerelease_versions, marketing_version
        )
        if current_builds:
            max_build = max(current_builds)
            print(f"Highest uploaded build for {marketing_version}: {max_build}")
            project_build = int_or_none(build_version)
            if project_build is None:
                messages.append(
                    "BLOCKED: CURRENT_PROJECT_VERSION is not numeric; App Store uploads need a numeric build."
                )
            elif args.direct_upload and project_build <= max_build:
                messages.append(
                    "BLOCKED: direct TestFlight upload would reuse or go below an uploaded build number. "
                    f"Set CURRENT_PROJECT_VERSION to at least {max_build + 1}."
                )
            elif not args.direct_upload and project_build <= max_build:
                messages.append(
                    "WARN: CURRENT_PROJECT_VERSION is not greater than the current train's highest uploaded build. "
                    "This is acceptable only if Xcode Cloud is assigning its own build number and no direct upload will run."
                )
        else:
            print(f"No uploaded builds found for {marketing_version}.")

    blocked = [message for message in messages if message.startswith("BLOCKED:")]
    warnings = [message for message in messages if message.startswith("WARN:")]
    for message in messages:
        print(message)

    if blocked:
        return 1
    if warnings:
        return 0

    print("OK: Cubby Xcode Cloud/TestFlight version preflight passed.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        print(f"BLOCKED: {error}", file=sys.stderr)
        sys.exit(1)
