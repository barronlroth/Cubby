# Nav/Search Refactor Plan

## Current Implementation Snapshot
- `HomeSearchContainer` wraps the content in a `TabView` with a `.search` role tab and relies on `.searchable(text:placement:.toolbarPrincipal)` to inject the navigation search UI. The plus button is injected through toolbar items and swaps to a clear button when `\isSearching` is true.
- `.searchable` in its current placement hides/relocates the field as the user scrolls, so we never see the Liquid Glass styling Apple introduced at WWDC25.
- The add-item control floats between toolbar and bottom inset, so the search affordance and creation affordance rarely appear together in one consistent row.

## Goals & Constraints
- Adopt the system-provided Liquid Glass search bar so we get the automatic full/compact transitions and platform-adaptive placement described in Apple’s latest design guidance.
- Keep the search affordance accessible (avoid the legacy collapse-on-scroll behavior) and render the plus button in the same row, anchored to the Liquid Glass layer.
- Mirror the iOS 26 Notes pattern: persistent search with a trailing action button that turns into a "close search" affordance when the field is active.
- Maintain existing search filtering logic inside `HomeView` and respect size-class differences across iPhone, iPad, and macOS.
- Preserve accessibility (VoiceOver labels, focus handling) and ensure add-item remains disabled when no home is selected.

## Reference Notes
- [Create with Swift – Adapting Search to the Liquid Glass Design System](https://www.createwithswift.com/adapting-search-to-the-liquid-glass-design-system/):
  - Use `.searchable(text:placement:.automatic, prompt:)` on `NavigationStack`/`NavigationSplitView` to let the system choose the correct surface.
  - On iOS, the Liquid Glass search bar lives at the bottom; on iPad/macOS it moves to the top-trailing toolbar or sidebar depending on context.
  - `.searchToolbarBehavior(.minimize)` enables full-width vs compact presentation.
  - `ToolbarSpacer` + `DefaultToolbarItem(kind: .search, placement: .bottomBar)` keeps the search control embedded in the toolbar surface alongside custom items.
- [Captain SwiftUI – Finding Deeper Meaning in Liquid Glass Search](Jul 6 2025):
  - Pattern 1: Toolbar search (bottom on iPhone, top-trailing on iPad/mac) with other controls sharing the Liquid Glass layer.
  - Pattern 2: Dedicated `Tab(role: .search)` discovery page.
  - Cubby should follow Pattern 1 to match the provided mock (toolbar search + trailing FAB style button).
- Notes app reference: Plus button sits to right of the Liquid Glass search bar, flipping to an "X" when search is active; both remain in the toolbar surface and use system behavior.

## Implementation Steps
1. **Centralize search ownership**
   - Keep `.searchable` on the root navigation container (`NavigationStack`/`NavigationSplitView`) so the system renders the Liquid Glass search surface in the navigation layer.
   - Preserve the search text binding flow from `HomeSearchContainer` → `MainNavigationView` → `HomeView` for filtering.

2. **Adopt toolbar-based Liquid Glass layout**
   - Move search configuration into a `DefaultToolbarItem(kind: .search, placement: .bottomBar)` (iPhone) and rely on the same item for top-trailing placement on iPad/macOS.
   - Opt into `.searchToolbarBehavior(.minimize)` (or `.expand`) to keep the field visible while allowing the system’s compact state when appropriate.
   - Avoid custom `safeAreaInset` or material wrappers; let the system manage glass, focus, and sizing.

3. **Integrate add-item control on the glass rail**
   - Add a sibling `ToolbarItem(placement: .bottomBar)` for the add-item button, separated by `ToolbarSpacer()` to mirror the Notes layout.
   - Toggle the button icon/state (plus ↔ close) based on `isSearching`/`searchText.isEmpty`, so it doubles as a cancel action while search is active.
   - Respect `canAddItem` to disable creation when no home is selected; keep the cancel affordance enabled regardless.

4. **Focus and state management**
   - Use the existing `@Environment(\.isSearching)` or an explicit `@FocusState` only for logic that the system does not already provide (e.g., dismiss keyboard when cancel action fires).
   - When cancelling, clear the search text and drop focus via `dismissSearch()` to return to the compact toolbar state.

5. **Update `HomeSearchContainer`**
   - Remove bespoke trailing button helpers and safe-area overlays; consolidate toolbar configuration inside `MainNavigationView`.
   - Retain the `TabView` wrapper only if other tabs require it; otherwise simplify to the navigation host plus toolbar items.

6. **Validation checklist**
   - iPhone 16 Pro / iOS 26: confirm the glass bar stays pinned above the home indicator, the plus button sits to the right of the search field, and it toggles to an `X` when typing.
   - iPad + macOS: ensure the inset adapts gracefully (glass look, alignment, focus behavior) and adding items still works.
   - Accessibility: VoiceOver should announce both button states and the search field should expose the clear action; hardware keyboard tabbing should move between field and button.

## Open Questions / Follow-ups
- Do we anticipate adding a dedicated discovery tab later? If so, we may split responsibilities (toolbar search for quick filtering, tab for broader discovery) or migrate entirely to the `Tab(role: .search)` pattern.
- The mock shows a microphone icon inside the search field—add via `.searchScopes` or a custom `searchSuggestions` accessory if required.
- On macOS, do we need an additional menu command or shortcut for adding items, or is the toolbar button sufficient?
