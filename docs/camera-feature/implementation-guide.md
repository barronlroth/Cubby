# Camera Feature Implementation Guide

## Overview

This guide provides step-by-step instructions for implementing the camera capture feature in Cubby. Follow these steps in order to ensure a smooth implementation.

## Prerequisites

- [ ] Xcode 15.0 or later
- [ ] iOS 17.0+ deployment target
- [ ] Physical iOS device for testing (camera doesn't work on simulator)
- [ ] Understanding of UIKit/SwiftUI interop

## Implementation Steps

### Phase 1: Project Setup (15 minutes)

#### Step 1.1: Create Feature Branch
```bash
git checkout main
git pull origin main
git checkout -b feat/camera-capture
```

#### Step 1.2: Update Info.plist
Add camera usage description to `/Cubby/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Cubby needs camera access to take photos of your items for your inventory.</string>
```

**Location**: Add after the existing `UIBackgroundModes` entry.

#### Step 1.3: Create Privacy Manifest (Required for iOS 17+)
Create new file: `/Cubby/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

#### Step 1.4: Verify Project Settings
1. Open `Cubby.xcodeproj`
2. Select the Cubby target
3. Go to Info tab
4. Verify "Privacy - Camera Usage Description" appears

### Phase 2: Core Components (45 minutes)

#### Step 2.1: Create ImagePicker Component

Create new file: `/Cubby/Views/Components/ImagePicker.swift`

**Important**: UIImagePickerController is the correct API for camera access. There is no native SwiftUI camera view.

```swift
import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        
        // Accessibility
        picker.view.accessibilityLabel = "Camera view"
        picker.view.accessibilityHint = "Take a photo of your item"
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, 
                                 didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Fix orientation if needed
                parent.image = image.fixedOrientation()
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Image orientation fix extension
extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}
```

#### Step 2.2: Create Camera Service

Create new file: `/Cubby/Services/CameraService.swift`

```swift
import SwiftUI
import AVFoundation
import UIKit

// Modern implementation with @MainActor and proper error handling
@MainActor
final class CameraService: ObservableObject {
    static let shared = CameraService()
    
    @Published private(set) var isCameraAvailable: Bool = false
    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    
    private init() {
        self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        self.isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        
        DebugLogger.info("CameraService initialized - Available: \(isCameraAvailable)")
    }
    
    nonisolated func checkAuthorizationStatus() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        await MainActor.run {
            self.authorizationStatus = status
        }
    }
    
    func requestCameraPermission() async -> Bool {
        switch authorizationStatus {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
            return granted
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    func checkCameraAvailability() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }
    
    var error: CameraError? {
        switch authorizationStatus {
        case .denied:
            return .permissionDenied
        case .restricted:
            return .hardwareRestricted
        default:
            return isCameraAvailable ? nil : .hardwareUnavailable
        }
    }
}

// Enhanced error handling
enum CameraError: LocalizedError {
    case permissionDenied
    case hardwareUnavailable
    case hardwareRestricted
    case captureFailure
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera Access Required"
        case .hardwareUnavailable:
            return "Camera Not Available"
        case .hardwareRestricted:
            return "Camera Access Restricted"
        case .captureFailure:
            return "Photo Capture Failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Grant camera access in Settings to take photos"
        case .hardwareUnavailable:
            return "Use Photo Library to select existing photos"
        case .hardwareRestricted:
            return "Camera access is restricted on this device"
        case .captureFailure:
            return "Try taking the photo again"
        }
    }
}
```

### Phase 3: UI Integration (30 minutes)

#### Step 3.1: Update AddItemView with Modern State Management

Modify `/Cubby/Views/Items/AddItemView.swift`:

1. **Add improved state management** (after existing @State properties):
```swift
// Better state management with enum
enum PhotoSourceState {
    case idle
    case showingCamera
    case showingLibrary
    case processingImage(UIImage)
}

