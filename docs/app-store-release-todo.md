# App Store Release Todo

## Overview
Comprehensive checklist for publishing Cubby to the Apple App Store.

**Current Status:**
- App Version: 1.0
- Bundle ID: `com.barronroth.Cubby`
- Min iOS Version: 18.5 (⚠️ Needs to be lowered to 17.0 for wider adoption)
- CloudKit: Configured but not implemented
- Developer Account: _To be confirmed_

---

## 1. Apple Developer Account Setup

### Account & Team
- [ ] Verify Apple Developer account is active ($99/year)
- [ ] Confirm account type (Individual vs Organization)
- [ ] Set up banking and tax information in App Store Connect
- [ ] Configure paid app agreement if planning paid features

### App Configuration
- [ ] Register App ID in Developer Portal
  - Bundle ID: `com.barronroth.Cubby`
  - [ ] Enable CloudKit capability
  - [ ] Enable Push Notifications
- [ ] Create App Store provisioning profile
- [ ] Create Distribution certificate

---

## 2. App Preparation

### Version & Build Configuration
- [ ] **CRITICAL: Lower deployment target from iOS 18.5 to iOS 17.0**
  - Current iOS 18.5 limits to only newest devices
  - iOS 17.0 provides much wider device support
- [ ] Set initial version (1.0.0)
- [ ] Configure build number (start with 1)
- [ ] Update Info.plist with required keys:
  - [ ] `NSPhotoLibraryUsageDescription` - "Cubby needs access to your photos to add images to your inventory items"
  - [ ] `NSCameraUsageDescription` - "Cubby uses the camera to take photos of your inventory items"

### App Icons & Assets
- [ ] Verify App Icon (1024x1024) is included
- [ ] Add all required icon sizes:
  - [ ] iPhone App Icon (120x120, 180x180)
  - [ ] iPad App Icon (152x152, 167x167) if supporting iPad
  - [ ] App Store Icon (1024x1024)
- [ ] Create Launch Screen or Launch Storyboard
- [ ] Add accent color and app tint color

### Code Signing & Entitlements
- [ ] Configure automatic code signing in Xcode
- [ ] Update entitlements for production:
  - [ ] Change `aps-environment` from "development" to "production"
  - [ ] Verify CloudKit container identifier
- [ ] Remove debug code and logs
- [ ] Enable optimizations for Release build

---

## 3. App Store Connect Setup

### Create App Listing
- [ ] Create new app in App Store Connect
- [ ] Set primary language (English)
- [ ] Add app name: "Cubby - Home Inventory"
- [ ] Select bundle ID: `com.barronroth.Cubby`
- [ ] Set SKU (unique identifier, e.g., "CUBBY2024")

### App Information
- [ ] **App Category**: Primary: Productivity, Secondary: Lifestyle
- [ ] **App Subtitle**: "Track where everything is stored"
- [ ] **Privacy Policy URL**: Create and host privacy policy
- [ ] **Support URL**: Create support page or use GitHub issues
- [ ] **Marketing URL**: Optional (could use GitHub repo)

### Pricing & Availability
- [ ] Set pricing tier (Free or Paid)
- [ ] Select availability in all countries/regions
- [ ] Configure pre-order if desired

---

## 4. Marketing Materials

### App Store Screenshots (Required)
**iPhone 6.9" Display (iPhone 16 Pro Max)**
- [ ] Screenshot 1: Home view with items
- [ ] Screenshot 2: Item detail with tags
- [ ] Screenshot 3: Search functionality
- [ ] Screenshot 4: Storage location hierarchy
- [ ] Screenshot 5: Adding new item with photo

**iPhone 6.5" Display (iPhone 14 Plus)**
- [ ] Reuse or resize 6.9" screenshots

**iPhone 5.5" Display (iPhone 8 Plus)** - Optional but recommended
- [ ] Resize key screenshots

**iPad Screenshots** (if supporting iPad)
- [ ] 12.9" iPad Pro screenshots
- [ ] 11" iPad Pro screenshots

### App Store Description
- [ ] **Short Description** (up to 170 characters):
  ```
  Never forget where you stored something again. Track items across multiple homes with photos, tags, and smart search.
  ```

- [ ] **Full Description** (up to 4000 characters):
  ```
  # Organize Your Life with Cubby

  Ever wondered "Do I already own this?" while shopping? Or spent hours searching for something you know you have but can't remember where? Cubby solves these everyday problems by helping you catalog and locate your belongings across multiple homes and storage locations.

  ## Key Features

  📍 **Smart Organization**
  Create a digital map of your storage spaces with our hierarchical location system. Organize from broad to specific: Home → Garage → Tool Cabinet → Top Drawer.

  🏠 **Multiple Properties**
  Perfect for managing items across multiple homes, storage units, or offices. Switch between locations effortlessly.

  📸 **Visual Inventory**
  Add photos to your items for quick visual identification. Never forget what something looks like.

  🏷️ **Flexible Tagging**
  Add custom tags to categorize items your way. Search by tags to find related items instantly.

  🔍 **Powerful Search**
  Find anything in seconds. Search by name, description, location, or tags across your entire inventory.

  ↩️ **Undo Protection**
  Accidentally deleted something? Our undo feature lets you recover items immediately.

  ## Perfect For:
  • Homeowners tracking household items
  • Collectors organizing collections
  • Small businesses managing inventory
  • Anyone with multiple storage locations
  • People planning moves or renovations

  ## Why Cubby?
  • 100% native iOS app with smooth performance
  • Privacy-focused: Your data stays on your device
  • No subscriptions or hidden fees
  • Regular updates and improvements
  • Built with Apple's latest technologies

  Start organizing your life today with Cubby!
  ```

