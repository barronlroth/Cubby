# Product Requirements Document: Home Page List View Redesign

## Overview
Transform the home page from a hierarchical folder structure to a flat list view that displays all inventory items grouped by their storage locations.

## Problem Statement
Currently, users must navigate through multiple levels of storage locations to view their items. This creates friction when users want to quickly scan their entire inventory or when they're unsure which location contains a specific item.

## Solution
Display all items directly on the home page in a continuous list view, with storage locations serving as section headers. This provides immediate visibility of all inventory items while maintaining organizational context.

## Requirements

### Functional Requirements

#### 1. List View Structure
- Display all items for the selected home in a single scrollable list
- Group items by their storage location
- Each storage location appears as a non-interactive section header
- Items appear directly under their storage location header

#### 2. Location Headers
- **No visual indentation** for nested locations
- Display full location path in header (e.g., "Bedroom > Closet > Top Shelf")
- Include item count badge in header
- Maintain consistent header styling using standard iOS section headers

#### 3. Item Display
- Show item row with:
  - Thumbnail photo (if available)
  - Item title
  - Item description (truncated if needed)
- Maintain existing tap behavior to open item detail view
- Preserve existing swipe actions for items

#### 4. Empty States
- Show appropriate empty state when no items exist
- Section headers should not appear for locations without items

#### 5. Performance
- Implement lazy loading for large item lists
- Maintain smooth scrolling performance
- Cache item photos using existing PhotoService

### Non-Functional Requirements

#### 1. Design Consistency
- **Use standard Apple design patterns**
- Maintain existing app aesthetics
- Follow iOS Human Interface Guidelines
- Use native SwiftUI List with sections

#### 2. Accessibility
- Ensure proper VoiceOver support for headers and items
- Maintain keyboard navigation support
- Preserve existing accessibility labels

#### 3. Compatibility
- Support iOS 17.0+
- Maintain iPad/Mac compatibility
- Preserve existing navigation patterns

## Technical Implementation

### Data Structure
```swift
struct LocationSection {
    let location: StorageLocation
    let locationPath: String  // "Bedroom > Closet > Top Shelf"
    let items: [InventoryItem]
}
```

### View Hierarchy
```
HomeView (modified)
├── List
│   └── ForEach(locationSections)
│       ├── Section Header (location path + count)
│       └── ForEach(items)
│           └── ItemRow (existing component)
```

### Key Changes
1. Modify `HomeView` to fetch and display all items
2. Create helper to build location path strings
3. Group items by storage location
4. Filter out empty locations
5. Reuse existing `ItemRow` component

## Success Metrics
- Reduced taps to view items (from 2-4 to 0)
- Improved item discoverability
- Maintained or improved scroll performance
- No regression in existing functionality

## Out of Scope
- Changing item creation flow
- Modifying storage location management
- Altering item detail views
- Adding new sorting or filtering options
- Changing the visual design language

## Migration Plan
1. Create new list view implementation
2. Test with various data sets
3. Ensure performance with 100+ items
4. Validate empty states
5. Deploy as direct replacement

## Risks & Mitigations
- **Risk**: Performance degradation with many items
  - **Mitigation**: Implement lazy loading and pagination if needed
- **Risk**: Loss of hierarchical context
  - **Mitigation**: Show full location path in headers
- **Risk**: Confusion during transition
  - **Mitigation**: Maintain familiar visual elements and interactions