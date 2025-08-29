# Camera Feature Technical Specification

## Executive Summary

This document outlines the technical implementation for adding native camera capture functionality to the Cubby iOS app, enabling users to take photos directly within the item creation and editing workflows.

## 1. Problem Statement

### Current Limitations
- Users must leave the app to take photos using the Camera app
- PhotosPicker only provides library access, not direct camera capture
- Friction in the item creation workflow when users want to photograph items in real-time
- No way to quickly capture an item's current state during inventory

### User Impact
- Interrupted workflow when documenting items
- Multiple app switches reduce efficiency
- Users may forget to return and complete item creation
- Poor UX for users who primarily want to photograph items as they organize

## 2. Proposed Solution

Implement a **dual-interface approach** that provides both camera capture and photo library access through distinct, clearly labeled controls within the item creation and editing views.

### Key Features
- Direct camera access button in AddItemView
- Maintain existing PhotosPicker for library access
- Camera option in ItemDetailView for updating photos
- Graceful degradation on devices without cameras
- Proper permission handling with clear messaging

## 3. Technical Architecture

### 3.1 Component Structure

```
Cubby/
├── Views/
│   ├── Components/
│   │   └── ImagePicker.swift          # New: UIImagePickerController wrapper
│   ├── Items/
│   │   ├── AddItemView.swift          # Modified: Add camera button
│   │   └── ItemDetailView.swift       # Modified: Add camera for edit
│   └── Shared/
│       └── PhotoCaptureSection.swift  # New: Reusable photo UI component
├── Services/
│   └── CameraService.swift            # New: Camera availability & permissions
└── Info.plist                          # Modified: Add NSCameraUsageDescription
```

### 3.2 Core Components

#### ImagePicker (UIViewControllerRepresentable)
```swift
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context)
    func makeCoordinator() -> Coordinator
}
```

#### CameraService
```swift
class CameraService: ObservableObject {
    static let shared = CameraService()
    
    @Published var isCameraAvailable: Bool
    @Published var cameraAuthorizationStatus: AVAuthorizationStatus
    
    func requestCameraPermission() async -> Bool
    func checkCameraAvailability() -> Bool
}
```

### 3.3 UI Implementation

#### Photo Section Layout (AddItemView)
```
┌─────────────────────────────────┐
│ Photo                           │
├─────────────────────────────────┤
│  ┌─────────────┐ ┌─────────────┐│
│  │   📷 Camera │ │ 🖼️ Library  ││
│  └─────────────┘ └─────────────┘│
└─────────────────────────────────┘
```

#### State Management
- `@State private var showingCamera = false`
- `@State private var showingImagePicker = false`
- `@State private var selectedImage: UIImage?`
- `@State private var imageSource: UIImagePickerController.SourceType = .camera`

## 4. Implementation Details

### 4.1 Permission Handling

#### Info.plist Entry
```xml
<key>NSCameraUsageDescription</key>
<string>Cubby needs camera access to take photos of your items for your inventory.</string>
```

#### Permission Flow
1. Check if camera hardware exists
2. Check current authorization status
3. Request permission if undetermined
4. Show appropriate UI based on status:
   - Authorized: Show camera button
   - Denied: Show settings prompt
   - Restricted: Hide camera option
   - Not Available: Hide camera option (simulator/iPod)

### 4.2 Image Processing Pipeline

1. **Capture**: UIImagePickerController → UIImage
2. **Orient**: Fix orientation metadata
3. **Compress**: JPEG 70% quality (matching PhotosPicker)
4. **Save**: PhotoService.savePhoto()
5. **Cache**: Update NSCache

### 4.3 Error Handling

| Scenario | User Message | Action |
|----------|-------------|--------|
| No Camera | "Camera not available on this device" | Hide camera button |
| Permission Denied | "Camera access required. Tap to open Settings." | Link to Settings |
| Save Failed | "Unable to save photo. Please try again." | Retry option |
| Memory Warning | "Large photo. Compressing..." | Auto-compress |

## 5. Technical Considerations

### 5.1 Platform Constraints
- **Simulator**: Camera unavailable, must handle gracefully
- **iPod Touch**: No camera hardware
- **iPad**: Different UI considerations for larger screen
- **iOS Version**: Minimum iOS 17.0 requirement

