# Cubby Dev on iPhone

Use the shared **Cubby Dev** scheme to install a separate development app beside the App Store version. Run uses `DebugDev`, the existing Cubby app target, bundle ID `com.barronroth.Cubby.dev`, and display name **Cubby Dev**. Ordinary Debug and Release configurations retain their existing behavior.

## Install and use

1. Pair the iPhone with this Mac, trust the computer, and enable Developer Mode when iOS requests it. In Xcode 27, use Device Hub → Add → Pair Nearby Device. iOS 27 supports first-time wireless pairing: leave Settings → Privacy & Security → Developer Mode open on the phone, select the Mac, and enter the code shown by Device Hub. Confirm the device is paired and reachable.
2. Select **Cubby Dev**, the iPhone destination, and development signing for team `CVE9ZKS33D`. Build and run with no launch arguments. Verify the installed bundle ID is `com.barronroth.Cubby.dev`; never replace the production app to test this profile.
3. Complete onboarding and add a few identifiable test belongings. Inventory and photos persist when you close and reopen Cubby Dev or install an updated build over it. Deleting the app removes its local data.
4. On an iOS 27 phone with the relevant Siri capabilities available, try “Find my surfboard in Cubby Dev,” search and open an item, and try follow-up requests referring to a displayed item. Also test after closing the app and restarting the phone, then unlocking it.

## Isolation and limits

`CUBBY_DEV` is defined only on the app target's `DebugDev` configuration. The binary refuses to open storage under another bundle ID. Its entitlements contain no iCloud or push access. Both the legacy SwiftData source and primary Core Data stores are persistent and local; sharing, CloudKit schema initialization, startup cloud recovery, and automatic seeding are disabled. A failed legacy store open stops startup instead of silently replacing it with an in-memory store.

The build grants development Pro access without contacting RevenueCat, including when Siri starts the process without launch arguments. Explicit `FORCE_FREE_TIER` and `FORCE_PRO_TIER` arguments can temporarily exercise access handling; they do not persist across independent launches. Production entitlement checks are unchanged.

Real App Intents, the protected Spotlight index, and on-screen annotations remain enabled. Do not use `UI-TESTING`, `-ui_testing`, or snapshot/seed flags for manual device testing. Cubby Dev rejects manual UI-test mode before resetting preferences. Its scheme runs automated tests using the ordinary isolated **Debug** configuration.

This profile can validate Siri, Spotlight, navigation, local persistence, and photos. It cannot validate purchases, restore, shared-household access, or CloudKit sync. It starts with an empty inventory; it does not import the production app's data. The scheme is intended for direct development installation, not TestFlight or App Store submission. A separate TestFlight app would need its own distribution configuration and App Store Connect record.

## Validation

September 14, 2026: the unsigned iOS device build passed with Xcode 27. The built app's identifier and display name match Cubby Dev; its Info.plist enables neither CloudKit sharing nor remote notifications. All 20 selected isolation, CloudKit configuration, and entitlement tests passed. On September 18, the development-signed app was installed and launched wirelessly on an iPhone 15 Pro running iOS 27.0 (24A435). The signed artifact was checked for the dev bundle identity, registered device, and absence of iCloud/push entitlements. Production Cubby remained installed at 1.0.12 (118), alongside Cubby Dev 1.1.0 (120). Onboarding displayed successfully; spoken Siri validation remains a hands-on check.

## Manual signing from the CLI

Automatic signing remains the default. To use an already installed development profile, pass `CUBBY_DEV_SIGNING_STYLE=Manual`, `CUBBY_DEV_PROVISIONING_PROFILE=<profile name>`, and `DEVELOPMENT_TEAM=CVE9ZKS33D` as build arguments. These custom variables scope the profile to the app target; do not pass a global `PROVISIONING_PROFILE_SPECIFIER`, which also affects Swift package dependencies. Before installation, verify the signed application identifier is `CVE9ZKS33D.com.barronroth.Cubby.dev` and the profile includes the paired device.
