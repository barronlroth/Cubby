//
//  PhotoService.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import Foundation
import UIKit

protocol PhotoServiceProtocol {
    func savePhoto(_ image: UIImage) async throws -> String
    func loadPhoto(fileName: String) async -> UIImage?
    func deletePhoto(fileName: String) async
    func clearCache()
}

class PhotoService: PhotoServiceProtocol {
    static let shared = PhotoService()
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let photosDirectory: URL
    
    private let imageCache = NSCache<NSString, UIImage>()
    private let maxCacheSize = 50 * 1024 * 1024
    
    init() {
        photosDirectory = documentsDirectory.appendingPathComponent("ItemPhotos")
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        
        imageCache.totalCostLimit = maxCacheSize
        imageCache.countLimit = 100
    }
    
    func savePhoto(_ image: UIImage) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw PhotoError.compressionFailed
        }
        
        try await Task.detached(priority: .background) {
            try data.write(to: fileURL)
        }.value
        
        imageCache.setObject(image, forKey: fileName as NSString, cost: data.count)
        
        return fileName
    }
    
    func loadPhoto(fileName: String) async -> UIImage? {
        if let cachedImage = imageCache.object(forKey: fileName as NSString) {
            return cachedImage
        }
        
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        
        return await Task.detached(priority: .background) {
            guard let data = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: data) else { return nil }
            
            self.imageCache.setObject(image, forKey: fileName as NSString, cost: data.count)
            return image
        }.value
    }
    
    func deletePhoto(fileName: String) async {
        imageCache.removeObject(forKey: fileName as NSString)
        
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func clearCache() {
        imageCache.removeAllObjects()
    }
}

enum PhotoError: Error {
    case compressionFailed
    case saveFailed
}