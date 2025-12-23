# Item Detail + Edit Redesign Plan

## Goals
- Make `ItemDetailView` a polished “read” experience that matches the new visual language in the Home list.
- Move all editing out of the detail screen into a dedicated edit experience.
- Replace the current “Edit” button with an ellipsis overflow button that exposes: **Move Item**, **Edit**, **Delete**.
- Keep SwiftUI/SwiftData patterns clean (especially around sheets, navigation, and model mutation).

## Non-goals (for this iteration)
- Reworking the Home list grouping/search logic.
- Redesigning location management or the location picker hierarchy (unless required for the move flow polish).

---

## Item Detail: Visual + Layout Spec

### Overall structure (matches screenshot)
- **Background:** use existing `appBackground` (light uses `Color("AppBackground")`, otherwise system background).
- **Scrollable content:** `ScrollView` + `VStack(spacing: …)` with consistent horizontal padding (likely `16`).
- **Top controls (iOS 26 Liquid Glass):**
  - Use standard `NavigationStack` navigation + toolbar items so iOS 26 renders the **default Liquid Glass** back button and overflow control.
  - Back: keep the system back button (don’t hide it, don’t replace with a custom button).
  - Ellipsis: implement as a `.topBarTrailing` `Menu`/`Button` and let the system style it.
  - Avoid custom overlays/backgrounds/materials for these controls (no hand-rolled circular buttons).

### Navigation controls (Liquid Glass)
- Goal: the back/ellipsis controls should look like the iOS 26 system “glass” controls, not custom UI.
- Implementation guidance:
  - Don’t call `.navigationBarBackButtonHidden(true)` in `ItemDetailView`.
  - Don’t hide the navigation bar (`.toolbar(.hidden, for: .navigationBar)`) for this screen.
  - Don’t wrap the controls in custom circles/material backgrounds; rely on system styling.

### Header
- **Emoji badge (always shown):**
  - Circle background (use `ItemIconBackground` or a new “warm neutral” if desired).
  - Centered `SlotMachineEmojiView(item:fontSize:)` (larger than list; e.g. 36–44).
- **Title:**
  - Requirement: **use the same serif as the Home title** (`AwesomeSerif-ExtraTall`).
  - Plan: implement as a reusable typography token (e.g. `CubbyTypography.homeTitleSerif`) so it’s guaranteed to match.
  - Centered, 1–2 lines, with `minimumScaleFactor` for very long titles.

### Photo card
- If `photoFileName` exists:
  - Large card with rounded corners (bigger than current `12`; likely `20–28`).
  - Prefer `scaledToFill` with a fixed-ish height for a stronger “hero” feel (and then clip).
  - Keep the photo static (no full-screen viewer) for this iteration.
- If no photo:
  - Show a “hero placeholder” that still feels intentional (not a gray box). Options:
    - Keep the emoji as the hero element (bigger) with a subtle material/gradient behind it.
    - Or show an empty photo frame style with the emoji centered.

### Description
- Requirement: **Circular Book 20 @ 90% opacity**
  - Font token: `Font.custom("CircularStd-Book", size: 20, relativeTo: .body)`
  - Color: `foregroundStyle(Color.primary.opacity(0.9))`
- Layout: multiline, comfortable line spacing.
- If the description is empty/nil, hide this entire block (no placeholder).

### Metadata block (below description)
- **Location row**
  - Match Home list’s “leaf first, ancestors after” breadcrumb style (as in screenshot).
  - Display format: `Leaf → Parent → …` (not the raw `fullPath` `"A > B"`).
  - Include icon (screenshot looks like a “box” icon; choose and standardize).
- **Last updated**
  - “Last updated on …” using `modifiedAt` (fallback to `createdAt` if needed).
  - Smaller, secondary/tertiary styling.

### Tags (if applicable)
- If tags exist, show them as chips (reusing `TagDisplayView`) between description and metadata, or below metadata.
- Keep this display-only on detail; editing happens in the edit screen.

---

## Overflow (Ellipsis) Action Menu