@State private var photoSourceState = PhotoSourceState.idle
@StateObject private var cameraService = CameraService.shared
```

2. **Replace the Photo section** with enhanced UI and accessibility:
```swift
Section("Photo") {
    if let selectedImage {
        Image(uiImage: selectedImage)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Selected photo")
        
        Button("Remove Photo", role: .destructive) {
            self.selectedImage = nil
            self.selectedPhotoItem = nil
            photoSourceState = .idle
        }
        .accessibilityLabel("Remove selected photo")
    } else {
        HStack(spacing: 12) {
            // Camera Button - UIImagePickerController is the correct approach
            if cameraService.isCameraAvailable {
                Button(action: {
                    Task {
                        let granted = await cameraService.requestCameraPermission()
                        if granted {
                            photoSourceState = .showingCamera
                        }
                    }
                }) {
                    Label("Camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Take a photo")
                .accessibilityHint("Opens the camera to capture a photo of your item")
            }
            
            // Photo Library Button - PhotosPicker is library-only
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Choose from library")
            .accessibilityHint("Opens your photo library to select an existing photo")
        }
        
        // Error handling with recovery suggestions
        if let error = cameraService.error {
            VStack(spacing: 4) {
                Text(error.errorDescription ?? "Camera unavailable")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .onTapGesture {
                if error == .permissionDenied,
                   let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}
```

3. **Add camera sheet with state handling** (after existing .sheet modifiers):
```swift
.sheet(item: Binding(
    get: {
        switch photoSourceState {
        case .showingCamera: return PhotoSource.camera
        case .showingLibrary: return PhotoSource.library
        default: return nil
        }
    },
    set: { _ in photoSourceState = .idle }
)) { source in
    ImagePicker(image: $selectedImage, sourceType: source == .camera ? .camera : .photoLibrary)
        .ignoresSafeArea()
        .onDisappear {
            if let image = selectedImage {
                photoSourceState = .processingImage(image)
            } else {
                photoSourceState = .idle
            }
        }
}

// Add this enum near the top of the file
enum PhotoSource: String, Identifiable {
    case camera
    case library
    var id: String { rawValue }
}
```

#### Step 3.2: Update ItemDetailView (Optional)

Similar changes to `/Cubby/Views/Items/ItemDetailView.swift` for editing photos.

### Phase 4: Testing (30 minutes)

#### Step 4.1: Simulator Testing

1. **Build and run on simulator**:
```bash
xcodebuild -project Cubby.xcodeproj -scheme Cubby \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  clean build
```

2. **Verify**:
- [ ] Camera button is hidden on simulator
- [ ] Photo library button still works
- [ ] No crashes when accessing photo section

#### Step 4.2: Device Testing

1. **Connect physical iOS device**
2. **Select device as run destination in Xcode**
3. **Build and run**

4. **Test Permission Flow**:
   - [ ] First launch: Permission prompt appears
   - [ ] Grant permission: Camera opens
   - [ ] Deny permission: Settings prompt appears
   - [ ] Settings redirect works

5. **Test Camera Functionality**:
   - [ ] Camera opens when button tapped
   - [ ] Photo captures correctly
   - [ ] Photo appears in preview
   - [ ] Cancel returns without photo
   - [ ] Photo saves with item

#### Step 4.3: Edge Cases

Test these scenarios:
- [ ] Device rotation during camera use
- [ ] Low memory warning during capture
- [ ] Background/foreground transitions
- [ ] Multiple photos in succession
- [ ] Very large photos (test compression)

### Phase 5: Code Review Checklist

Before submitting PR, verify:

#### Code Quality
- [ ] No force unwrapping of optionals
- [ ] Proper error handling
- [ ] Memory management (no retain cycles)
- [ ] Debug logging added for troubleshooting

#### UI/UX
- [ ] Buttons have appropriate labels
- [ ] Loading states handled
- [ ] Error messages are user-friendly
- [ ] Accessibility labels set

#### Permissions
- [ ] Info.plist description is clear
- [ ] Permission denied handled gracefully
- [ ] Settings redirect works

#### Testing
- [ ] Works on simulator (library only)
- [ ] Works on real device (both options)
- [ ] No crashes in any scenario
- [ ] Photos save correctly

### Phase 6: Documentation

#### Step 6.1: Update CLAUDE.md

Add to `/Cubby/CLAUDE.md`:

```markdown
### Camera Integration
- Uses UIImagePickerController via UIViewControllerRepresentable
- Camera permission required (NSCameraUsageDescription)
- Gracefully degrades on devices without cameras
- See `/docs/camera-feature/` for implementation details
```

#### Step 6.2: Update README if needed

Add to features list if public-facing.

### Common Issues & Solutions

#### Issue 1: Camera doesn't appear on device
**Solution**: 
- Check Info.plist has NSCameraUsageDescription
- Verify PrivacyInfo.xcprivacy is included in the build

#### Issue 2: "CameraPicker not found" error
**Solution**: CameraPicker doesn't exist. Use UIImagePickerController wrapped in UIViewControllerRepresentable.

#### Issue 3: PhotosPicker doesn't show camera option
**Solution**: PhotosPicker is library-only. You need a separate camera button with UIImagePickerController.

#### Issue 4: Photo orientation incorrect
**Solution**: The fixedOrientation() extension is already included in ImagePicker.swift

#### Issue 5: Memory warning with large photos
**Solution**: Compress before saving:
```swift
let compressed = image.jpegData(compressionQuality: 0.7)
```

#### Issue 6: App Store submission rejected for privacy
**Solution**: Ensure PrivacyInfo.xcprivacy is included with proper API usage reasons

### Git Workflow

#### Creating the PR

1. **Stage changes**:
```bash
git add .
git status  # Verify correct files
```

2. **Commit**:
```bash
git commit -m "feat: Add camera capture for item photos

- Add UIImagePickerController wrapper
- Implement dual button interface (camera + library)
- Handle permissions gracefully
- Add camera service for availability checking"
```

3. **Push branch**:
```bash
git push origin feat/camera-capture
```

4. **Create PR**:
```bash
gh pr create --title "Add camera capture for item photos" \
  --body "Implements direct camera access in item creation flow"
```

### Performance Considerations

1. **Image Compression**:
   - Always compress to 70% JPEG before saving
   - Consider implementing progressive loading for large images

2. **Memory Management**:
   - Release image data after save
   - Use autoreleasepool for batch operations

3. **Async Operations**:
   - Keep photo processing off main thread
   - Show progress indicators during save

### Security Notes

1. **Privacy**:
   - Strip EXIF data before storage
   - Don't store location data
   - Clear image cache on app termination

2. **Permissions**:
   - Only request when user initiates
   - Provide clear explanation
   - Handle denial gracefully

## Important Technical Notes

### Verified API Information
1. **UIImagePickerController is correct**: There is no native SwiftUI camera API
2. **PhotosPicker is library-only**: It cannot directly access the camera
3. **Dual-button approach is best**: Separate buttons for camera and library provide the clearest UX
4. **Privacy Manifest is required**: iOS 17+ requires PrivacyInfo.xcprivacy for App Store distribution

## Next Steps

After implementation:

1. **User Testing**: Get feedback on UX flow
2. **Performance Testing**: Profile with Instruments
3. **Accessibility Testing**: Verify VoiceOver support
4. **Privacy Compliance**: Test with Privacy Report in Xcode

## Support

For questions during implementation:
- Check `/docs/camera-feature/tech-spec.md` for technical details
- Review Apple's Camera guidelines
- Test on multiple device types

---

**Guide Version**: 2.0  
**Last Updated**: 2024-12-29  
**Estimated Time**: 2-3 hours  
**Difficulty**: Intermediate  
**Note**: Updated with verified Apple documentation and corrected API information