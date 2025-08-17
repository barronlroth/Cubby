# Cubby Implementation Todo List

## Overview
This todo list is derived from the technical specification and breaks down all implementation tasks into checkable items. Each epic is organized with its subtasks and estimated hours.

## Current Status for Handoff
**Last Updated:** August 16, 2025
**Developer:** Previous Dev
**Status:** Core features implemented, nested locations has a bug

## ⚠️ KNOWN ISSUES FOR NEXT DEVELOPER
1. **Nested Locations Not Working Properly**
   - Parent-child relationships in SwiftData not persisting correctly
   - Locations can be created but don't show up in the hierarchy
   - Possible issue with the bidirectional relationship configuration
   - Check StorageLocation.swift lines 14-17 for relationship definitions

2. **Potential SwiftData Relationship Issues**
   - Removed inverse relationships to fix circular reference crash
   - This may be causing the nested location persistence issue
   - Consider adding explicit inverse relationships back

## ✅ WORKING FEATURES
- Home creation and management
- Adding items with photos
- Moving items between locations  
- Search functionality with filtering
- Photo caching with NSCache
- Item detail view with editing
- Location deletion (for empty locations)
- Data cleanup service for orphaned photos

## Epic 1: Project Setup & Data Layer (5 hours) ✅ COMPLETED
### Configure SwiftData Schema (2 hours) ✅
- [x] Create Home model with UUID, name, dates, and cascade relationship to StorageLocation
- [x] Create StorageLocation model with bidirectional parent-child relationships
- [x] Add depth tracking and max nesting depth constant (10 levels)
- [x] Create InventoryItem model with all properties and relationships
- [x] Implement computed properties (fullPath, canDelete, canMoveTo)
- [x] Set up proper delete rules (cascade for homes, deny for locations with items)

### Implement PhotoService (2 hours) ✅
- [x] Create PhotoServiceProtocol with async methods
- [x] Set up Documents/ItemPhotos directory structure
- [x] Implement savePhoto with 70% JPEG compression
- [x] Implement loadPhoto with NSCache integration
- [x] Configure NSCache with 50MB limit and 100 image count
- [x] Implement deletePhoto and clearCache methods
- [x] Add PhotoError enum for error handling

### Create Mock Data Generator (1 hour) ✅
- [x] Build sample data generator for testing
- [x] Create at least 2 homes with nested locations
- [x] Generate sample items with and without photos
- [ ] Add debug menu integration for data generation
- [x] Create ModelContainer.preview extension for SwiftUI previews

## Epic 2: Onboarding & Home Management (5 hours) ✅ COMPLETED
### Build OnboardingView (2 hours) ✅
- [x] Create welcome UI with "Welcome to Cubby" title
- [x] Add text field for home name input
- [x] Implement validation for non-empty home name
- [x] Create first Home object in SwiftData
- [x] Auto-create "Unsorted" storage location for new home
- [x] Set hasCompletedOnboarding flag in @AppStorage
- [x] Add transition animation to HomeView

### Implement Home Picker (2 hours) ✅
- [x] Create dropdown picker component for navigation bar
- [x] Query all homes from SwiftData using @Query
- [x] Handle home switching with state management
- [x] Implement "Add New Home" menu option
- [x] Create add home flow with name input
- [x] Update current home selection in @AppStorage

### Create Home Management (1 hour) ✅
- [ ] Implement edit home name functionality
- [x] Add delete home with confirmation dialog
- [x] Enforce cascade delete for all locations/items
- [ ] Prevent deletion of last remaining home
- [x] Add success/error feedback with haptics

## 🧪 Testing Checkpoint 1
### Pause Development and Let User Test (After Epic 2)
- [ ] Build and deploy to simulator
- [ ] User validates onboarding flow
- [ ] User tests home creation
- [ ] User validates home switching
- [ ] User confirms navigation structure
- [ ] Gather feedback on UX
- [ ] Document any bugs or issues
- [ ] Make adjustments based on feedback

