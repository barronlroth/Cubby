# RevenueCat Integration Plan (Annual + Lifetime, Limits-Based Paywall)

## Summary

Cubby will use RevenueCat to sell **Pro** access via:

- **Annual auto-renew subscription**: `$29.99/year`
  - Includes an Apple-managed **free trial** (**3 days free**, then auto-renews at $29.99/year unless canceled)
- **Lifetime license** (non-consumable): `$249`

**Free limits**

- Max **1 Home** total
- Max **10 Items** (effectively total, since Free has 1 home)

**Paywall trigger**

- Show paywall only when a user attempts to exceed a Free limit (“just in time”).

**Downgrade-safe behavior (Option B)**

- If a user is **not Pro** and is **over any limit** (e.g., previously subscribed and created multiple homes), Cubby stays fully usable for **view/search/edit**, but blocks **new home/item creation** until the user upgrades (or deletes down).

## V1 Decisions (Locked)

- **Paywall UI**: use **RevenueCatUI** for the paywall surface (keep custom SwiftUI paywall UI to a minimum).
- **No accounts in v1**: rely on RevenueCat anonymous IDs; users may need to tap **Restore Purchases** on a new device.
- **Gate scope**: enforce limits on **Home creation** + **Item creation** only; **Storage Location** creation remains allowed even when over-limit.
- **Post-purchase UX**: no “resume pending action” in v1; purchase succeeds → dismiss → user taps “Add” again.
- **Always-available access**: add a **“Cubby Pro”** entry point in the **HomePicker menu** for Restore/Manage.

---

## Product & RevenueCat Configuration

### App Store Connect (source of truth)

Create these products:

| Product ID | Type | Price |
|---|---|---|
| `cubby_pro_annual` | Auto-renewable subscription | $29.99/year |
| `cubby_pro_lifetime` | Non-consumable | $249 |

Notes:

- Create a subscription group (e.g., “Cubby Pro”) and add `cubby_pro_annual` to it.
- Configure an **Introductory Offer → Free Trial** for `cubby_pro_annual` (**3 days free**).
- Ensure the app target has the **In-App Purchase** capability enabled.

### RevenueCat

In RevenueCat Dashboard:

- **Entitlement**: `pro`
- Add products: `cubby_pro_annual`, `cubby_pro_lifetime`
- Attach both products to entitlement `pro`
- Create an **Offering** (e.g., `default`) and set as **Current**
  - Packages:
    - Annual → `cubby_pro_annual`
    - Lifetime → `cubby_pro_lifetime`

Notes:

- The **3-day free trial** is configured in **App Store Connect**; RevenueCat/StoreKit will surface it automatically on the annual package.
- Lifetime (non-consumable) does not have a trial.

---

## iOS App Integration (SwiftUI + SwiftData)

### SDK setup

- Add RevenueCat Purchases SDK via Swift Package Manager.
- Add RevenueCatUI via Swift Package Manager (v1 paywall UI).
- Configure Purchases early in app lifecycle (recommended: inside `ProAccessManager` init; instantiate it in `HomeSearchContainer` so it runs on first render after onboarding):
  - Load API key from `Info.plist` (see “Keys & build configs” below)
  - `Purchases.configure(withAPIKey: <public_sdk_key>)`
  - Set debug logging in DEBUG builds only (e.g., `Purchases.logLevel = .debug`).
- No accounts: rely on RevenueCat’s anonymous user ID + “Restore Purchases”.

### Keys & build configs (API key)

- Add a build setting `REVENUECAT_PUBLIC_API_KEY` (Debug/Release) via `.xcconfig`.
- In `Info.plist`, add `RevenueCatPublicApiKey` with value `$(REVENUECAT_PUBLIC_API_KEY)`.
- In code, read `RevenueCatPublicApiKey` from the bundle and fail fast in DEBUG if it’s missing/empty.

### Key architecture objects

#### `ProAccessManager` (RevenueCat state + purchase API)
Create `Cubby/Services/ProAccessManager.swift` (`@MainActor`, `ObservableObject`) to own:

- Cached `CustomerInfo` and derived `isPro`
  - `isPro = customerInfo.entitlements["pro"]?.isActive == true`
- Cached `Offerings` and exposed “available packages” for paywall UI
- APIs:
  - `refresh()` (fetch latest customer info)
  - `loadOfferings()` (fetch current offering/packages for paywalls)
  - `purchase(package:)`
  - `restorePurchases()`
- Listener/delegate to receive updates so UI flips to Pro immediately after purchase/restore

Injection:

- Create a single instance at the app root and provide via `.environmentObject(proAccessManager)`.

#### `FeatureGate` (centralized rules + SwiftData counts)
Create `Cubby/Services/FeatureGate.swift` as a stateless helper to centralize all gating:

