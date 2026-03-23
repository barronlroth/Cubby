import Foundation
import CoreData

class DataCleanupService {
    static let shared = DataCleanupService()
    
    func performCleanup(persistenceController: PersistenceController) async {
        await cleanupOrphanedPhotos(persistenceController: persistenceController)
    }
    
    private func cleanupOrphanedPhotos(persistenceController: PersistenceController) async {
        let request = NSFetchRequest<NSDictionary>(entityName: "CDInventoryItem")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["photoFileName"]

        guard let rows = try? persistenceController.persistentContainer.viewContext.fetch(request) else {
            return
        }

        let activePhotoNames = Set(
            rows.compactMap { $0["photoFileName"] as? String }
        )
        
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