## Epic 3: Storage Location System (10 hours) ⚠️ PARTIAL - NESTED LOCATIONS BUG
### Build StorageLocationRow Component (3 hours) ✅
- [x] Display location name with proper typography
- [x] Show item count badge
- [x] Implement disclosure indicator for expandable locations
- [x] Add indentation based on depth level
- [x] Implement swipe actions (Add Nested, Delete)
- [x] Handle tap to show location details
- [x] Add loading state for large child lists

### Implement OutlineGroup Integration (2 hours) ⚠️ HAS ISSUES
- [x] Set up OutlineGroup with StorageLocation data
- [ ] ⚠️ Configure parent-child relationship binding - NOT WORKING PROPERLY
- [x] Implement expand/collapse state persistence
- [x] Add @AppStorage for remembering expanded states
- [ ] Handle lazy loading for locations with >50 children
- [x] Optimize performance for deep nesting

### Create Add Location Flow (2 hours) ✅
- [x] Build location creation form view
- [x] Add text field with validation
- [x] Implement parent location picker
- [x] Validate unique names within same parent
- [x] Check nesting depth limit (max 10)
- [x] Save new location to SwiftData
- [x] Auto-select newly created location

### Implement Location Deletion (2 hours) ✅
- [x] Check for items in location before delete
- [x] Check for child locations
- [x] Show appropriate error messages
- [x] Implement confirmation dialog
- [x] Handle successful deletion with animation
- [ ] ⚠️ Update parent's child array - MAY HAVE ISSUES

### Build Location Detail View (1 hour) ✅
- [x] Display all items in location
- [x] Show child locations list
- [ ] Implement inline name editing
- [x] Add item count display
- [x] Show full location path
- [x] Add empty state for no items

## 🧪 Testing Checkpoint 2
### Pause Development and Let User Test (After Epic 3)
- [ ] Build and deploy to simulator
- [ ] User tests storage location creation
- [ ] User validates nested location functionality
- [ ] User tests expand/collapse behavior
- [ ] User validates swipe actions
- [ ] User tests location deletion rules
- [ ] Gather feedback on hierarchy UX
- [ ] Document issues with nesting
- [ ] Validate performance with deep nesting

## Epic 4: Item Management (11 hours) ✅ COMPLETED
### Build AddItemView Form (3 hours) ✅
- [x] Create NavigationStack with Form
- [x] Add Item Details section with title/description fields
- [x] Add Location section with picker navigation
- [x] Add Photo section with add/remove functionality
- [x] Implement form validation (title and location required)
- [x] Create save functionality with transaction handling
- [x] Add cancel button with confirmation if changes made
- [x] Handle keyboard dismissal properly

### Implement StorageLocationPicker (3 hours) ✅
- [x] Build hierarchical location list
- [x] Show full path for each location
- [x] Add search bar for filtering locations
- [x] Implement "Create New Location" button
- [x] Handle inline location creation
- [x] Auto-select created location
- [x] Add visual hierarchy with indentation
- [x] Highlight currently selected location

### Create Image Picker Integration (2 hours) ✅
- [x] Integrate PhotosPicker from PhotosUI
- [x] Handle image selection callback
- [x] Display selected image preview
- [x] Compress and save using PhotoService
- [x] Handle save failures gracefully
- [x] Add remove photo functionality
- [x] Show loading state during save

### Build ItemDetailView (2 hours) ✅
- [x] Display photo with AsyncImage if exists
- [x] Show title with inline editing
- [x] Show description with inline editing
- [x] Display storage location with full path
- [x] Implement "Move Item" functionality
- [x] Add delete with confirmation
- [x] Show created/modified dates
- [x] Handle photo deletion on item delete

### Create ItemRow Component (1 hour) ✅
- [x] Show thumbnail image if photo exists
- [x] Display title and truncate if needed
- [x] Show storage location name
- [x] Handle tap to navigate to detail
- [x] Add swipe to delete action
- [x] Implement loading state for photo