- Limits:
  - `freeMaxHomes = 1`
  - `freeMaxItemsPerHome = 10`
- “Downgrade-safe” rule (Option B):
  - If `!isPro` and `homeCount > freeMaxHomes`, then **deny all creation** (homes + items).
- APIs return a structured reason (so paywall copy is specific):
  - `canCreateHome(modelContext:isPro:) -> GateResult`
  - `canCreateItem(homeId:modelContext:isPro:) -> GateResult`

Implementation detail:

- Use `ModelContext.fetchCount` with `FetchDescriptor` and `#Predicate` (pattern already used in `StorageLocationDeletionService`).

Non-goals (v1):

- Do not gate **Storage Location** creation (only homes + items).

Counts needed:

- Home count:
  - `FetchDescriptor<Home>()` and `fetchCount(...)`
- Item count in a home:
  - `FetchDescriptor<InventoryItem>(predicate: #Predicate { $0.storageLocation?.home?.id == homeId })`

#### Paywall presentation (RevenueCatUI; single global sheet)
For v1, keep this intentionally small and SwiftUI-native:

- Host `@State private var activePaywall: PaywallContext?` in `HomeSearchContainer` and present a single `.sheet(item:)`.
- Sheet content: a short Cubby header for the reason (home limit / item limit / over-limit), followed by a `RevenueCatUI` paywall for the current offering (Annual + Lifetime).
- No “pending action” auto-resume in v1: purchase succeeds → paywall dismisses → user taps “Add” again.

`PaywallContext` (suggested shape):

- `reason`: `.homeLimitReached` / `.itemLimitReached` / `.overLimit`
- Conforms to `Identifiable` so it can drive `.sheet(item:)`.

---

## Paywall UX (just-in-time + always-available restore)

### Just-in-time paywall sheet

Displayed only when user tries to exceed limits.

Core elements:

- Title/benefit copy based on reason (homes vs items vs over-limit)
- Two purchase options:
  - Annual subscription (primary; includes free trial messaging like “3 days free then $29.99/year”)
  - Lifetime (secondary)
- Buttons:
  - Purchase selected package
  - Restore Purchases
  - Manage Subscription (when relevant; opens Apple manage subscriptions)
  - Close
- Links:
  - Privacy Policy
  - Terms of Use

### Manage subscription (Annual only)

- Prefer StoreKit’s native flow:
  - `try await AppStore.showManageSubscriptions(in: windowScene)`
- Hide “Manage Subscription” for Lifetime-only users (no subscription to manage).
- Optional fallback: open Apple’s subscriptions page (`https://apps.apple.com/account/subscriptions`) if needed.

### Error handling (make it predictable)

- Offerings fail to load: show inline error + Retry + Restore Purchases.
- User cancels purchase: no alert; stop loading and keep paywall open.
- Purchase fails: show alert; keep paywall open.
- Restore succeeds but no entitlement: show a neutral “No purchases found” message.

### “Cubby Pro” / “Subscription” screen (recommended)

Even with just-in-time paywalls, add a reachable screen so users can restore/manage without hitting a limit:

- Shows current state (Free vs Pro)
- Restore Purchases
- Manage Subscription (when subscription product is active/known)
- Optionally show the same Annual/Lifetime options

---

## Cubby Integration Points (where to enforce limits)

### Root wiring

- `Cubby/Views/Home/HomeSearchContainer.swift`
  - Create the single `@StateObject` `ProAccessManager` (configures RevenueCat once)
  - Host `@State private var activePaywall: PaywallContext?` and present the global `.sheet(item:)`
  - Inject `proAccessManager` into the environment for entitlement checks / purchase/restore

### Add Home gating

- `Cubby/Views/Home/HomeView.swift` (HomePicker “Add New Home”)
  - Before toggling `showingAddHome = true`, call `FeatureGate.canCreateHome(...)`
  - If denied: present paywall with reason `.homeLimitReached` or `.overLimit`

- `Cubby/Views/Home/AddHomeView.swift` (backup guard)
  - In `saveHome()`, re-check gate before inserting/saving
  - If denied: show a clear alert and offer Upgrade/Restore

### Add Item gating (main “+” action)

- `Cubby/Views/MainNavigationView.swift`
  - The plus button is `handleToolbarButtonTap()`
  - Before `showingAddItem = true`, call `FeatureGate.canCreateItem(homeId: selectedHome.id, ...)`
  - If denied: present paywall with reason `.itemLimitReached` or `.overLimit`

### Add Item gating (Location detail menu)

- `Cubby/Views/Home/LocationDetailView.swift`
  - Gate `showingAddItem = true` similarly (homeId from `location.home?.id`)

