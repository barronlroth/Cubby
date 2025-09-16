# Visual Redesign Tech Spec (Sprint 2025-09)

## Overview
- Purpose: Refresh the Home list screen visuals and interactions while staying fully native in SwiftUI and reusing existing data flow and models.
- Scope: Typography, spacing, colors, icons, section headers, item rows, top controls (home selector + search), and a floating Add button. No data model changes.
- Non-goals: Cloud sync, new navigation patterns, tags, or location-management overhaul.

## References
- Figma: https://www.figma.com/design/uT23Q6PFe3aBu99hHAKnhc/Cubby?node-id=69-1871
- Prior spec: `docs/home-page-redesign/tech-spec.md` (logic and grouping)
- App principles: `CLAUDE.md` (pass IDs, hide empty locations, etc.)

## Target Screens
- Home list (items grouped by location sections)
- Search (existing screen; visuals only if needed)
- Add actions (FAB menu)

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

## Components
- App Header (Home Selector + Search)
  - Layout: Left-aligned Home name with down-caret; trailing search icon button
  - Implementation: `toolbar` with `ToolbarItem(placement: .navigationBarLeading)` for a `Menu` or `Button` opening Home picker; trailing search `Button`
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

- Floating Add Button (FAB)
  - Circular button, bottom-right over content, with `plus` symbol
  - Action: Add Item only (opens existing AddItemView). No additional menu.
  - SwiftUI: `ZStack` overlay anchored via `alignment: .bottomTrailing`, with safe-area insets
  - Minimum tap size: 44x44; add subtle shadow; respects Dynamic Type and Reduce Motion

## Behavior
- Grouping & Sorting: Reuse existing logic (items grouped by location; items A–Z; sections sorted by path). Empty locations hidden.
- Home switching: Tapping Home name opens Home menu/picker; maintain `selectedHome` binding.
- Search: Trailing toolbar button navigates to existing SearchView. Functionality unchanged; only icon and placement updated.
- Scrolling: Header collapses naturally; no custom parallax.
- States:
  - Empty: Use `ContentUnavailableView` with guidance copy
  - Loading: No explicit spinner; SwiftData queries render reactively

## Accessibility
- Dynamic Type: All text uses system text styles; scale custom fonts with `.scaledFont` if provided.
- Contrast: Validate primary/secondary text against backgrounds; ensure 4.5:1 for body/callout.
- Hit Targets: 44x44 for row tap areas and FAB.
- VoiceOver: Meaningful labels for section headers, rows (title, location), and FAB actions.

## Implementation Plan
1. Header: Add a scroll-aware header VStack above List with home selector + search button.
2. Sections: Update `LocationSectionHeader` to match path styling (title + italic sub-path shown only when nested; use arrow separator asset between levels).
3. ItemRow: Add leading icon circle style; keep photos logic optional behind a flag.
4. FAB: Add overlay button that directly triggers Add Item; reuse existing AddItemView.
5. Theming: Introduce lightweight color/typography tokens (Swift constants) without a new theming system.
6. QA: Verify on iPhone 13–16, Dark Mode, Dynamic Type up to XL.

## Pseudocode Sketch
```swift
struct HomeListScreen: View {
    @Binding var selectedHomeId: UUID?
    @State private var showAddMenu = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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

            fab
        }
        .toolbar { toolbarItems }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { /* open home picker */ }) {
                HStack(spacing: 6) {
                    Text(currentHomeName).font(.system(.largeTitle, design: .serif)).bold()
                    Image(systemName: "chevron.down")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var fab: some View {
        Button(action: onAddItem) {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(.black))
                .shadow(radius: 6, y: 3)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Item")
    }
}
```

## Risks & Mitigations
- Large custom fonts: Use scalable variants and fall back to system if not embedded.
- List performance with overlays: Keep FAB lightweight; avoid per-row complex backgrounds.
- Gesture conflicts: Place FAB outside list hit region via padding.

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
