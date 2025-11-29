# Fastlane / Snapshot Worklog (Codex session)

## Goal
- Capture App Store / TestFlight screenshots via `fastlane snapshot` using seeded mock data.
- Submit build 14 to the App Store with auto-release (pending screenshots).

## Actions Taken
1) **Fastlane/TestFlight builds**
   - Ran `fastlane beta` twice, resulting in TestFlight builds:
     - Build 13 (earlier run).
     - Build 14 with changelog “Conditional wrapper if the iPhone has Apple Intelligence or not.” (Uploaded and processing; external distribution on.)

2) **Mock data seeding for UI/Testing**
   - Updated `CubbyApp.swift` to detect `UI-TESTING` / `-ui_testing` and `SEED_MOCK_DATA`.
   - In UI/testing modes, the app:
     - Uses in-memory SwiftData.
     - Clears UserDefaults for a clean state.
     - Runs `MockDataGenerator.clearAllData` and `generateMockData`.
     - Marks onboarding complete (skips onboarding UI).
   - Result: Any UI test run automatically launches with a fully populated dataset (homes, nested locations, items).

3) **Snapshot test**
   - Added `CubbyUITests/CubbySnapshotTests.swift`:
     - Launches app with `UI-TESTING` + `SEED_MOCK_DATA`.
     - Captures screenshots:
       - `01-Home`
       - `02-ItemDetail`
       - `03-AddItem`
   - Snapshot helper added to `CubbyUITests/SnapshotHelper.swift` and synced copy in `fastlane/SnapshotHelper.swift`.

4) **Snapfile configuration**
   - `fastlane/Snapfile` now targets the simulators you have installed:
     - Devices: `iPhone 17 Pro Max`, `iPhone 17`
     - Language: `en-US`
     - Outputs: `fastlane/screenshots`
     - Clears previous screenshots, stops after first error, test target `CubbyUITests`, `xcargs` includes `-only-testing:CubbyUITests`.
   - Seeding is automatic for snapshot runs.

5) **Test fixes**
   - `CubbyTests/StorageLocationTests.swift`: removed `#Predicate` macro usage to fix compile error when running tests under snapshot.

## Current Status / Blocker
- **Builds succeed; UI tests fail to launch the runner on simulators.**
- Error in xcresult: `Failed to launch com.barronroth.CubbyUITests: Application info provider (FBSApplicationLibrary) returned nil for "com.barronroth.CubbyUITests"`.
- This indicates the UI test runner bundle did not install/launch on the simulators (not a code compile issue).

## Requested Next Steps (for you)
1) Boot a single simulator from your installed 26.1 runtimes (e.g., **iPhone 17 Pro Max**) in Simulator.app.
2) Run snapshot serially on that single device to avoid concurrency flakiness:
   - Option A (via CLI flags, if accepted by your fastlane version):
     ```bash
     cd /Users/barron/Developer/Cubby
     FASTLANE_SKIP_UPDATE_CHECK=1 fastlane snapshot --destination "platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.1" --concurrent_simulators false
     ```
   - Option B (edit Snapfile temporarily):
     - Set `devices(["iPhone 17 Pro Max"])`
     - Add `concurrent_simulators(false)`
     - Then run:
       ```bash
       FASTLANE_SKIP_UPDATE_CHECK=1 fastlane snapshot
       ```
3) If it still fails, try erasing that simulator in Simulator.app and rerun.

## What happens when it works
- Snapshot will launch the app with seeded data (onboarding skipped) and produce screenshots in:
  - `fastlane/screenshots/en-US/6.7"/`
  - `fastlane/screenshots/en-US/6.1"/`
- Then we can run `fastlane deliver` (or a release lane) to submit build 14 with the new screenshots and auto-release.

## Open Questions
1) Do you want me to proceed to set `concurrent_simulators(false)` and a single device in Snapfile, or keep the dual-device setup and keep retrying?
2) After screenshots are generated, should I wire a `deliver` lane for App Store submission of build 14 with auto-release and “Conditional wrapper…” as What’s New?
