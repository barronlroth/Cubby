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
- the latest unlocked-device rerun no longer reproduced `Invalid bundle ID for container`
- a Debug signing/configuration bug was forcing `CubbyV2` schema-init runs to use the `Production` CloudKit environment
- that bug is now fixed by using Development entitlements for Debug builds
- `CubbyV2` development schema initialization now succeeds
- a first development share was created successfully enough to reach the share sheet
- `CubbyV2` schema changes were deployed to production from CloudKit Console
- build `54` was uploaded with `asc` and is now in internal TestFlight testing only
- the remaining Phase 2 work is now the two-Apple-ID validation matrix on build `54`

That means the app/container association issue likely cleared, and the production-schema failure turned out to be caused by the app being signed for the wrong CloudKit environment during Debug schema-init runs.

## Current State By Artifact

### Current branch workspace

- The runtime UI and CRUD path are Core Data-backed.
- SwiftData remains only as a legacy migration source or debug seed source.
- Migration now opens the on-disk legacy SwiftData store directly and defers retry if that source is unavailable.
- Shared-home location creation now routes to the owning home/location store instead of always targeting the private store.
- Cross-store item moves are now rejected instead of silently reparenting items across private/shared stores.
- Fastlane now has an explicit internal-only beta upload path for the first `CubbyV2` validation build.
- Debug/device builds now use a Development CloudKit entitlements file so `INIT_CLOUDKIT_SCHEMA` targets the development environment instead of production.

### Latest TestFlight build

- Build `54` is now the latest uploaded TestFlight build.
- Build `54` was uploaded on March 24, 2026 at 8:01 PM PDT through `asc builds upload`.
- Build `54` is `VALID` in App Store Connect.
- Build `54` is internal-only in practice:
  - `internalBuildState = IN_BETA_TESTING`
  - `externalBuildState = READY_FOR_BETA_SUBMISSION`
  - the internal beta group has `hasAccessToAllBuilds = true`
- Build `54` includes the `CubbyV2` cutover, the March 23 migration/store-routing fixes, the cross-store move guard, the Debug Development-entitlements fix for CloudKit schema init, and the public-link first-invite workaround.

### Apple-side blocker state

- `Invalid bundle ID for container` did not reproduce on the latest unlocked-device rerun.
- `Cannot create new type CD_CDHome in production schema` was reproduced once, then traced to the app being signed with `com.apple.developer.icloud-container-environment = Production` during a Debug schema-init run.
- On March 23, 2026, a Development-signed app build and install to Barron's iPhone succeeded.
- On March 23, 2026 at 10:09 PM PDT, an unlocked-device `INIT_CLOUDKIT_SCHEMA` launch reached app startup and schema bootstrap.
- On March 23, 2026 at 10:19 PM PDT, a rebuilt Debug app with Development entitlements successfully initialized `CubbyV2` development schema.
- On March 23, 2026 shortly after 10:19 PM PDT, the first share flow reached the system share sheet on-device.
- On March 23, 2026 shortly after that share flow, `CubbyV2` schema changes were promoted to Production through CloudKit Console.
- On March 23, 2026 at 10:30 PM PDT, build `53` was uploaded through `asc` and reached `VALID` processing state.
- On March 24, 2026 at 8:01 PM PDT, build `54` was uploaded through `asc` and reached `VALID` processing state.
- Result: the current blocker is no longer container association, schema-init, schema deployment, or internal beta upload; it is now the two-user validation sequence on build `54`.

## What Is Already Done

### Product / app behavior

- Shared homes runtime was moved onto Core Data instead of the prior hybrid SwiftData/Core Data split.
- Owner-paid shared-homes rules were implemented:
  - only Pro owners can manage sharing
  - collaborators can participate for free
  - collaborator-visible shared homes/items do not count against collaborator free-tier limits
