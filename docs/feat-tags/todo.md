# Tags Feature Implementation Todo

## Overview
Implementing tags functionality for Cubby inventory items following v1 requirements from the PRD and technical specification.

## Phase 1: Data Model (1 hour)
- [x] Add `tags: Set<String> = []` property to InventoryItem model
- [x] Add computed property `sortedTags` for alphabetical display
- [x] Test data persistence with SwiftData
- [x] Verify no migration issues

## Phase 2: Basic UI Components (2 hours)
- [x] Create `TagChip.swift` component
  - [x] Display tag text with caption font
  - [x] Add optional delete button with xmark.circle.fill icon
  - [x] Style with secondary color background and capsule shape
  - [x] Add tap action for deletion

- [x] Create `TagDisplayView.swift` component
  - [x] Use LazyVGrid with adaptive columns (minimum 80pt)
  - [x] Display sorted tags using TagChip
  - [x] Add spring animation for add/remove transitions
  - [x] Pass delete callback to parent

## Phase 3: Input & Validation (2 hours)
- [x] Add `formatAsTag()` String extension
  - [x] Convert to lowercase
  - [x] Replace spaces with dashes
  - [x] Filter to allow only letters, numbers, and dashes
  - [x] Enforce 30 character limit
  - [x] Trim leading/trailing dashes

- [x] Create `TagInputView.swift` component
  - [x] TextField with tag formatting on change
  - [x] Enter key handling for submission
  - [x] Maximum 10 tags validation
  - [x] Display current tag count (e.g., "3/10 tags")
  - [x] Clear input after successful addition
  - [x] Focus management with @FocusState

- [x] Add `TagTextField` ViewModifier
  - [x] Disable autocapitalization
  - [x] Disable autocorrection
  - [x] Add haptic feedback on submission (iOS 17+)
  - [x] Real-time formatting during typing

## Phase 4: View Integration (2 hours)
- [x] Update `ItemDetailView.swift`
  - [x] Add TagDisplayView below item description
  - [x] Show "Add Tag" button in edit mode
  - [x] Present TagInputView (inline or sheet)
  - [x] Handle tag deletion
  - [x] Enforce 10 tag limit with visual feedback

- [x] Update `AddItemView.swift`
  - [x] Include TagInputView in form
  - [x] Position below description field
  - [x] Show running tag count
  - [x] Allow tag entry during creation

## Phase 5: Search Integration (1 hour)
- [x] Update `SearchViewModel.swift`
  - [x] Modify search predicate to include tags
  - [x] Implement partial tag matching
  - [x] Support multi-term search across tags
  - [x] Add result ranking by match count
  - [x] Test search performance

## Phase 6: Autocomplete (2 hours)
- [x] Implement tag suggestions in parent views
  - [x] Use @Query to fetch all items
  - [x] Extract unique tags from all items
  - [x] Filter suggestions based on current input
  - [x] Limit to 5 suggestions
  - [x] Sort suggestions alphabetically

- [x] Add UI for suggestions
  - [x] Use inline suggestions (modified from .searchSuggestions)
  - [x] Display with tag icon
  - [x] Add tap to complete functionality
  - [x] Implement real-time filtering (debouncing in search view)

## Phase 7: Polish & Testing (1 hour)
- [x] Add haptic feedback
  - [x] Light impact on tag addition
  - [x] Success feedback on tag removal

- [x] Implement animations
  - [x] Scale + opacity for tag add/remove
  - [x] Spring animation for grid updates

- [x] Add accessibility
  - [x] VoiceOver labels for tag chips
  - [x] Announce tag count changes
  - [x] Support Dynamic Type

- [x] Write unit tests
  - [x] Test tag formatting function
  - [x] Test validation logic
  - [x] Test search with tags
  - [x] Test duplicate prevention

## Out of Scope for v1
- ❌ Tags visible on home screen
- ❌ Bulk tag operations
- ❌ Tag management screen
- ❌ Tag colors or icons
- ❌ Preset/suggested tags
- ❌ Tag analytics
- ❌ Tag-based filtering

## Acceptance Criteria Checklist
- [x] Users can add up to 10 tags per item
- [x] Tags automatically format (lowercase, spaces to dashes)
- [x] Existing tags suggested during input
- [x] Tags appear as removable chips on item detail
- [x] Search finds items by tag content (partial match)
- [x] Multi-word search queries work across tags
- [x] Tags persist across app sessions
- [x] No tags visible on home screen (v1 constraint)

## Notes
- Using Set<String> for automatic duplicate prevention
- No separate Tag entity needed for v1
- SwiftData handles optional properties without migration
- Focus on rapid tag entry UX
- Maintain consistency with existing app patterns