### Behavior
- The ellipsis button opens a `Menu` with actions:
  1. **Move Item**
  2. **Edit**
  3. **Delete** (destructive)
- **Delete** should not immediately delete; it should trigger a confirmation step.

### SwiftUI implementation notes
- Use `Menu` (Apple docs: `swiftui/menu`) with `Label`-backed actions.
- Use `confirmationDialog` (Apple docs: `swiftui/view/confirmationdialog…`) or `alert` for delete confirmation:
  - Recommend `confirmationDialog` to match the “action menu” mental model.
  - Copy: mention undo availability (“You can undo this for a limited time.”)

### Post-action expectations
- **Move Item:** stay on the detail screen and update location metadata immediately.
- **Edit:** present the edit UI, then reflect changes on dismiss (title, description, photo, tags, timestamps).
- **Delete:** record undo, delete, then dismiss back.

---

## Item Edit: UX + Screen Spec

### Presentation
- Present from the overflow menu as a **sheet** containing a `NavigationStack`.
- Top bar:
  - Title: “Edit Item”
  - Cancel / Save (Save disabled until title is valid)

### Fields (recommended)
1. **Title**
   - Required, autocapitalization `.words`.
   - Validate using `ValidationHelpers.validateItemTitle`.
2. **Description**
   - Multiline editor (prefer `TextEditor` or a multi-line `TextField(axis: .vertical)` with a better visual style).
   - Validate length using `ValidationHelpers.validateItemDescription`.
3. **Photo**
   - Show current photo preview if present.
   - Actions:
     - Choose from library
     - Take photo (if supported)
     - Remove photo (destructive)
   - Interaction: tapping the photo preview opens the same photo action flow used today (picker/camera/remove).
   - When replacing a photo:
     - Save new photo, update `photoFileName`
     - Delete old photo file (to avoid orphan buildup), unless you intentionally rely on cleanup.
4. **Tags**
   - Reuse `TagInputView` + suggestions logic (currently embedded in `ItemDetailView` and `AddItemView`).

### “Move” stays separate
- Because “Move Item” is explicitly an overflow action, keep location changes out of the edit form unless you tell me otherwise (avoids duplicated flows and decision fatigue).

### Data flow / SwiftData safety
- Prefer passing **IDs into sheets**:
  - `ItemEditView(itemId: UUID)`
  - Fetch item with `FetchDescriptor` inside the sheet to avoid SwiftData reference detachment edge cases.
- Keep edits as draft `@State` until Save; on Save, write into the model + `modelContext.save()`.

---

## Engineering Approach (SwiftUI best practices)

### View decomposition
- Break `ItemDetailView` into small, testable subviews:
  - `ItemDetailTopBar` (back + menu)
  - `ItemDetailHeader` (emoji + title)
  - `ItemDetailPhotoCard`
  - `ItemDetailDescription`
  - `ItemDetailMetadata` (location + updated date)
  - (Optional) `ItemDetailTags`

### Typography tokens (to ensure consistency)
- Add a small, centralized set of font helpers (e.g. `CubbyTypography`) so:
  - Item title can literally reuse the “home location title” font token.
  - Description styling is locked to “Circular Book 20 @ 90%”.

### State + presentation
- Use an enum-driven presentation state instead of multiple booleans (cleaner and scales as you add actions):
  - e.g. `@State private var presentedSheet: PresentedSheet?`
- Load photos with `.task(id: item.photoFileName)` so changes refresh reliably.

---

## TODO Checklist (Engineering)

### Detail screen
- [ ] Create shared serif title token (`AwesomeSerif-ExtraTall`) and apply it to item title.
- [ ] Refactor `ItemDetailView` to accept `itemId: UUID` (fetch locally; handle missing/deleted item gracefully).
- [ ] Redesign `Cubby/Views/Items/ItemDetailView.swift` into the new layout (header → title → photo → description → metadata).
- [ ] Replace inline edit UI and remove “Move/Delete” bottom buttons (actions move to overflow menu).
- [ ] Implement back/ellipsis using standard toolbar items and default Liquid Glass styling (no custom backgrounds/overlays).
- [ ] Implement photo loading refresh keyed off `photoFileName`.
- [ ] Add/adjust tags display (read-only) in the new detail layout.

