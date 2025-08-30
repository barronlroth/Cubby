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