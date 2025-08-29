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

#### Step 1.3: Verify Project Settings
1. Open `Cubby.xcodeproj`
2. Select the Cubby target
3. Go to Info tab
4. Verify "Privacy - Camera Usage Description" appears

### Phase 2: Core Components (45 minutes)

#### Step 2.1: Create ImagePicker Component

Create new file: `/Cubby/Views/Components/ImagePicker.swift`

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
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

#### Step 2.2: Create Camera Service

Create new file: `/Cubby/Services/CameraService.swift`

```swift
import SwiftUI
import AVFoundation
import UIKit

@MainActor
class CameraService: ObservableObject {
    static let shared = CameraService()
    
    @Published var isCameraAvailable: Bool = false
    @Published var cameraAuthorizationStatus: AVAuthorizationStatus
    
    private init() {
        self.cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        self.isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        
        DebugLogger.info("CameraService initialized - Available: \(isCameraAvailable)")
    }
    
    func requestCameraPermission() async -> Bool {
        switch cameraAuthorizationStatus {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorizationStatus = granted ? .authorized : .denied
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
    
    var permissionMessage: String? {
        switch cameraAuthorizationStatus {
        case .denied:
            return "Camera access is required to take photos. Please enable it in Settings."
        case .restricted:
            return "Camera access is restricted on this device."
        default:
            return nil
        }
    }
}
```

### Phase 3: UI Integration (30 minutes)

#### Step 3.1: Update AddItemView

Modify `/Cubby/Views/Items/AddItemView.swift`:

1. **Add new state variables** (after existing @State properties):
```swift
@State private var showingCamera = false
@StateObject private var cameraService = CameraService.shared
```

2. **Replace the Photo section** with:
```swift
Section("Photo") {
    if let selectedImage {
        Image(uiImage: selectedImage)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        
        Button("Remove Photo", role: .destructive) {
            self.selectedImage = nil
            self.selectedPhotoItem = nil
        }
    } else {
        HStack(spacing: 12) {
            // Camera Button
            if cameraService.isCameraAvailable {
                Button(action: {
                    Task {
                        let granted = await cameraService.requestCameraPermission()
                        if granted {
                            showingCamera = true
                        }
                    }
                }) {
                    Label("Camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            // Photo Library Button
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        
        // Permission message if needed
        if let message = cameraService.permissionMessage {
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .onTapGesture {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
        }
    }
}
```

3. **Add camera sheet** (after existing .sheet modifiers):
```swift
.sheet(isPresented: $showingCamera) {
    ImagePicker(image: $selectedImage, sourceType: .camera)
        .ignoresSafeArea()
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
**Solution**: Check Info.plist has NSCameraUsageDescription

#### Issue 2: Crash when opening camera
**Solution**: Ensure permission is granted before presenting

#### Issue 3: Photo orientation incorrect
**Solution**: Use UIImage orientation fix:
```swift
extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        // Implementation to fix orientation
    }
}
```

#### Issue 4: Memory warning with large photos
**Solution**: Compress before saving:
```swift
let compressed = image.jpegData(compressionQuality: 0.7)
```

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

## Next Steps

After implementation:

1. **User Testing**: Get feedback on UX flow
2. **Performance Testing**: Profile with Instruments
3. **A/B Testing**: Compare camera vs library usage
4. **Enhancements**: Consider adding filters, editing tools

## Support

For questions during implementation:
- Check `/docs/camera-feature/tech-spec.md` for technical details
- Review Apple's Camera guidelines
- Test on multiple device types

---

**Guide Version**: 1.0  
**Last Updated**: 2024-12-29  
**Estimated Time**: 2-3 hours  
**Difficulty**: Intermediate