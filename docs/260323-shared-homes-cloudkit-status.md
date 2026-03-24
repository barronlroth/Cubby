# Shared Homes CloudKit Status

## Summary

Shared Homes is no longer blocked on core app architecture.

The app runtime has already been cut over to the Core Data + `NSPersistentCloudKitContainer` stack used by CloudKit sharing. The remaining work is now split across:

- final persistence correctness hardening in the branch workspace
- CloudKit container setup and validation on Apple's side

At the moment:

- the old container `iCloud.com.barronroth.Cubby` was repaired enough to expose the next CloudKit schema issue
- that container then appeared to get stuck in a bad state around `cloudkit.share`
- a fresh container `iCloud.com.barronroth.CubbyV2` was created and the app was repointed to it
- the new blocker is now `Invalid bundle ID for container` for `iCloud.com.barronroth.CubbyV2`

That last error means the app/container association has not fully propagated or is not fully recognized by CloudKit yet. As of March 23, 2026, the latest device recheck is still incomplete because the Development-signed app could be built and installed, but the schema-init launch attempt never reached app startup while the device was locked.

## Current State By Artifact

### Current branch workspace

- The runtime UI and CRUD path are Core Data-backed.
- SwiftData remains only as a legacy migration source or debug seed source.
- Migration now opens the on-disk legacy SwiftData store directly and defers retry if that source is unavailable.
- Shared-home location creation now routes to the owning home/location store instead of always targeting the private store.
- Cross-store item moves are now rejected instead of silently reparenting items across private/shared stores.
- Fastlane now has an explicit internal-only beta upload path for the first `CubbyV2` validation build.

### Latest TestFlight build

- Build `52` is still the latest uploaded TestFlight build.
- Build `52` includes the share-flow hardening work.
- Build `52` does not include the `CubbyV2` cutover, the March 23 migration/store-routing fixes, the cross-store move guard, or the internal-only beta lane.

### Apple-side blocker state

- The latest confirmed CloudKit container failure on `iCloud.com.barronroth.CubbyV2` is still `Invalid bundle ID for container`.
- On March 23, 2026, a Development-signed app build and install to Barron's iPhone succeeded.
- On March 23, 2026 at 9:50 PM PDT, the latest `INIT_CLOUDKIT_SCHEMA` launch attempt was blocked before app startup because the device was locked.
- Result: the app/container association still needs to be rechecked on an unlocked device before any new beta upload.

## What Is Already Done

### Product / app behavior

- Shared homes runtime was moved onto Core Data instead of the prior hybrid SwiftData/Core Data split.
- Owner-paid shared-homes rules were implemented:
  - only Pro owners can manage sharing
  - collaborators can participate for free
  - collaborator-visible shared homes/items do not count against collaborator free-tier limits
- First-share flow was changed to the normal share sheet instead of leading with `UICloudSharingController`.
- Existing shared homes still use the Apple manage-sharing UI.
- The redundant `Shared with N people` line under the shared chip was removed.

### Stability / correctness fixes

- Fixed duplicate persistent container initialization in-process.
- Fixed a recursion crash in `CoreDataAppRepository`.
- Fixed first-share flow to precreate CloudKit shares before presenting the invite sheet.
- Added waiting around CloudKit export where appropriate during share creation.

### Tests

Focused validation is passing in the current workspace:

- `DataMigrationTests`
- `CoreDataAppRepositoryTests`
- `HomeSharingServiceTests`
- `FeatureGateTests`
- `RemoteChangeHandlerTests`

Most recent focused rerun in the current workspace on March 23, 2026: `51 passed, 0 failed`.

## TestFlight / build history for this incident

- `49`: switched first share to the standard share sheet
- `50`: share sheet + Cubby thumbnail / management split improvements
- `51`: waited for CloudKit export before sharing
- `52`: precreated CloudKit shares before presenting invite sheet

Build `52` is the latest TestFlight build that contains the current share-flow fixes, but it predates the `CubbyV2` cutover and the March 23 persistence hardening.

## What Was Attempted On The Original Container

Original container:

- `iCloud.com.barronroth.Cubby`

Observed failures on that container:

1. Initial TestFlight error:
   - `Cannot create new type CD_CDHome in production schema`
2. After production schema deployment for the Core Data entities:
   - `Cannot create new type cloudkit.share in production schema`

### Work performed on the original container

- Generated development schema from the real Core Data sharing stack using a Development-signed device build.
- Verified that the Core Data entity record types existed in development.
- Deployed those additive schema changes to production through CloudKit Console.
- Verified production now contained:
  - `CD_CDHome`
  - `CD_CDStorageLocation`
  - `CD_CDInventoryItem`

### Why the original container was abandoned

After the entity schema was fixed, the remaining failure was:

- `Cannot create new type cloudkit.share in production schema`

CloudKit Console showed no pending schema changes for that share type. At that point the container no longer looked like a normal undeployed-schema problem. Because there are no real users yet, creating a fresh container became the faster and safer path than continuing to salvage the old one.

## What Was Changed For The Fresh Container

Fresh container:

- `iCloud.com.barronroth.CubbyV2`

Branch-tip container changes:

