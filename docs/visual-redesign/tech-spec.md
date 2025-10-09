# Visual Redesign Tech Spec (Sprint 2025-09)

## Overview
- Purpose: Refresh the Home list screen visuals and interactions while staying fully native in SwiftUI and reusing existing data flow and models.
- Scope: Typography, spacing, colors, icons, section headers, item rows, top controls (home selector), and a native iOS 26 bottom toolbar hosting search + add actions. No data model changes.
- Non-goals: Cloud sync, new navigation patterns beyond the bottom toolbar, tags, or location-management overhaul.

## References
- Figma: https://www.figma.com/design/uT23Q6PFe3aBu99hHAKnhc/Cubby?node-id=69-1871
- Prior spec: `docs/home-page-redesign/tech-spec.md` (logic and grouping)
- App principles: `CLAUDE.md` (pass IDs, hide empty locations, etc.)

## Target Screens
- Home list (items grouped by location sections)
- Search (existing screen; visuals only if needed)
- Bottom toolbar (Search + Add controls)

## Design System (SwiftUI-first)
- Typography:
  - Home name title: Display/Serif (custom if provided), weight semi-bold, scales with Dynamic Type.
  - Section title: `title2.bold()`; sub-path: `callout.italic()` with secondary color.
  - Item title: `headline.bold()`; subtitle/notes: `subheadline` with `.secondary`.
- Colors:
  - Default to Figma visuals where specified:
    - Background (light mode): `#FAF9F6` via `Color("AppBackground")`
    - Primary/secondary text: `.primary` / `.secondary`
    - Icon circle: `#ECDBBD` via `Color("ItemIconBackground")`
  - Dark mode: keep using system semantic backgrounds until dark palette is provided; text and controls remain semantic.
- Icons:
  - Use Figma-provided icons for header chevron, search, and path separators; fallback to SF Symbols only if assets are removed.
  - Item leading icon is emoji (not photo) rendered inside a 48x48 circle with subtle shadow (optional)
- Spacing:
  - Horizontal inset: 16
  - Vertical item padding: 10–12
  - Section header top spacing: 24; bottom: 8
- Shape & effects:
  - Item row uses plain background (no card chrome) to keep List performant
  - Use `.contentShape(Rectangle())` for full-row taps

- App Header (Home Selector)
  - Layout: Left-aligned Home name with down-caret
  - Implementation: `toolbar` with `ToolbarItem(placement: .navigationBarLeading)` for a `Menu` or `Button` opening Home picker
  - Title style: large text within content area (not large nav bar title) for easier custom font usage; use a VStack header above the list that collapses with scroll (confirmed)

- Section Header
  - Shows full path: root → … → parent → current. Render on a single line with tail truncation if it exceeds one line.
  - Example: “Travel Bags → Under My Bed → Treasure Chest” (path separator icon from Figma).
  - SwiftUI: simple HStack/VStack; avoid sticky background complexity; rely on List’s default sticky behavior.
  - No item counts in this visual pass; keep logic available behind a flag.

- Item Row
  - Leading: 48x48 circle with emoji; background `ItemIconBackground` (or `secondarySystemBackground` fallback)
  - Title + subtitle; truncate subtitle to 1 line
  - Trailing: chevron; disable disclosure indicator for non-navigable rows
  - Tapping navigates to `ItemDetailView`
  - Emoji selection: Use a stable fallback derived from `item.id` hashing into a curated emoji list. In the future, allow user override (model field to be added later). This avoids visual churn across launches.
  - Performance: Emoji variant only in list (photo moves to Item Detail Page).

- Bottom Toolbar (Search + Add)
  - Native iOS 26 bottom bar built with `toolbar` and `.bottomBar` placement to gain liquid glass chrome
  - Search: Apply `.searchable(text:placement:prompt:)` with `placement: .toolbar` and `.searchToolbarBehavior(.minimize)` so the system renders the minimized search pill that expands inline for filtering; no sheet hand-off
  - Trailing content: Add Item `Button` (icon-only) that opens `AddItemView`
  - Layout: System-managed capsule with 12pt gap between controls, horizontal padding 16, bottom padding 36; respects bottom safe area by default
  - Styling: `.toolbarBackground(.thinMaterial, for: .bottomBar)` + `.toolbarBackgroundVisibility(.visible, for: .bottomBar)`; hide shared background per-item when we want separated pills
  - Availability: Bottom toolbar appears only in compact-width contexts (iPhone); revert to existing toolbar/search affordances on iPad/Mac

## Behavior
- Grouping & Sorting: Reuse existing logic (items grouped by location; items A–Z; sections sorted by path). Empty locations hidden.
- Home switching: Tapping Home name opens Home menu/picker; maintain `selectedHome` binding.
- Search: Inline filtering through `.searchable` keeps results live as the user types; keyboard stays active and query persists.
- Add: Bottom Add button opens `AddItemView` sheet; button is hosted entirely within `HomeView` to avoid duplicate presenters.
- Scrolling: Header collapses naturally; bottom toolbar floats above content via system chrome.
- Layout contexts: Bottom toolbar is displayed only when `horizontalSizeClass == .compact`; wider layouts continue using existing toolbar/search affordances.
- States:
  - Empty: Use `ContentUnavailableView` with guidance copy
  - Loading: No explicit spinner; SwiftData queries render reactively

