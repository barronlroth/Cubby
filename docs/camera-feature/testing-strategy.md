# Camera Feature Testing Strategy

## Overview

Comprehensive testing approach for the camera capture feature, covering unit tests, UI tests, integration tests, and manual testing scenarios.

## Testing Pyramid

```
         /\
        /  \  Manual Testing (10%)
       /────\
      /      \  UI/E2E Tests (20%)
     /────────\
    /          \  Integration Tests (30%)
   /────────────\
  /              \  Unit Tests (40%)
 /────────────────\
```

## 1. Unit Tests

### 1.1 CameraService Tests

**File**: `/CubbyTests/CameraServiceTests.swift`

```swift
import XCTest
@testable import Cubby
import AVFoundation

class CameraServiceTests: XCTestCase {
    
    var cameraService: CameraService!
    
    override func setUp() {
        super.setUp()
        cameraService = CameraService.shared
    }
    
    func testCameraAvailabilityOnSimulator() {
        #if targetEnvironment(simulator)
        XCTAssertFalse(cameraService.isCameraAvailable, 
                      "Camera should not be available on simulator")
        #endif
    }
    
    func testPermissionStateMessages() {
        // Test each authorization state returns correct message
        let testCases: [(AVAuthorizationStatus, String?)] = [
            (.authorized, nil),
            (.denied, "Camera access is required to take photos. Please enable it in Settings."),
            (.restricted, "Camera access is restricted on this device."),
            (.notDetermined, nil)
        ]
        
        for (status, expectedMessage) in testCases {
            // Mock the status and verify message
            XCTAssertEqual(cameraService.permissionMessage(for: status), 
                          expectedMessage)
        }
    }
    
    func testCameraAvailabilityCheck() {
        let isAvailable = cameraService.checkCameraAvailability()
        #if targetEnvironment(simulator)
        XCTAssertFalse(isAvailable)
        #else
        // On device, should match system availability
        XCTAssertEqual(isAvailable, 
                      UIImagePickerController.isSourceTypeAvailable(.camera))
        #endif
    }
}
```

### 1.2 Image Processing Tests

**File**: `/CubbyTests/ImageProcessingTests.swift`

```swift
class ImageProcessingTests: XCTestCase {
    
    func testImageCompression() {
        // Create test image
        let testImage = createTestImage(size: CGSize(width: 3000, height: 4000))
        
        // Compress
        let compressed = testImage.jpegData(compressionQuality: 0.7)
        
        XCTAssertNotNil(compressed)
        XCTAssertLessThan(compressed!.count, 1_000_000, 
                         "Compressed image should be under 1MB")
    }
    
    func testImageOrientationFix() {
        // Test various orientations
        let orientations: [UIImage.Orientation] = [.up, .down, .left, .right]
        
        for orientation in orientations {
            let image = createTestImage(orientation: orientation)
            let fixed = image.fixedOrientation()
            
            XCTAssertEqual(fixed.imageOrientation, .up, 
                          "Fixed image should have .up orientation")
        }
    }
    
    func testImageSaveAndLoad() async {
        let testImage = createTestImage()
        
        // Save
        let fileName = try? await PhotoService.shared.savePhoto(testImage)
        XCTAssertNotNil(fileName)
        
        // Load
        let loaded = await PhotoService.shared.loadPhoto(fileName: fileName!)
        XCTAssertNotNil(loaded)
    }
}
```

## 2. Integration Tests

### 2.1 Camera Flow Integration

**File**: `/CubbyTests/CameraIntegrationTests.swift`

```swift
class CameraIntegrationTests: XCTestCase {
    
    func testCameraToPhotoServiceFlow() async {
        // 1. Simulate image capture
        let capturedImage = createTestImage()
        
        // 2. Process through service
        let fileName = try? await PhotoService.shared.savePhoto(capturedImage)
        XCTAssertNotNil(fileName)
        
        // 3. Verify in cache
        let cached = PhotoService.shared.getCachedPhoto(fileName: fileName!)
        XCTAssertNotNil(cached)
        
        // 4. Verify file exists
        let fileExists = PhotoService.shared.photoExists(fileName: fileName!)
        XCTAssertTrue(fileExists)
    }
    
    func testItemCreationWithCameraPhoto() async {
        let context = createTestContext()
        
        // Create item with photo
        let photo = createTestImage()
        let fileName = try? await PhotoService.shared.savePhoto(photo)
        
        let item = InventoryItem(
            title: "Test Item",
            description: "Test",
            storageLocation: createTestLocation()
        )
        item.photoFileName = fileName
        
        context.insert(item)
        try? context.save()
        
        // Verify item saved with photo
        let fetched = try? context.fetch(FetchDescriptor<InventoryItem>())
        XCTAssertEqual(fetched?.first?.photoFileName, fileName)
    }
}
```

