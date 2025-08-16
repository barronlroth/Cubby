//
//  DataCleanupService.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import Foundation
import SwiftData

class DataCleanupService {
    static let shared = DataCleanupService()
    
    func performCleanup(modelContext: ModelContext) async {
        await cleanupOrphanedPhotos(modelContext: modelContext)
    }
    
    private func cleanupOrphanedPhotos(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<InventoryItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return }
        
        let activePhotoNames = Set(items.compactMap { $0.photoFileName })
        
        let photosURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ItemPhotos")
        
        guard let photoFiles = try? FileManager.default.contentsOfDirectory(at: photosURL, includingPropertiesForKeys: nil) else { return }
        
        for photoURL in photoFiles {
            let fileName = photoURL.lastPathComponent
            if !activePhotoNames.contains(fileName) {
                try? FileManager.default.removeItem(at: photoURL)
            }
        }
    }
}