- First-share flow now uses `UICloudSharingController` and exposes `Anyone with the link` because named-recipient invites were failing at Apple's `Couldn't Add People` step.
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

Most recent focused rerun in the current workspace on March 24, 2026: `51 passed, 0 failed`.

### CloudKit validation

- CloudKit Console now shows the Core Data record types in `iCloud.com.barronroth.CubbyV2` Development.
- Development currently contains at least:
  - `CD_CDHome`
  - `CD_CDInventoryItem`
  - `CD_CDStorageLocation`
  - `CD_Home`
  - `CD_InventoryItem`
  - `CD_StorageLocation`
- The first share flow successfully reached the share sheet on-device, which confirms the app can precreate a development share on `CubbyV2`.
- Those schema changes were then deployed to Production from CloudKit Console.
- Production now shows the same Core Data record types and `Deploy Schema Changes…` is disabled.

## TestFlight / build history for this incident

- `49`: switched first share to the standard share sheet
- `50`: share sheet + Cubby thumbnail / management split improvements
- `51`: waited for CloudKit export before sharing
- `52`: precreated CloudKit shares before presenting invite sheet
- `53`: `CubbyV2` cutover + migration hardening + shared-store routing fixes + cross-store move rejection + Debug Development entitlements fix, uploaded internal-only via `asc`
- `54`: restored first invites to `UICloudSharingController`, enabled `Anyone with the link`, and returned the persisted `CKShare` after export before presenting the share UI

Build `54` is now the active validation build for the fresh `CubbyV2` container.

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

### Current state on the fresh container

Current `CubbyV2` state:

- Development schema initialization succeeds from a Debug device build signed with `com.apple.developer.icloud-container-environment = Development`.
- CloudKit Console reflects the generated Core Data record types in Development.
- The first share flow reaches the system share sheet from the device build.
- Production now contains the deployed Core Data schema for the fresh container.
- `Deploy Schema Changes…` is disabled in Production after deployment.

### Latest device recheck

The latest successful recheck reached CloudKit startup and completed schema init:

- Device build succeeded
- Device install succeeded
- `xcrun devicectl device process launch --console --device 00008130-00046D843869E93A com.barronroth.Cubby INIT_CLOUDKIT_SCHEMA`
- app launched successfully on the unlocked device
- app logged `CloudKit development schema initialized`
- CloudKit Console reflected the new Development record types immediately afterward

The same device path previously failed because the Debug app was signed for the Production CloudKit environment. After splitting entitlements by configuration, the schema-init path now behaves correctly.

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
- `Cannot create new type ... in production schema` points to undeployed or inconsistent production schema state for the current container.
- If a Debug schema-init build is signed for `Production`, `initializeCloudKitSchema()` cannot seed the development schema and will fail with production-schema creation errors.

## Current Branch And Upload State

Branch tip now includes:

- the `CubbyV2` cutover
- retry-safe legacy migration
- shared-home location store routing fixes
- cross-store item move rejection
- an internal-only Fastlane beta lane: `fastlane beta_internal`
- Debug-only Development CloudKit entitlements for schema-init/device validation

Shipped in internal TestFlight build `53`:

- the `CubbyV2` container cutover
- retry-safe legacy migration
- shared-home location store routing fixes
- cross-store item move rejection
- Debug-only Development CloudKit entitlements for schema-init/device validation

Shipped in internal TestFlight build `54`:

- everything from build `53`
- first-invite sharing via `UICloudSharingController`
- `Anyone with the link` sharing enabled
- persisted-share refetch after export before presenting the invite UI

Still not completed:

- the two-Apple-ID validation matrix on build `54`

## Immediate Next Steps

1. Run the two-Apple-ID validation matrix on build `54`.
2. Use the public-link invite path for this pass, because Apple's named-recipient `Couldn't Add People` path is still not working.
3. Capture exact logs, timestamps, build number, and container/environment details for any invite, accept, write, revoke, or relaunch failure.
4. If invite acceptance, collaborator writes, revoke flow, and relaunch convergence all pass on build `54`, decide whether to keep rollout internal for one more cycle or start preparing the external group.

## What Not To Spend Time On Right Now

- More share-sheet UI changes
- More app-layer sharing logic changes
- More schema work on the old `Cubby` container
- Another TestFlight upload before build `54` has been exercised through the full two-user matrix
- Another external TestFlight rollout before the internal `CubbyV2` validation build passes the two-user matrix

The current bottleneck is end-to-end two-user validation on build `54`, not CloudKit container acceptance.
