import SwiftUI
import SwiftData

struct ItemRow: View {
    let item: InventoryItem
    let showLocation: Bool
    @State private var photo: UIImage?
    @State private var isLoadingPhoto = false
    
    init(item: InventoryItem, showLocation: Bool = true) {
        self.item = item
        self.showLocation = showLocation
    }
    
    var body: some View {
        NavigationLink(destination: ItemDetailView(item: item)) {
            HStack(spacing: 12) {
                if let photoFileName = item.photoFileName {
                    Group {
                        if let photo {
                            Image(uiImage: photo)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if isLoadingPhoto {
                            ProgressView()
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "shippingbox")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 60, height: 60)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let description = item.itemDescription, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    if showLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.caption2)
                            Text(item.storageLocation?.name ?? "Unknown")
                                .font(.caption)
                        }
                        .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .task {
            await loadPhoto()
        }
    }
    
    private func loadPhoto() async {
        guard let photoFileName = item.photoFileName else { return }
        
        isLoadingPhoto = true
        photo = await PhotoService.shared.loadPhoto(fileName: photoFileName)
        isLoadingPhoto = false
    }
}