### Overflow menu + actions
- [ ] Add ellipsis `Menu` with: Move Item, Edit, Delete (destructive).
- [ ] Add delete confirmation via `confirmationDialog` (or `alert` if you prefer).
- [ ] Keep existing undo behavior (`UndoManager.recordDeletion`) and ensure post-delete dismiss works.

### Move flow
- [ ] Open `StorageLocationPicker` from the menu (scoped to the item’s current home only).
- [ ] Preselect current location when opening move UI.
- [ ] Apply move only when the chosen location differs; update `modifiedAt`; save.

### Edit flow
- [ ] Create `Cubby/Views/Items/ItemEditView.swift` (sheet + `NavigationStack`).
- [ ] Implement draft state for title/description/tags/photo and validation gating for Save.
- [ ] Handle photo replace/remove as a transaction: write new file → save model → then delete old file; handle missing files gracefully.
- [ ] On Save: update model fields, set `modifiedAt`, `modelContext.save()` with `do/catch` and user-facing error handling.

### Shared behavior + robustness
- [ ] Centralize tag suggestions into a shared helper/service so Add/Edit behave identically.
- [ ] Standardize persistence error handling for move/edit/delete/photo (surface failures via alert/banner; log with `DebugLogger`).

### Accessibility
- [ ] Add accessibility labels/hints for icon-only controls (ellipsis, any icon buttons); enforce 44pt hit targets.
- [ ] Use Dynamic Type-friendly sizing (e.g. `@ScaledMetric` for emoji size and photo height); validate contrast for description at 0.9 opacity.

### Previews + QA
- [ ] Add `#Preview` harnesses for detail + edit using in-memory `ModelContainer` (similar to `HomeViewPreviewData`).
- [ ] Manual QA pass: long titles, empty description, no photo, large Dynamic Type, dark mode, move across deep hierarchies, delete + undo.
- [ ] QA edge cases: edit sheet open while item moved/deleted; item deleted while viewing detail (graceful empty state).
- [ ] If you rely on fastlane snapshots, update/regenerate snapshot baselines after UI changes.

### Tests
- [ ] Add a unit test for breadcrumb formatting/order (leaf → parents) and any parsing helpers introduced for it.

---

## Acceptance Criteria
- Detail screen matches the screenshot’s hierarchy and typography requirements (serif title, description styling, leaf → parents location).
- Ellipsis menu is the only primary action entry point (Move/Edit/Delete).
- Edit is a dedicated UI (no inline editing on the detail screen).
- Move/Edit/Delete all persist correctly in SwiftData and update the detail UI immediately.
- Delete requires confirmation and still participates in the existing undo flow.

---

## Decisions (PM)
- Title uses the serif Home title (`AwesomeSerif-ExtraTall`).
- Keep the hero photo static (no full-screen viewer) for now.
- Hide the description block when empty/nil.
- In the edit screen, tapping the image launches the existing photo flow (picker/camera/remove).
- Location display is leaf → parents.
- “Move Item” is restricted to locations within the item’s current home (no cross-home move yet).

---

## Docs referenced (via sosumi)
- `Menu`: https://developer.apple.com/documentation/swiftui/menu/
- `confirmationDialog`: https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:actions:message:)-1r2g1/
- Liquid Glass: https://developer.apple.com/documentation/technologyoverviews/liquid-glass
- Adopting Liquid Glass: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass

---