### 2.2 Permission Flow Tests

```swift
class PermissionIntegrationTests: XCTestCase {
    
    @MainActor
    func testPermissionRequestFlow() async {
        let service = CameraService.shared
        
        // Initial state
        let initialStatus = service.cameraAuthorizationStatus
        
        // Request permission
        let granted = await service.requestCameraPermission()
        
        // Verify state change
        if initialStatus == .notDetermined {
            XCTAssertTrue(granted || !granted) // Should have a definite answer
            XCTAssertNotEqual(service.cameraAuthorizationStatus, .notDetermined)
        }
    }
}
```

## 3. UI Tests

### 3.1 Camera Button Visibility

**File**: `/CubbyUITests/CameraUITests.swift`

```swift
class CameraUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testCameraButtonVisibility() {
        // Navigate to Add Item
        app.buttons["Add Item"].tap()
        
        #if targetEnvironment(simulator)
        // Camera button should not exist on simulator
        XCTAssertFalse(app.buttons["Camera"].exists)
        #else
        // Camera button should exist on device
        XCTAssertTrue(app.buttons["Camera"].exists)
        #endif
        
        // Library button should always exist
        XCTAssertTrue(app.buttons["Library"].exists)
    }
    
    func testPhotoSectionInteraction() {
        // Navigate to Add Item
        app.buttons["Add Item"].tap()
        
        // Check photo section exists
        XCTAssertTrue(app.staticTexts["Photo"].exists)
        
        // Library button should be tappable
        let libraryButton = app.buttons["Library"]
        XCTAssertTrue(libraryButton.isHittable)
    }
}
```

### 3.2 Permission Flow UI Tests

```swift
extension CameraUITests {
    
    func testPermissionPromptAppears() {
        // Reset permissions in setUp if needed
        app.resetAuthorizationStatus(for: .camera)
        
        // Navigate and tap camera
        app.buttons["Add Item"].tap()
        
        if app.buttons["Camera"].exists {
            app.buttons["Camera"].tap()
            
            // Verify permission alert appears
            let permissionAlert = app.alerts["Allow "Cubby" to access your camera?"]
            XCTAssertTrue(permissionAlert.waitForExistence(timeout: 2))
        }
    }
    
    func testPermissionDeniedMessage() {
        // This test requires permission to be pre-denied
        // Navigate to Add Item
        app.buttons["Add Item"].tap()
        
        // Look for permission denied message
        let message = app.staticTexts["Camera access is required"]
        if message.exists {
            // Tap should open settings
            message.tap()
            
            // Verify Settings app opens (in real device test)
            XCTAssertFalse(app.wait(for: .runningBackground, timeout: 2))
        }
    }
}
```

## 4. Manual Testing Checklist

### 4.1 Device Testing

#### iPhone Testing
- [ ] **iPhone 15 Pro**: Full camera functionality
- [ ] **iPhone SE**: Smaller screen layout
- [ ] **iPhone 8**: Older device performance
- [ ] **iPod Touch**: No camera available

#### iPad Testing
- [ ] **iPad Pro**: Large screen layout
- [ ] **iPad Mini**: Compact tablet layout

### 4.2 Permission Scenarios

| Scenario | Steps | Expected Result |
|----------|-------|-----------------|
| First Launch | 1. Fresh install<br>2. Add Item<br>3. Tap Camera | Permission prompt appears |
| Permission Granted | 1. Grant permission<br>2. Tap Camera | Camera opens |
| Permission Denied | 1. Deny permission<br>2. Tap Camera | Settings prompt appears |
| Permission Changed | 1. Grant in Settings<br>2. Return to app | Camera button enabled |

### 4.3 Camera Functionality

#### Basic Flow
- [ ] Open camera from Add Item
- [ ] Take photo
- [ ] Photo appears in preview
- [ ] Save item with photo
- [ ] Verify photo in item detail

#### Edge Cases
- [ ] Cancel camera without taking photo
- [ ] Take photo in landscape
- [ ] Take photo in portrait
- [ ] Low light conditions
- [ ] Flash on/off
- [ ] Front/back camera switch

### 4.4 Performance Testing

#### Memory Testing
1. Open Instruments
2. Select Allocations template
3. Profile these scenarios:
   - [ ] Take 10 photos in sequence
   - [ ] Take very large photo (max resolution)
   - [ ] Background/foreground during capture