## Accessibility
- Dynamic Type: All text uses system text styles; scale custom fonts with `.scaledFont` if provided.
- Contrast: Validate primary/secondary text against backgrounds; ensure 4.5:1 for body/callout.
- Hit Targets: 44x44 for row tap areas and bottom bar controls.
- VoiceOver: Meaningful labels for section headers, rows (title, location), SearchField, and Add button actions.

## Implementation Plan
1. Header: Add a scroll-aware header VStack above List with home selector; remove trailing search button.
2. Sections: Update `LocationSectionHeader` to match path styling (title + italic sub-path shown only when nested; use arrow separator asset between levels).
3. ItemRow: Add leading icon circle style; keep photos logic optional behind a flag.
4. Bottom Toolbar: Apply `.searchable(text:placement:prompt:)` with `.toolbar` placement and `.searchToolbarBehavior(.minimize)` for inline filtering; add Add button via `ToolbarItem(placement: .bottomBar)`; gate toolbar to compact width.
5. Theming: Introduce lightweight color/typography tokens (Swift constants) without a new theming system.
6. QA: Verify on iPhone 13–16, Dark Mode, Dynamic Type up to XL, and confirm NavigationSplitView behavior on iPad/Mac.

## Pseudocode Sketch
```swift
struct HomeListScreen: View {
    @Binding var selectedHomeId: UUID?
    @State private var searchQuery = ""

    var body: some View {
        List {
            header
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            ForEach(locationSections) { section in
                Section(header: sectionHeader(section)) {
                    ForEach(section.items) { item in
                        ItemRow(item: item, style: .emojiIcon)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchQuery, placement: .toolbar, prompt: "Search")
        .searchToolbarBehavior(.minimize)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(action: onAddItem) {
                    Image(systemName: "plus")
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Add Item")
            }
        }
        .toolbarBackground(.thinMaterial, for: .bottomBar)
        .toolbarBackgroundVisibility(.visible, for: .bottomBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { /* open home picker */ }) {
                HStack(spacing: 6) {
                    Text(currentHomeName).font(.system(.largeTitle, design: .serif)).bold()
                    Image("mingcute-down-line")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
```

## Risks & Mitigations
- Large custom fonts: Use scalable variants and fall back to system if not embedded.
- Bottom bar polish: Verify glass effect and padding align on devices with different safe area depths.
- Gesture conflicts: Ensure bottom bar doesn’t interfere with home indicator gestures; rely on system toolbar spacing.

## Open Questions (updated)
- Fonts: Provide serif (home title) and sans (UI) font files and preferred weights. See “Asset Drop Points”. If not provided, we’ll fall back to SF Pro + New York.
- Dark Mode palette: Provide dark equivalents for `AppBackground` and `ItemIconBackground`.
- Localization: Any copy that needs to be locked down for the new header or empty state?

## Handoff Checklist
- [ ] Figma link + component names
- [ ] Font files and usage guidelines
- [ ] Optional beige color for icon background (light/dark)
- [ ] Icon set decisions + mapping rules
- [ ] Copy for empty states and tooltips

- Fonts: Place files here and add to the Xcode target (also add to Info.plist `UIAppFonts`):
  - `Cubby/Resources/Fonts/Serif/` → e.g., `SerifDisplay-Regular.otf`, `SerifDisplay-Semibold.otf`
  - `Cubby/Resources/Fonts/Sans/` → e.g., `SansText-Regular.otf`, `SansText-Bold.otf`
  - After adding, usage in code via PostScript names, e.g., `.custom("SerifDisplay-Semibold", size: ...)` and `.custom("SansText-Regular", size: ...)` with `.scaledToFit`.

- Icons (exported from Figma):
  - Placed under `Cubby/Assets.xcassets/Icons/` as imagesets:
    - `mingcute-down-line.imageset` (home selector chevron)
    - `pajamas-search.imageset` (search icon)
    - `pajamas-arrow-right.imageset` (path separator arrow)
    - `pajamas-reply.imageset` (path prefix/marker)
  - Use with `Image("mingcute-down-line")`, `Image("pajamas-search")`, etc. All are template-rendered.

  - Color set `ItemIconBackground` will be added to `Cubby/Assets.xcassets` with the Figma light value `#ECDBBD` (dark pending).

- App background color:
  - Color set `AppBackground` will be added to `Cubby/Assets.xcassets` with light value `#FAF9F6` (dark pending). Use where the design specifies the tinted background.

## Search Toolbar Decisions

- Use SwiftUI’s `searchable(text:placement:prompt:)` with `placement: .toolbar` and `.searchToolbarBehavior(.minimize)` so the system renders the liquid-glass search capsule and handles inline filtering.
- Inline filtering replaces the previous sheet-based flow; any search text immediately updates the Home list while maintaining keyboard focus. The dedicated `SearchView` sheet remains available only when explicitly invoked from other areas (if needed).
- `HomeView` owns the Add-item presentation state; `MainNavigationView` delegates to it so there is a single source of truth for showing `AddItemView`.
- The bottom toolbar is scoped to compact-width environments (iPhone). On iPad/Mac, keep the existing NavigationSplitView toolbar/search controls to avoid awkward placement.
- No legacy (< iOS 26) fallback is required; devices running earlier OS versions will retain the current experience.
