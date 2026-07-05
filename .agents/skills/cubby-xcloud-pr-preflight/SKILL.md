---
name: cubby-xcloud-pr-preflight
description: Use before opening, updating, pushing, or uploading any Cubby PR or branch that can trigger Xcode Cloud, TestFlight, or App Store Connect distribution. Checks Cubby's MARKETING_VERSION and CURRENT_PROJECT_VERSION against App Store Connect version-train state and uploaded build numbers, with special handling for codex/ PR branches, direct TestFlight uploads, Xcode Cloud failures, Apple validation errors 90186/90062, and build-number/version-train bumps.
---

# Cubby Xcode Cloud PR Preflight

## Required Flow

Run this skill before pushing a branch that can trigger Cubby's Xcode Cloud workflow, before direct TestFlight upload, and before "fixing" Xcode Cloud by bumping a build number.

1. Use repo root `/Users/barron/Developer/Cubby` or the active Cubby worktree.
2. Run the checker:

```bash
python3 .agents/skills/cubby-xcloud-pr-preflight/scripts/preflight.py
```

For direct local TestFlight upload, use:

```bash
python3 .agents/skills/cubby-xcloud-pr-preflight/scripts/preflight.py --direct-upload
```

3. Treat any `BLOCKED` line as a stop sign. Fix the project version/build settings first, then run the checker again.
4. After pushing, monitor the PR check:

```bash
gh pr checks --watch=false
```

If Xcode Cloud fails, inspect the check details before making another version bump.

## Rules

- Always set `ASC_BYPASS_KEYCHAIN=1` for `asc` commands in this repo.
- App Store Connect app ID is `6751732388`.
- Read version values from `Cubby.xcodeproj/project.pbxproj`; all `MARKETING_VERSION` values must match, and all `CURRENT_PROJECT_VERSION` values must match.
- Check the App Store version train first. If the project `MARKETING_VERSION` already has an App Store version in `READY_FOR_DISTRIBUTION` or `READY_FOR_SALE`, that train is closed for new TestFlight uploads. Bump `MARKETING_VERSION` to the next patch version before pushing or uploading.
- Then check build numbers. For direct TestFlight uploads, `CURRENT_PROJECT_VERSION` must be greater than every uploaded build number for the same `MARKETING_VERSION`.
- Xcode Cloud may assign its own build number. Do not assume the Xcode Cloud build number will equal `CURRENT_PROJECT_VERSION`; still keep the project value sane for local/direct uploads.
- Do not push a no-op build bump until ASC confirms whether the failure is a closed version train, an actual build-number collision, or something else.
- Keep PR branches that should trigger the Codex Xcode Cloud/TestFlight workflow under the `codex/` prefix.

## Failure Signals

- Apple validation errors `90186` or `90062` usually mean the archive was uploaded to a closed or invalid version train. Check `MARKETING_VERSION` before bumping only `CURRENT_PROJECT_VERSION`.
- Xcode Cloud "Preparing build for App Store Connect failed" can be the same closed-train problem. Verify ASC version state and build history before changing project settings.
- If `asc` asks for keychain access, the environment is wrong. Use `ASC_BYPASS_KEYCHAIN=1` and the exported config/key files already set up on this machine.