### Keywords (100 characters max)
- [ ] Define keywords:
  ```
  inventory,storage,organize,home,tracker,items,belongings,catalog,find,location,household,manage
  ```

### What's New (Version Notes)
- [ ] Write version 1.0 release notes:
  ```
  Initial release of Cubby!
  • Track items across multiple locations
  • Add photos to your inventory
  • Organize with custom tags
  • Powerful search functionality
  • Beautiful, native iOS design
  ```

---

## 5. Privacy & Legal

### Privacy Policy (Required)
- [ ] Create privacy policy covering:
  - [ ] Data collection (photos, item information)
  - [ ] Data storage (local device only currently)
  - [ ] Future CloudKit sync plans
  - [ ] No third-party sharing
  - [ ] User rights and data deletion
- [ ] Host privacy policy online
- [ ] Add URL to App Store Connect

### Terms of Service
- [ ] Create basic terms of service
- [ ] Include liability limitations
- [ ] Host online or include in app

### App Review Information
- [ ] Demo account (if needed): N/A - local app
- [ ] Notes for reviewer:
  ```
  Cubby is a local-only inventory management app. 
  All data is stored on device using SwiftData.
  CloudKit entitlements are included for future sync features but not currently active.
  ```

### Export Compliance
- [ ] Confirm no encryption beyond iOS standard
- [ ] Submit export compliance documentation

### Age Rating
- [ ] Complete age rating questionnaire
- [ ] Expected rating: 4+ (no objectionable content)

---

## 6. Testing & Quality Assurance

### Device Testing
- [ ] Test on real devices:
  - [ ] iPhone 16 Pro
  - [ ] iPhone 15
  - [ ] iPhone 14
  - [ ] iPhone 13 or older (iOS 17 compatible)
  - [ ] iPad (if supporting)
- [ ] Test all orientations
- [ ] Test with different text sizes (accessibility)
- [ ] Test in light and dark mode

### Performance Testing
- [ ] Test with large datasets (1000+ items)
- [ ] Verify photo storage doesn't exceed reasonable limits
- [ ] Check memory usage
- [ ] Profile for performance issues

### TestFlight Beta
- [ ] Upload build to TestFlight
- [ ] Internal testing with team
- [ ] External beta testing (optional):
  - [ ] Recruit 10-20 beta testers
  - [ ] Run beta for 1-2 weeks
  - [ ] Collect and address feedback
- [ ] Fix any crash reports

### Final Checklist
- [ ] All features working correctly
- [ ] No placeholder text or images
- [ ] No debug/development UI elements
- [ ] Proper error handling for all user actions
- [ ] Network errors handled gracefully
- [ ] All text is properly localized (even if English only)

---

## 7. Submission Process

### Build & Archive
- [ ] Select "Any iOS Device" as destination
- [ ] Archive build in Xcode (Product → Archive)
- [ ] Validate archive
- [ ] Upload to App Store Connect

### App Store Connect Submission
- [ ] Select uploaded build
- [ ] Fill in all required metadata
- [ ] Upload all screenshots
- [ ] Set release date (immediate or scheduled)
- [ ] Submit for review

### Review Process
- [ ] Monitor review status (typically 24-48 hours)
- [ ] Respond quickly to any reviewer questions
- [ ] Be prepared to make quick fixes if rejected
- [ ] Have rollback plan ready

---

## 8. Launch Preparation

### Marketing
- [ ] Prepare launch announcement
- [ ] Create social media posts
- [ ] Update GitHub README with App Store link
- [ ] Consider Product Hunt launch
- [ ] Reach out to iOS app review sites

### Support Infrastructure
- [ ] Set up support email
- [ ] Create FAQ document
- [ ] Prepare for user feedback
- [ ] Set up crash reporting (Crashlytics/Sentry)
- [ ] Configure analytics (optional)

### Post-Launch Monitoring
- [ ] Monitor crash reports
- [ ] Track download numbers
- [ ] Respond to user reviews
- [ ] Gather feature requests
- [ ] Plan version 1.1 updates

---

## 9. Future Considerations

### Version 1.1+ Features
- [ ] CloudKit sync implementation
- [ ] iPad optimization
- [ ] Widget support
- [ ] Shortcuts integration
- [ ] Share extensions
- [ ] Watch app companion
- [ ] Mac app (Catalyst or native)

### Monetization (If Applicable)
- [ ] Premium features planning
- [ ] In-app purchase implementation
- [ ] Subscription model consideration
- [ ] Family sharing support

---

## Important Notes

⚠️ **Critical Issues to Fix Before Submission:**
1. **iOS Deployment Target**: Must be lowered from 18.5 to 17.0
2. **Privacy Descriptions**: Must add camera and photo library usage descriptions
3. **Testing**: Must test on physical devices, not just simulator

📅 **Timeline Estimate:**
- App preparation: 2-3 days
- Asset creation: 1-2 days
- Testing: 2-3 days
- Review process: 1-2 days
- **Total: 1-2 weeks**

💡 **Tips:**
- Submit early in the week (Monday-Wednesday) for faster review
- Have everything ready before starting submission
- Keep first version simple and stable
- Plan updates for post-launch improvements

---

## Resources

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [Screenshots Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)

---

*Last Updated: August 2024*
*Document Version: 1.0*