- `CloudKitSyncSettings.containerIdentifier` now points to `iCloud.com.barronroth.CubbyV2`
- `Cubby.entitlements` now lists only `iCloud.com.barronroth.CubbyV2`
- `CloudKitSchemaBootstrapper` now initializes the Core Data sharing schema first, then best-effort initializes the legacy SwiftData schema

Relevant files:

- `/Users/barron/Developer/Cubby/Cubby/Services/CloudKitSyncSettings.swift`
- `/Users/barron/Developer/Cubby/Cubby/Cubby.entitlements`
- `/Users/barron/Developer/Cubby/Cubby/Services/CloudKitSchemaBootstrapper.swift`

Xcode also touched the project settings while the new container was added:

- `CODE_SIGN_IDENTITY = "Apple Development"`
- `PROVISIONING_PROFILE_SPECIFIER = ""`

Relevant file:

- `/Users/barron/Developer/Cubby/Cubby.xcodeproj/project.pbxproj`

## What Was Verified On The Fresh Container

### App-side signing / entitlements

A Development-signed device build was created and installed to Barron's iPhone on March 23, 2026.

Verified on the built app:

- `aps-environment = development`
- `com.apple.developer.icloud-container-environment = Development`
- `com.apple.developer.icloud-container-identifiers = ["iCloud.com.barronroth.CubbyV2"]`

Verified in the embedded provisioning profile:

- `iCloud.com.barronroth.CubbyV2` is present
- the old container is still also present in the profile

That means the app binary itself is requesting the new container correctly.

### Current failure on the fresh container

Current CloudKit failure:

- `Permission Failure`
- server message:
  - `Invalid bundle ID for container`

This happens during Core Data mirroring setup for:

- `com.apple.coredata.cloudkit.zone:__defaultOwner__`
- `com.apple.coredata.cloudkit.shared.subscription`

Container:

- `iCloud.com.barronroth.CubbyV2`

This is no longer a schema mismatch. It is an Apple-side app/container association issue.

### Latest device recheck

The latest recheck did not reach CloudKit startup:

- Device build succeeded
- Device install succeeded
- `xcrun devicectl device process launch --console --device 00008130-00046D843869E93A com.barronroth.Cubby INIT_CLOUDKIT_SCHEMA`
- launch failed with `CoreDeviceError 10002` / `FBSOpenApplicationErrorDomain error 7`
- server-side reason: the device was locked, so the app never reached schema bootstrap

That means the branch is ready for the next validation attempt, but the first checkpoint in the Phase 2 plan is still pending on an unlocked device.

## Apple Docs Used To Interpret The Current State

These Apple docs were consulted through `sosumi` during debugging:

- [CKShare](https://developer.apple.com/documentation/cloudkit/ckshare/)
- [Deploying an iCloud Container’s Schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema/)
- [Inspecting and Editing an iCloud Container’s Schema](https://developer.apple.com/documentation/cloudkit/inspecting-and-editing-an-icloud-container-s-schema/)
- [Handling an iCloud Container’s Data](https://developer.apple.com/documentation/cloudkit/handling-an-icloud-container-s-data/)
- [Setting Up Core Data with CloudKit](https://developer.apple.com/documentation/coredata/setting-up-core-data-with-cloudkit/)
- [Sharing Core Data objects between iCloud users](https://developer.apple.com/documentation/coredata/sharing_core_data_objects_between_icloud_users)
- [Configuring iCloud services](https://developer.apple.com/documentation/xcode/configuring-icloud-services)
- [Enabling CloudKit in Your App](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app)
- [TN3164: Debugging the synchronization of NSPersistentCloudKitContainer](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)

Most important interpretation from TN3164:

- `Invalid bundle ID for container` points to the app ID / CloudKit container association, not an app-code bug.

## Current Branch And Upload State

Branch tip now includes:

- the `CubbyV2` cutover
- retry-safe legacy migration
- shared-home location store routing fixes
- cross-store item move rejection
- an internal-only Fastlane beta lane: `fastlane beta_internal`

Still not shipped:

- a TestFlight build containing those changes
- a successful `CubbyV2` schema-init run on an unlocked device
- a successful development share creation on `CubbyV2`

## Immediate Next Steps

1. Unlock Barron's iPhone and rerun the Development-signed launch with `INIT_CLOUDKIT_SCHEMA`.
2. If the app reaches startup and the `Invalid bundle ID for container` error is gone:
   - initialize development schema on `CubbyV2`
   - create one development share
   - deploy fresh schema to production from CloudKit Console
   - upload an internal-only build with `fastlane beta_internal`
   - run the two-Apple-ID validation matrix on that exact build
3. If `Invalid bundle ID for container` is still present after one more app ID/container reassociation check:
   - stop container iteration
   - escalate as an Apple-side app/container association blocker

## What Not To Spend Time On Right Now

- More share-sheet UI changes
- More app-layer sharing logic changes
- More schema work on the old `Cubby` container
- Another TestFlight upload before the `CubbyV2` container accepts the app ID
- Another external TestFlight rollout before the internal `CubbyV2` validation build passes the two-user matrix

The current bottleneck is CloudKit container acceptance, not the SwiftUI or Core Data sharing code path.
