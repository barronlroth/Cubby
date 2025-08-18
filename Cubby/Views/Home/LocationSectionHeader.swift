import SwiftUI

struct LocationSectionHeader: View {
    let locationPath: String
    let itemCount: Int
    
    var body: some View {
        HStack {
            Text(locationPath)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text("\(itemCount) \(itemCount == 1 ? "item" : "items")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color(UIColor.systemGroupedBackground))
    }
}