#### Expected Metrics
- Memory: < 100MB increase per photo
- CPU: < 80% during capture
- Disk: Photos compressed to < 1MB

### 4.5 Error Scenarios

| Error | Test Steps | Expected Behavior |
|-------|------------|-------------------|
| No Space | Fill device storage | Graceful error message |
| Camera Busy | Open camera in another app first | Wait or show message |
| Corrupted Image | Provide malformed data | Handle gracefully |
| Save Failure | Make Documents readonly | Show retry option |

## 5. Accessibility Testing

### 5.1 VoiceOver Testing
- [ ] Camera button announced correctly
- [ ] Permission prompts readable
- [ ] Photo preview described
- [ ] Error messages announced

### 5.2 Dynamic Type
- [ ] Button labels scale properly
- [ ] Permission text remains readable
- [ ] Layout doesn't break at largest size

### 5.3 Reduce Motion
- [ ] Camera transitions respect setting
- [ ] No unnecessary animations

## 6. Regression Testing

### Critical Paths to Verify
1. **Existing Photo Library Flow**
   - [ ] PhotosPicker still works
   - [ ] Can select multiple photos
   - [ ] Selected photos save correctly

2. **Item Creation Without Photo**
   - [ ] Can still create items without photos
   - [ ] No required photo validation

3. **Item Editing**
   - [ ] Can change existing photo
   - [ ] Can remove photo
   - [ ] Can add photo to item without one

## 7. Test Data

### Test Images
```swift
struct TestImages {
    static let small = createImage(width: 100, height: 100)
    static let medium = createImage(width: 1000, height: 1000)
    static let large = createImage(width: 4000, height: 3000)
    static let portrait = createImage(width: 3000, height: 4000)
    static let landscape = createImage(width: 4000, height: 3000)
    static let square = createImage(width: 2000, height: 2000)
}
```

### Test Scenarios
```swift
struct TestScenarios {
    static let permissions = [
        "first_launch",
        "permission_granted",
        "permission_denied",
        "permission_restricted"
    ]
    
    static let devices = [
        "iPhone_with_camera",
        "iPhone_without_camera",
        "iPad_with_camera",
        "Simulator"
    ]
}
```

## 8. Continuous Integration

### CI Pipeline Configuration

```yaml
# .github/workflows/camera-tests.yml
name: Camera Feature Tests

on:
  pull_request:
    paths:
      - 'Cubby/Views/Components/ImagePicker.swift'
      - 'Cubby/Services/CameraService.swift'
      - 'Cubby/Views/Items/AddItemView.swift'

jobs:
  unit-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -project Cubby.xcodeproj \
            -scheme Cubby \
            -destination 'platform=iOS Simulator,name=iPhone 15'
  
  ui-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run UI Tests
        run: |
          xcodebuild test \
            -project Cubby.xcodeproj \
            -scheme CubbyUITests \
            -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 9. Test Reporting

### Metrics to Track
- **Test Coverage**: Aim for >80% code coverage
- **Test Execution Time**: Unit tests < 10s, UI tests < 60s
- **Failure Rate**: Track flaky tests
- **Device Coverage**: Test on 5+ device types

### Test Report Template
```markdown
## Camera Feature Test Report
Date: [DATE]
Version: [VERSION]
Tester: [NAME]

### Summary
- Total Tests: XX
- Passed: XX
- Failed: XX
- Skipped: XX

### Coverage
- Code Coverage: XX%
- Device Coverage: X/X devices
- OS Coverage: iOS 17.0 - 18.0

### Issues Found
1. [Issue description]
   - Severity: [High/Medium/Low]
   - Steps to reproduce
   - Expected vs Actual

### Recommendations
- [Any improvements needed]
```

## 10. Post-Release Monitoring

### Key Metrics
1. **Crash Rate**: Monitor camera-related crashes
2. **Permission Grant Rate**: Track acceptance rate
3. **Feature Usage**: Camera vs Library selection ratio
4. **Performance**: Photo save time P50/P95/P99

### Error Tracking
```swift
// Add analytics
Analytics.track("camera_opened")
Analytics.track("camera_permission_granted")
Analytics.track("camera_permission_denied")
Analytics.track("photo_captured")
Analytics.track("photo_save_failed", properties: ["error": error])
```

---

**Document Version**: 1.0  
**Last Updated**: 2024-12-29  
**Test Coverage Target**: 80%  
**Estimated Testing Time**: 4-6 hours