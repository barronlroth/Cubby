//
//  ValidationHelpers.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import Foundation

enum ValidationResult {
    case success
    case failure(String)
}

struct ValidationHelpers {
    static func validateLocationName(_ name: String, in parent: StorageLocation?, home: Home) -> ValidationResult {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure("Location name cannot be empty")
        }
        
        let siblings = parent?.childLocations ?? home.storageLocations
        let isDuplicate = siblings?.contains { $0.name.lowercased() == name.lowercased() } ?? false
        
        if isDuplicate {
            return .failure("A location with this name already exists at this level")
        }
        
        return .success
    }
    
    static func validateNestingDepth(_ parent: StorageLocation?) -> Bool {
        guard let parent else { return true }
        return parent.depth < StorageLocation.maxNestingDepth - 1
    }
    
    static func validateItemTitle(_ title: String) -> ValidationResult {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure("Item title cannot be empty")
        }
        return .success
    }
    
    static func validateHomeName(_ name: String) -> ValidationResult {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure("Home name cannot be empty")
        }
        return .success
    }
}