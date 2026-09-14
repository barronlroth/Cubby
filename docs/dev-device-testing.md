# Cubby Dev on iPhone

Use the shared **Cubby Dev** scheme to install a separate development app beside the App Store version. Run uses `DebugDev`, the existing Cubby app target, bundle ID `com.barronroth.Cubby.dev`, and display name **Cubby Dev**. Ordinary Debug and Release configurations retain their existing behavior.

## Install and use

1. Pair the iPhone with this Mac, trust the computer, and enable Developer Mode when iOS requests it. Use Xcode's Devices and Simulators window to confirm the device is connected. Wireless installation requires the device to be paired and reachable.
2. Select **Cubby Dev**, the iPhone destination, and development signing for team `CVE9ZKS33D`. Build and run with no launch arguments. Verify the installed bundle ID is `com.barronroth.Cubby.dev`; never replace the production app to test this profile.
3. Complete onboarding and add a few identifiable test belongings. Inventory and photos persist when you close and reopen Cubby Dev or install an updated build over it. Deleting the app removes its local data.
4. On an iOS 27 phone with the relevant Siri capabilities available, try “Find my surfboard in Cubby Dev,” search and open an item, and try follow-up requests referring to a displayed item. Also test after closing the app and restarting the phone, then unlocking it.

## Isolation and limits

`CUBBY_DEV` is defined only on the app target's `DebugDev` configuration. The binary refuses to open storage under another bundle ID. Its entitlements contain no iCloud or push access. Both the legacy SwiftData source and primary Core Data stores are persistent and local; sharing, CloudKit schema initialization, startup cloud recovery, and automatic seeding are disabled. A failed legacy store open stops startup instead of silently replacing it with an in-memory store.

The build grants development Pro access without contacting RevenueCat, including when Siri starts the process without launch arguments. Explicit `FORCE_FREE_TIER` and `FORCE_PRO_TIER` arguments can temporarily exercise access handling; they do not persist across independent launches. Production entitlement checks are unchanged.

Real App Intents, the protected Spotlight index, and on-screen annotations remain enabled. Do not use `UI-TESTING`, `-ui_testing`, or snapshot/seed flags for manual device testing. Cubby Dev rejects manual UI-test mode before resetting preferences. Its scheme runs automated tests using the ordinary isolated **Debug** configuration.

This profile can validate Siri, Spotlight, navigation, local persistence, and photos. It cannot validate purchases, restore, shared-household access, or CloudKit sync. It starts with an empty inventory; it does not import the production app's data. The scheme is intended for direct development installation, not TestFlight or App Store submission. A separate TestFlight app would need its own distribution configuration and App Store Connect record.

## Validation

September 14, 2026: the unsigned iOS device build passed with Xcode 27. The built app's identifier and display name match Cubby Dev; its Info.plist enables neither CloudKit sharing nor remote notifications. All 20 selected isolation, CloudKit configuration, and entitlement tests passed. Device signing and installation require the paired phone's identifier; no physical device installation has been performed yet.
