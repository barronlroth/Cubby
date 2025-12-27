# RevenueCat Pro Integration (Cubby)

This folder contains the core helpers used to gate Cubby’s “Pro” access via RevenueCat.

## Product configuration (expected by the app)

- **Entitlement**: `pro`
- **Products**:
  - Annual subscription: `cubby_pro_annual`
  - Lifetime (non-consumable): `cubby_pro_lifetime`
- **Offerings**: RevenueCat must have a **Current** offering with packages for the products above.

## API key wiring (no secrets committed)

RevenueCat is configured from `Info.plist` (not hard-coded):

- `Cubby/Info.plist` contains `RevenueCatPublicApiKey = $(REVENUECAT_PUBLIC_API_KEY)`
- Set `REVENUECAT_PUBLIC_API_KEY` in:
  - `Cubby/Config/Debug.xcconfig`
  - `Cubby/Config/Release.xcconfig`

Notes:
- The key is the **Public SDK Key** from RevenueCat **Project Settings → API Keys**.
- Debug and Release are separate build configurations; use the same key in both unless RevenueCat provides distinct test/prod keys.

## Core types and responsibilities

### `ProAccessManager`
File: `Cubby/Services/ProAccessManager.swift`

- Owns RevenueCat state (`CustomerInfo`, `Offerings`) and derived `isPro`.
- Computes `isPro` via entitlement: `customerInfo.entitlements["pro"]?.isActive == true`.
- Configures RevenueCat once at app start and listens for updates via `PurchasesDelegate` so UI flips to Pro immediately after purchase/restore.
- Uses cached `CustomerInfo` first (fast/offline), then refreshes in the background.
- Test determinism: forces `isPro = true` and skips configuration when running:
  - UI tests (`UI-TESTING` / `-ui_testing`)
  - SwiftUI previews (`XCODE_RUNNING_FOR_PREVIEWS`)
  - XCTest (`XCTestConfigurationFilePath`)

### `FeatureGate`
File: `Cubby/Services/FeatureGate.swift`

- Centralizes free-tier limits and Option B “downgrade-safe” logic.
- Limits:
  - Free max homes: `1`
  - Free max items per home: `10`
- Option B:
  - If `!isPro` and `homeCount > 1`, deny **all creation** (homes + items) but allow view/search/edit.
- Uses `ModelContext.fetchCount` with `FetchDescriptor` + `#Predicate` for counts.

### `PaywallContext` (global sheet trigger)
File: `Cubby/Services/PaywallContext.swift`

- Defines `PaywallContext.Reason` (`homeLimitReached`, `itemLimitReached`, `overLimit`).
- Provides an `EnvironmentValues.activePaywall` binding used to present a single, global `.sheet(item:)`.

## Paywall + Pro entry points (where this is used)

- Global paywall host:
  - `Cubby/Views/Home/HomeSearchContainer.swift` creates a single `ProAccessManager` and presents `ProPaywallSheetView` from `activePaywall`.
- Paywall UI (RevenueCatUI):
  - `Cubby/Views/Pro/ProPaywallSheetView.swift` shows `PaywallView(offering: proAccessManager.offerings?.current)` and basic inline error/restore flows.
  - Auto-dismisses when `isPro` becomes `true`.
- Always-available restore/manage:
  - `Cubby/Views/Pro/ProStatusView.swift` (opened from HomePicker → “Cubby Pro”).
  - Includes Restore Purchases, and “Manage Subscription” (Annual only, via `AppStore.showManageSubscriptions`).

## Gating integration points (just-in-time)

- Add Home:
  - `HomeView` → `HomePicker` gates “Add New Home” and triggers paywall via `activePaywall`.
  - `AddHomeView` re-checks in `saveHome()` and shows an Upgrade/Restore alert (backup guard).
- Add Item:
  - `MainNavigationView` gates the toolbar “+” (main add item entry).
  - `LocationDetailView` gates “Add Item” from the location menu.
  - `AddItemView` re-checks in `saveItem()` and shows an Upgrade/Restore alert (backup guard).

## Local testing notes

- To exercise paywalls:
  - Try creating a **2nd home** (home limit).
  - Try creating an **11th item** in a home (item limit).
- To bypass gating for deterministic UI testing:
  - Launch with `UI-TESTING` (and optionally `SEED_MOCK_DATA`); the app forces `isPro = true`.

## Dashboard checklist reference

See `docs/revenuecat-setup-checklist.md` for the App Store Connect + RevenueCat configuration required for the paywall to load products.

