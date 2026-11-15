# Two-Account Shared-Home Test

A manual end-to-end check of iCloud shared homes on two simulators signed in to two different Apple IDs. Run it before shipping changes to sharing, persistence or CloudKit (see issues #81–#87). Unit tests cover the service logic with a fake container; only this run exercises real CloudKit.

## What you need

- **Two real Apple IDs** with iCloud enabled. App Store sandbox testers cannot sign in to iCloud, so they don't work here. Use accounts you control and don't mind adding test data to.
- Xcode with an iOS simulator runtime that supports iCloud sign-in.
- The **Cubby Sharing Debug** scheme. It runs the Debug configuration with `SKIP_SEEDING` (your stores are never cleared), `-com.apple.CoreData.CloudKitDebug 1` and `-com.apple.CoreData.Logging.stderr 1`. Debug builds use the CloudKit **Development** environment, so test data stays out of production.
- Pro access on both devices. Sharing and the app itself need it. Either use a working sandbox purchase, or enable the scheme's `FORCE_PRO_TIER` argument (it's off by default and only works in DEBUG).

If the Development schema is behind the model, run once with `INIT_CLOUDKIT_SCHEMA` (see [development.md](development.md)).

## Set up the simulators

```bash
xcrun simctl create "Cubby Owner" "iPhone 17"
xcrun simctl create "Cubby Participant" "iPhone 17"
```

1. Boot each simulator, open **Settings › Sign in**, and sign in with a different Apple ID on each. Turn on iCloud Drive.
2. In Xcode, choose **Cubby Sharing Debug**, then run on *Cubby Owner* and again on *Cubby Participant*. Both installs start empty.
3. On each device, finish onboarding. On the owner, create a home called `Share Test` with a location `Shelf` and an item `Tape`.
4. Keep Xcode's console open for each run. Filter on `CloudKit` or `Share` to follow Cubby's logs. On each device, **Options › Debug › Sharing Diagnostics** lists recent CloudKit setup, import and export events. Every one should end `ok`.

Wait for an `export · private` event that ends `ok` on the owner before sharing.

## Script

Record the result of every step. If a step fails, note the Sharing Diagnostics events and console errors from both devices.

| # | Device | Action | Expected |
|---|--------|--------|----------|
| 1 | Owner | Select `Share Test`, tap the Share button, choose **Copy Link** (or Messages). In the options, check that you can pick who can access and whether they can edit. Pick *Anyone with the link* and *Can make changes*. | The system share sheet appears without an error. The home shows the **Shared** badge. No "Couldn't Add People" alert. |
| 2 | Participant | Quit Cubby (`xcrun simctl terminate "Cubby Participant" com.barronroth.Cubby`), then open the link: `xcrun simctl openurl "Cubby Participant" "<copied link>"`. | Cubby launches cold, shows **Joining "Share Test"…**, then selects `Share Test` with **Shared with you**. `Shelf` and `Tape` are present. |
| 3 | Participant | Add item `Hammer` to `Shelf`. | Saves. Diagnostics shows `export · shared` → `ok`. |
| 4 | Owner | Wait or pull to refresh. | `Hammer` appears in `Shelf`. |
| 5 | Owner | Rename the home to `Share Test 2`. | Saves. |
| 6 | Participant | Wait. | The home is named `Share Test 2`. |
| 7 | Participant | Home picker › edit › **Leave** `Share Test 2`. | The home disappears and stays gone. On the owner, the participant is removed from the share (Shared status row › manage). |
| 8 | Owner | Home picker › edit › **Delete** `Share Test 2`. Read the confirmation. | The copy says collaborators lose access. After confirming, the home is gone. |
| 9 | Both | Quit and relaunch Cubby on both devices. | No crash. The owner has no `Share Test 2`, the participant has no shared home, and no duplicate homes appear. Diagnostics shows clean imports. |

### Variations worth running

- **Private share:** repeat steps 1–2, choosing *Only invited people* and inviting the participant's Apple ID. Also try *View only*, then check the participant can't add or edit items.
- **Warm accept:** in step 2, leave Cubby running on the participant before opening the link.
- **Join from link:** on the participant, paste the URL into **Options › Debug › Sharing Diagnostics › Join from Link**. It follows the same acceptance path.
- **Owner delete with a participant online:** keep the participant open during step 8. The home should disappear there too after the next import.

## Troubleshooting

- **"Couldn't Add People"** or a share sheet error in step 1: copy the owner's Sharing Diagnostics events and console output into an issue. Don't work around it in code; this was the failure the ShareLink change targets.
- **"This home has data that iCloud can't share yet."** The preflight found duplicate ids, a parent cycle, an object in the wrong store, or a location that belongs to another home. The console has the object URI (`Share preflight failed: …`).
- **The participant stays on "Joining…"** for more than two minutes: check for `import · shared` events and errors in Sharing Diagnostics. The banner clears after two minutes, and the home appears after the next successful import.
- **Duplicate homes after relaunch:** look for `Duplicate CDHome id …` warnings, then `Duplicate record repair: …` after the first import.
