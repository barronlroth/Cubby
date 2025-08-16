//
//  ItemRow.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData

struct ItemRow: View {
    let item: InventoryItem
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        NavigationLink(destination: ItemDetailView(item: item)) {
            HStack(spacing: 12) {
                if let photoFileName = item.photoFileName {
                    Group {
                        if let image = thumbnailImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                                .clipped()
                        } else if isLoadingImage {
                            ProgressView()
                                .frame(width: 50, height: 50)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        } else {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .frame(width: 50, height: 50)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .task {
                        await loadThumbnail(photoFileName)
                    }
                } else {
                    Image(systemName: "cube.box")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(width: 50, height: 50)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let description = item.itemDescription, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if let location = item.storageLocation {
                        Text(location.fullPath)
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func loadThumbnail(_ fileName: String) async {
        isLoadingImage = true
        thumbnailImage = await PhotoService.shared.loadPhoto(fileName: fileName)
        isLoadingImage = false
    }
}