- `Cubby/Views/Items/AddItemView.swift` (backup guard)
  - In `saveItem()`, re-check gate before inserting/saving
  - If denied: show alert and offer Upgrade/Restore

---

## Offline behavior

- Use RevenueCat cached `CustomerInfo` to determine `isPro` immediately on launch.
- Attempt refresh in the background when network is available.
- If offline and status is unknown/unrefreshed, default to cached state (typical).

---

## Testing & QA plan

### Sandbox purchase tests

- Fresh install (Free):
  - Create first home via onboarding
  - Attempt to create a second home → paywall appears
  - Add items up to 10 → 11th item triggers paywall
- Purchase annual → `pro` activates immediately → limits removed
- Purchase lifetime → `pro` activates immediately and persists
- Restore purchases on a new install/device → `pro` restored
- Let subscription expire (or simulate) → creation blocked when over-limit (Option B)

### UI test considerations

- Do **not** shrink seeded data to fit Free limits (it reduces UI coverage and makes snapshots worse).
- Add a **UI-test-only Pro override** (DEBUG-only):
  - When `UI-TESTING` / `-ui_testing` args are present, treat the user as Pro for gating so seeded data and flows remain deterministic.
  - Simplest implementation: have `ProAccessManager` force `isPro = true` in UI-testing runs (and skip network fetches if desired).

---

## Rollout steps (recommended order)

1. App Store Connect: create products + subscription group
2. RevenueCat: entitlement + offerings + packages
3. Add SDK + configure at launch
4. Add `ProAccessManager` + `FeatureGate` + `RevenueCatUI` paywall sheet
5. Wire gating into Add Home/Add Item entry points + backup guards
6. Add “Cubby Pro” screen entry point (restore/manage)
7. Sandbox test end-to-end
8. Submit for review

---

## TODO checklist

### Store / RevenueCat setup

- [ ] App Store Connect: create subscription group “Cubby Pro”
- [ ] App Store Connect: create `cubby_pro_annual` (auto-renew, $39.99/yr)
- [ ] App Store Connect: configure `cubby_pro_annual` free trial introductory offer (3 days)
- [ ] App Store Connect: create `cubby_pro_lifetime` (non-consumable, $249)
- [ ] RevenueCat: create entitlement `pro`
- [ ] RevenueCat: add products `cubby_pro_annual`, `cubby_pro_lifetime`
- [ ] RevenueCat: attach both products to `pro`
- [ ] RevenueCat: create offering `default`, set as Current, add Annual + Lifetime packages

### Code integration

- [ ] Add RevenueCat SDK + RevenueCatUI via SPM
- [ ] Add `REVENUECAT_PUBLIC_API_KEY` build setting + `Info.plist` key wiring (`RevenueCatPublicApiKey`)
- [ ] Add `Cubby/Services/ProAccessManager.swift`
- [ ] Add `Cubby/Services/FeatureGate.swift` (home/item counts + Option B)
- [ ] Add global `RevenueCatUI` paywall sheet in `Cubby/Views/Home/HomeSearchContainer.swift` (Annual w/ trial + Lifetime)
- [ ] Add “Cubby Pro” screen (`Cubby/Views/Pro/ProStatusView.swift`) with Restore/Manage
- [ ] Add “Cubby Pro” entry point in `HomePicker` menu (always-available Restore/Manage)
- [ ] Add UI-testing Pro override (so `SEED_MOCK_DATA` remains unchanged)

### Wire up gating (Cubby-specific)

- [ ] `Cubby/Views/Home/HomeView.swift`: gate “Add New Home”
- [ ] `Cubby/Views/Home/AddHomeView.swift`: backup guard in `saveHome()`
- [ ] `Cubby/Views/MainNavigationView.swift`: gate toolbar “Add Item”
- [ ] `Cubby/Views/Home/LocationDetailView.swift`: gate “Add Item”
- [ ] `Cubby/Views/Items/AddItemView.swift`: backup guard in `saveItem()`
- [ ] Add a menu entry point to open `ProStatusView` (so Restore is always reachable)

### QA

- [ ] Verify paywall triggers correctly at 1 home / 10 items
- [ ] Verify purchase success updates UI without restart
- [ ] Verify restore works
- [ ] Verify offline cached Pro state works
- [ ] Verify Option B behavior after losing Pro while over-limit

---

## Appendix A: Decision log (v1)

- Cross-device without accounts: acceptable that users may need to tap **Restore Purchases** on a new device.
- Paywall approach: use **RevenueCatUI** for v1 (smallest implementation).
- Over-limit creation scope: gate **homes + items only**; allow creating storage locations even when over-limit.
- “Cubby Pro” entry point placement: add it to the **HomePicker menu** (always-available Restore/Manage).
- Copy/positioning: Annual is primary and clearly communicates the **3-day free trial**; Lifetime remains a secondary option.