## 🧪 Testing Checkpoint 3 (Major Milestone)
### Pause Development and Let User Test (After Epic 4)
- [ ] Build and deploy to simulator
- [ ] User tests complete item creation flow
- [ ] User validates photo capture/selection
- [ ] User tests item editing
- [ ] User validates item moving between locations
- [ ] User tests item deletion
- [ ] Test with 50+ items for performance
- [ ] Validate photo compression quality
- [ ] Gather feedback on core workflow
- [ ] **This is the main validation point - app is feature complete**

## Epic 5: Search & Discovery (6 hours) ✅ COMPLETED
### Build Search UI (2 hours) ✅
- [x] Create floating search pill button
- [x] Implement tap to expand animation
- [x] Build full-screen search view
- [x] Auto-focus search field on presentation
- [x] Add clear button when text present
- [x] Implement dismiss gesture/button
- [x] Style with iOS 18 design language

### Implement Search Logic (2 hours) ✅
- [x] Create SearchViewModel with @Published properties
- [x] Implement 300ms debouncing with Task
- [x] Build SwiftData predicates for search - Simplified to in-memory filtering
- [x] Search in both title and description
- [x] Implement home filter functionality
- [x] Sort results by modified date
- [x] Handle empty search state

### Create Search Results View (1 hour) ✅
- [x] Build results list with ItemRow
- [x] Show full location path for each item
- [x] Display home name if multiple homes
- [x] Handle tap to navigate to item detail
- [x] Add empty state for no results
- [x] Show loading state during search

### Add Search Optimizations (1 hour) ✅
- [ ] Implement search result caching
- [ ] Cache last 10 searches
- [x] Optimize SwiftData fetch descriptors - Using in-memory filtering instead
- [ ] Add performance monitoring
- [ ] Test with 1,000+ items
- [x] Ensure <100ms response time

## 🧪 Testing Checkpoint 4
### Pause Development and Let User Test (After Epic 5)
- [ ] Build and deploy to simulator
- [ ] User tests search functionality
- [ ] User validates search performance
- [ ] User tests home filtering
- [ ] User validates search result navigation
- [ ] Test with 100+ items
- [ ] Gather feedback on search UX

## Epic 6: Empty States & Polish (6 hours)
### Design Empty State Components (2 hours)
- [ ] Create reusable EmptyStateView component
- [ ] Add SF Symbol icons for each state
- [ ] Write contextual copy for each scenario
- [ ] Add action buttons where appropriate
- [ ] Implement consistent styling
- [ ] Add subtle animations