### 5.2 Performance
- Image compression before save (70% JPEG)
- Memory management for large photos
- Async image processing to prevent UI blocking
- Cache management (50MB limit maintained)

### 5.3 SwiftUI Integration
- UIViewControllerRepresentable for UIImagePickerController
- Proper coordinator pattern for delegate handling
- SwiftUI lifecycle management
- Sheet presentation for camera view

## 6. Testing Strategy

### 6.1 Unit Tests
```swift
class CameraServiceTests: XCTestCase {
    func testCameraAvailabilityOnSimulator()
    func testPermissionStateTransitions()
    func testImageOrientationFix()
}
```

### 6.2 UI Tests
```swift
class CameraUITests: XCTestCase {
    func testCameraButtonVisibility()
    func testPermissionPromptFlow()
    func testPhotoCaptureCancellation()
}
```

### 6.3 Manual Testing Checklist
- [ ] Camera button appears on real device
- [ ] Camera button hidden on simulator
- [ ] Permission prompt shows correct text
- [ ] Photo captures and saves correctly
- [ ] Orientation handled properly (portrait/landscape)
- [ ] Memory warnings handled gracefully
- [ ] Settings redirect works when permission denied

## 7. Migration & Rollout

### 7.1 Feature Flag (Optional)
```swift
struct FeatureFlags {
    static let isCameraEnabled = true // Can be remote-configured
}
```

### 7.2 Backwards Compatibility
- No breaking changes to existing PhotosPicker flow
- Existing photos remain unchanged
- Database schema unchanged

## 8. Future Enhancements

### Phase 2 Possibilities
- Multiple photo capture in sequence
- Built-in photo editing (crop, rotate)
- Document scanning mode
- Barcode/QR code scanning for items
- Video capture for item condition

### Phase 3 Possibilities
- Custom camera overlay with guides
- ML-powered item recognition
- Automatic background removal
- HDR capture for better item photos

## 9. Security & Privacy

### Data Protection
- Photos stored locally in app sandbox
- No automatic cloud upload without user action
- EXIF data stripped before storage
- No location data retained from photos

### Privacy Compliance
- Clear usage description in Info.plist
- Permission requested only when needed
- Graceful handling of permission denial
- No tracking of camera usage analytics

## 10. Acceptance Criteria

### Functional Requirements
- [ ] Camera button visible in AddItemView on devices with cameras
- [ ] Tapping camera button opens native camera interface
- [ ] Captured photo appears in preview after taking
- [ ] Photo saves successfully to item
- [ ] Permission prompt appears on first camera use
- [ ] Library access remains functional via PhotosPicker

### Non-Functional Requirements
- [ ] Camera opens within 1 second of tap
- [ ] Photo saves within 2 seconds
- [ ] No memory leaks during photo capture
- [ ] Graceful handling of all error states
- [ ] Works on iOS 17.0+

## 11. Dependencies

### External Dependencies
- UIKit (UIImagePickerController)
- AVFoundation (Permission checking)
- Photos framework (Existing)

### Internal Dependencies
- PhotoService (Existing)
- ValidationHelpers (Existing)
- DebugLogger (Existing)

## 12. Appendix

### A. Code Examples

#### Basic Camera Button Implementation
```swift
Button(action: { showingCamera = true }) {
    Label("Take Photo", systemImage: "camera.fill")
}
.disabled(!CameraService.shared.isCameraAvailable)
.sheet(isPresented: $showingCamera) {
    ImagePicker(image: $selectedImage, sourceType: .camera)
}
```

#### Permission Check
```swift
private func checkCameraPermission() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        return true
    case .notDetermined:
        return await AVCaptureDevice.requestAccess(for: .video)
    case .denied, .restricted:
        return false
    @unknown default:
        return false
    }
}
```

### B. References
- [Apple Human Interface Guidelines - Camera](https://developer.apple.com/design/human-interface-guidelines/capturing-photos)
- [UIImagePickerController Documentation](https://developer.apple.com/documentation/uikit/uiimagepickercontroller)
- [AVCaptureDevice Authorization](https://developer.apple.com/documentation/avfoundation/avcapturedevice/1624584-authorizationstatus)
- [PhotosPicker Documentation](https://developer.apple.com/documentation/photokit/photospicker)

---

**Document Version**: 1.0  
**Last Updated**: 2024-12-29  
**Author**: Technical Team  
**Status**: Draft - Awaiting Review