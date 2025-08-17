#!/usr/bin/env swift

// Simple test script to verify nested locations work
// Run this after app launches to test the fix

import Foundation
import SwiftData

// Test Instructions:
// 1. Launch the app in simulator
// 2. Complete onboarding if needed
// 3. Create a root location called "Bedroom"
// 4. Tap on "Bedroom" location
// 5. Use swipe action or context menu to "Add Nested Location"
// 6. Create a nested location called "Closet"
// 7. Verify that "Closet" appears under "Bedroom" with proper indentation
// 8. Tap on "Closet" and add another nested location called "Top Shelf"
// 9. Verify the hierarchy: Bedroom > Closet > Top Shelf

print("""
NESTED LOCATION TEST CHECKLIST
==============================

[ ] App launches successfully
[ ] Onboarding completed (if first time)
[ ] Created root location "Bedroom"
[ ] Successfully added nested location "Closet" under "Bedroom"
[ ] "Closet" appears indented under "Bedroom"
[ ] Successfully added "Top Shelf" under "Closet"
[ ] Hierarchy displays correctly with proper indentation
[ ] Can expand/collapse parent locations
[ ] Full path shows correctly in location details

If all items are checked, nested locations are working correctly!
""")