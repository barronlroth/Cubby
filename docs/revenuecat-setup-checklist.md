# RevenueCat + App Store Connect Setup Checklist (Cubby Pro)

This is the exact configuration Cubby expects for the RevenueCat integration implemented in `docs/revenuecat-integration-plan.md`.

## IDs and pricing (do not change)

**Bundle ID**
- `com.barronroth.Cubby`

**Entitlement**
- `pro`

**Products**
- `cubby_pro_annual` — auto-renewable subscription — **$39.99 / year** — **3-day free trial**
- `cubby_pro_lifetime` — non-consumable — **$249**

---

## 1) App Store Connect setup

### A. Prerequisites
- App must exist in App Store Connect with bundle ID `com.barronroth.Cubby`.
- Paid Apps agreements / banking / tax should be completed (otherwise IAPs may not be testable).

### B. Create subscription group
1. Go to **My Apps → Cubby → Subscriptions**.
2. Create a subscription group (suggested name: **Cubby Pro**).

### C. Create the annual subscription (`cubby_pro_annual`)
1. In the **Cubby Pro** subscription group, create a new subscription:
   - **Reference Name**: `Cubby Pro Annual` (any internal name is fine)
   - **Product ID**: `cubby_pro_annual`
   - **Duration**: 1 Year
2. Set the price to **$39.99/year**.
3. Add at least one localization (display name + description).
4. Configure **Introductory Offer → Free Trial → 3 days**.
5. Ensure the subscription is available for sale in the regions you care about.

### D. Create the lifetime non-consumable (`cubby_pro_lifetime`)
1. Go to **My Apps → Cubby → In-App Purchases**.
2. Create a new **Non-Consumable**:
   - **Reference Name**: `Cubby Pro Lifetime` (any internal name is fine)
   - **Product ID**: `cubby_pro_lifetime`
3. Set the price to **$249**.
4. Add at least one localization (display name + description).
5. Mark it available for sale.

### E. Sandbox testers (for purchase testing)
1. Go to **Users and Access → Sandbox Testers**.
2. Create a tester (new email; not your real Apple ID).
3. On device/simulator: sign in with the sandbox account when prompted during purchase.

### F. Xcode capability
Ensure the app target has the **In-App Purchase** capability enabled in Xcode (**Signing & Capabilities**).

---

## 2) RevenueCat dashboard setup

### A. Create/verify the app in RevenueCat
1. Create a RevenueCat project (or use an existing one).
2. Add an app for **iOS (App Store)** with bundle ID `com.barronroth.Cubby`.

### B. Connect RevenueCat to App Store Connect
RevenueCat needs to be able to read products/receipts from Apple.

Do one of the following in **RevenueCat → Project Settings → Integrations → App Store Connect** (exact menu naming may vary):
- Preferred: configure **App Store Connect API Key** access, or
- Configure the **App-Specific Shared Secret** (required for subscriptions in many setups).

### C. Create entitlement
1. Go to **Entitlements**.
2. Create entitlement: `pro`.

### D. Add products + attach to entitlement
1. Go to **Products** and add:
   - `cubby_pro_annual`
   - `cubby_pro_lifetime`
2. Attach both products to the `pro` entitlement.

### E. Create the offering (must be “Current”)
1. Go to **Offerings**.
2. Create offering (suggested identifier: `default`).
3. Set it as **Current**.
4. Add packages to the Current offering:
   - Annual → `cubby_pro_annual`
   - Lifetime → `cubby_pro_lifetime`

If the Current offering has no packages, the app will show “No purchase options found.”

---

## 3) Local app config (SDK key)

### A. Put your RevenueCat Public SDK key in the xcconfig
Set your RevenueCat **Public SDK Key** here:
- `Cubby/Config/Debug.xcconfig`
- `Cubby/Config/Release.xcconfig`

Only set the public key. Do not commit secrets.

### B. Confirm Info.plist wiring
The app reads `RevenueCatPublicApiKey` from:
- `Cubby/Info.plist`

---

## 4) How to verify it works (quick checklist)

### A. Confirm the “Cubby Pro” screen exists
- Home picker menu → **Cubby Pro** (restore/manage entry point).

### B. Trigger paywall (Free limits)
- Try to create a **2nd Home** → paywall.
- Add items until you have **10**, then try adding the **11th** → paywall.

### C. Bypass gating for Pro-flow testing (no purchases)
Launch with `UI-TESTING` (or `-ui_testing`) to force Pro and disable gating:
- `xcrun simctl launch booted com.barronroth.Cubby UI-TESTING`

Note: `UI-TESTING` also resets defaults and uses an in-memory store (good for deterministic testing, not for testing paywall triggers).