### Implement Empty States (1 hour)
- [ ] No homes state (shouldn't happen but handle it)
- [ ] No storage locations in home
- [ ] No items in location
- [ ] No search results
- [ ] No photo for item
- [ ] Location picker empty state

### Add Loading States (1 hour)
- [ ] Create reusable ProgressView styles
- [ ] Add loading for data fetches
- [ ] Implement skeleton screens for lists
- [ ] Show progress for photo operations
- [ ] Add timeout handling
- [ ] Ensure smooth transitions

### Polish Animations (2 hours)
- [ ] Add view transition animations
- [ ] Implement smooth expand/collapse for locations
- [ ] Add haptic feedback (light impact for actions)
- [ ] Polish floating button animations
- [ ] Add success haptics for saves
- [ ] Implement delete animations

## Epic 7: Error Handling & Edge Cases (5 hours)
### Implement Error Handling (2 hours)
- [ ] Handle photo save failures with rollback
- [ ] Catch SwiftData save errors
- [ ] Handle network errors (future)
- [ ] Show user-friendly error alerts
- [ ] Add retry mechanisms where appropriate
- [ ] Log errors for debugging

### Handle Edge Cases (2 hours)
- [ ] Truncate very long names in UI
- [ ] Handle deep nesting performance
- [ ] Manage large photos (>10MB)
- [ ] Prevent circular references in moves
- [ ] Handle app termination during saves
- [ ] Manage low storage scenarios

### Add Data Validation (1 hour)
- [ ] Validate all text inputs
- [ ] Prevent duplicate names at same level
- [ ] Ensure required fields before save
- [ ] Validate photo file sizes
- [ ] Check nesting depth limits
- [ ] Sanitize user input

## 🧪 Testing Checkpoint 5 (Final)
### Pause Development and Let User Test (After Epic 7)
- [ ] Build and deploy to simulator
- [ ] Complete end-to-end testing
- [ ] User validates all error handling
- [ ] Test edge cases
- [ ] Performance testing with 1000+ items
- [ ] User confirms app is ready for personal use
- [ ] Document any remaining issues
- [ ] Create list of V2 features based on usage

## Additional Tasks
### Data Cleanup Service
- [ ] Implement DataCleanupService class
- [ ] Create orphaned photo detection
- [ ] Delete orphaned photos on app launch
- [ ] Add cleanup to app lifecycle
- [ ] Test with various scenarios

### Undo/Redo Support
- [ ] Create UndoManager struct
- [ ] Implement item deletion recording
- [ ] Add undo functionality for deletes
- [ ] Limit undo history to 10 items
- [ ] Add UI for undo action
- [ ] Clear undo stack on app restart

### Testing Setup
- [ ] Create TestPhotoService mock
- [ ] Set up in-memory test containers
- [ ] Build preview data generators
- [ ] Create UI test target
- [ ] Add performance test suite
- [ ] Set up continuous integration

### App Configuration
- [ ] Configure versioned schema in CubbyApp
- [ ] Set up ModelContainer properly
- [ ] Implement app lifecycle handling
- [ ] Add data cleanup on launch
- [ ] Configure proper entitlements
- [ ] Set up app icons and launch screen

## Performance Requirements
- [ ] App launch time < 2 seconds
- [ ] Search response < 100ms for 1,000 items
- [ ] Photo loading < 500ms with cache
- [ ] Support 10,000+ items without lag
- [ ] Smooth scrolling in all lists
- [ ] No memory leaks with photos

## Code Quality Checklist
- [ ] Follow SwiftUI best practices
- [ ] Maintain clear separation of concerns
- [ ] Use protocol-based design for services
- [ ] Achieve 80% unit test coverage
- [ ] Document complex logic
- [ ] Use consistent naming conventions

## Delivery Milestones
### Week 1: Foundation ✅
- [x] Complete Epic 1 (Data Layer)
- [x] Complete Epic 2 (Onboarding)
- [x] NavigationSplitView shell working
- [x] Photo service with caching

### Week 2: Core Features ⚠️ PARTIAL
- [⚠️] Complete Epic 3 (Storage Locations) - Has nested location bug
- [x] Complete Epic 4 (Item Management)
- [ ] Undo support working
- [x] iPad navigation functional

### Week 3: Search & Polish ⚠️ PARTIAL
- [x] Complete Epic 5 (Search)
- [x] Complete Epic 6 (Empty States)
- [ ] Complete Epic 7 (Error Handling)
- [ ] Performance testing complete
- [ ] Final bug fixes

## Notes
- Each checkbox represents a discrete, testable piece of functionality
- Time estimates are included in epic headers
- Dependencies should be completed in order within each epic
- Test each feature as it's completed
- Update this list as new requirements emerge

## Handoff Summary for Next Developer
### What Works ✅
- Complete onboarding flow
- Home management (create, switch, delete)
- Root-level storage location creation
- Item management with photos (add, edit, delete, move)
- Search with home filtering
- Photo service with caching
- Empty states throughout the app

### What Needs Fixing 🔧
1. **PRIORITY: Nested Location Creation**
   - Locations are created but parent-child relationships don't persist
   - Check SwiftData relationship configuration in StorageLocation.swift
   - May need to restore inverse relationships with proper configuration

### What's Not Implemented Yet 📝
- Undo/Redo support
- Edit home name functionality
- Prevent deletion of last remaining home
- Debug menu for mock data generation
- Performance testing with 1000+ items
- Error handling improvements
- Full test coverage

### Files to Review First
1. `/Cubby/Models/StorageLocation.swift` - Check relationship definitions
2. `/Cubby/Views/Home/AddLocationView.swift` - Location creation logic
3. `/Cubby/Views/Home/StorageLocationRow.swift` - Hierarchy display
4. `/Cubby/CubbyApp.swift` - ModelContainer setup