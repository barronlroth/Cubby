import Foundation
import SwiftData

enum ValidationResult {
    case success
    case failure(String)
}

struct ValidationHelpers {
    
    static func validateLocationName(_ name: String, in parent: StorageLocation?, home: Home) -> ValidationResult {
        // Check empty
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return .failure("Location name cannot be empty")
        }
        
        // Check length
        guard trimmedName.count <= 100 else {
            return .failure("Location name must be less than 100 characters")
        }
        
        // Check duplicates at same level
        let siblings: [StorageLocation]
        if let parent = parent {
            siblings = parent.childLocations ?? []
        } else {
            siblings = home.storageLocations?.filter { $0.parentLocation == nil } ?? []
        }
        
        let isDuplicate = siblings.contains { 
            $0.name.lowercased() == trimmedName.lowercased() 
        }
        
        if isDuplicate {
            return .failure("A location with this name already exists at this level")
        }
        
        return .success
    }
    
    static func validateNestingDepth(_ parent: StorageLocation?) -> Bool {
        guard let parent = parent else { return true }
        return parent.depth < StorageLocation.maxNestingDepth - 1
    }
    
    static func validateItemTitle(_ title: String) -> ValidationResult {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            return .failure("Item title cannot be empty")
        }
        
        guard trimmedTitle.count <= 200 else {
            return .failure("Item title must be less than 200 characters")
        }
        
        return .success
    }
    
    static func validateItemDescription(_ description: String?) -> ValidationResult {
        guard let description = description else { return .success }
        
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedDescription.count <= 1000 else {
            return .failure("Description must be less than 1000 characters")
        }
        
        return .success
    }
    
    static func validatePhotoSize(_ imageData: Data) -> ValidationResult {
        let maxSize = 10 * 1024 * 1024 // 10MB
        
        guard imageData.count <= maxSize else {
            let sizeInMB = Double(imageData.count) / (1024 * 1024)
            return .failure(String(format: "Photo size (%.1fMB) exceeds maximum of 10MB", sizeInMB))
        }
        
        return .success
    }
    
    static func validateHomeName(_ name: String) -> ValidationResult {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            return .failure("Home name cannot be empty")
        }
        
        guard trimmedName.count <= 50 else {
            return .failure("Home name must be less than 50 characters")
        }
        
        return .success
    }
}