## Staff Engineer Review (Brad)
- Navigation/top bar: Keep system `NavigationStack` behaviors (swipe back on iOS) even if you overlay custom controls; validate you aren’t breaking interactive pop by hiding the nav bar.
- ID-driven navigation: Consider making `ItemDetailView` itself take `itemId` (not an `InventoryItem`) for the same SwiftData detachment reasons you noted for sheets, and to handle “item deleted” gracefully.
- Persistence/error handling: Avoid `try? modelContext.save()`; use `do/catch` and surface failures (alert/banner) for move/edit/photo ops.
- Photo lifecycle: Route load/save/delete through `PhotoService` (and/or the existing cleanup service). Delete the old photo file only after the new one is written and the model save succeeds; handle “file missing” with a placeholder + debug log.
- Move flow constraints: Clarify whether moving across homes is supported; if not, ensure the picker is scoped to the item’s current home and continues enforcing depth/cycle rules.
- Accessibility: Add explicit requirements for icon-only controls (labels/hints), hit targets (44pt), Dynamic Type scaling (`@ScaledMetric` for emoji size/photo height), and contrast checks for the 0.9 opacity description text.
- Reuse tag logic: If tag suggestions are currently embedded in multiple screens, extract into a small shared view model/service so Add/Edit behave identically and can be tested.
- Testing/QA: Add at least a unit test for breadcrumb ordering (leaf → parents), plus regression checks for “edit sheet open while item is moved/deleted” edge cases.

---

## Author Response
- Navigation/top bar — **Agree**: Keep `NavigationStack` default behaviors and use standard toolbar placements (`.topBarLeading` / `.topBarTrailing`) without custom overlay/backgrounds so Liquid Glass can render the navigation controls correctly. Action: ensure interactive pop remains enabled and avoid `.navigationBarBackButtonHidden(true)` unless we replace it correctly.
- ID-driven navigation — **Agree**: This aligns with our repo-wide “pass IDs, not objects” rule. Action: refactor `ItemDetailView` to take `itemId: UUID` and fetch via `FetchDescriptor`; show an empty/missing state (and dismiss/pop) if the item no longer exists.
- Persistence/error handling — **Agree**: Action: standardize `do/catch` on save/move/edit/photo operations and surface errors via `alert` (and log with `DebugLogger`) instead of `print`/silent failure.
- Photo lifecycle — **Agree**: Action: treat photo updates as a 2-step transaction: write new file → save model → then delete old file; if any step fails, retain the previous file reference. Also handle missing files gracefully (placeholder + log).
- Move flow constraints — **Resolved**: Limit “Move Item” to locations in the item’s current home for now (simpler UI and fewer edge cases).
- Accessibility — **Agree**: Action: require accessibility labels/hints for icon-only controls, enforce 44pt hit targets, use `@ScaledMetric` for key sizes (emoji/photo height), and verify contrast (especially description at 0.9 opacity) across light/dark + increased contrast.
- Reuse tag logic — **Agree (scope-controlled)**: I agree we should de-duplicate. Action: extract tag-suggestion generation into a small shared helper/service (pure function or lightweight type) rather than a heavy view model unless we need async behavior later.
- Testing/QA — **Agree**: Action: add a unit test for breadcrumb ordering (leaf → parents) and add regression QA cases for “edit sheet open while item is moved/deleted” by ensuring the edit view handles missing item and/or disables saving when the backing record is gone.

---

## Staff Follow-up (Brad)
- Looks aligned overall — I’m comfortable proceeding once the doc is made internally consistent.
- Please reconcile the “floating custom top controls” spec with your updated decision to use standard toolbar placements for Liquid Glass; pick one approach and update the earlier layout section accordingly (my preference: keep system back button + add an ellipsis toolbar item).
- Please add an explicit macOS/iPad adaptation note (toolbar vs overlay, window resizing behavior, pointer hit targets/hover) since Cubby ships on macOS too.
- Process note: avoid editing the “Staff Engineer Review” bullets after the fact; add clarifications in “Author Response” so review history stays auditable.

---

## Author Response (Follow-up)
- Consistency — **Resolved**: The “Top controls (iOS 26 Liquid Glass)” section now specifies standard `NavigationStack` navigation + toolbar items (system back + trailing ellipsis `Menu`), with explicit “don’t hide/don’t customize” guidance.
- macOS/iPad note — **Out of scope**: Per PM direction, this redesign plan is iOS-only for now; we can add a platform adaptation section if/when macOS becomes in scope again.
- Review history — **Agree**: Going forward, keep review bullets as-written and add any corrections/clarifications in “Author Response” sections.
