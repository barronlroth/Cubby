# CubbyTests Guide

This folder contains unit tests for Cubby using Swift Testing.

## SwiftData test containers

- Always use in-memory containers with CloudKit disabled:
  `ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)`
- Avoid using production containers or CloudKit-backed stores in tests.

## CloudKit-related tests

- Only test deterministic logic (settings/availability).
- Use `CloudKitSyncSettings.resolve(..., isRunningTestsOverride: ...)` when you need
  to simulate non-test environments.

## Running tests

```
xcodebuild -project Cubby.xcodeproj -scheme Cubby test
```
