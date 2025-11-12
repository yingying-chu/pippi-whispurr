//
//  PhotoGridView.swift
//  PippiWhispurr
//
//  Grid view showing photos for a specific date
//

import SwiftUI
import Photos

struct PhotoGridView: View {
    @EnvironmentObject var photoManager: PhotoManager
    let date: Date

    private var photos: [PetPhoto] {
        photoManager.photosForDate(date)
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedDate)
                            .font(.headline)

                        Text("\(photos.count) pet photo\(photos.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(photos) { photo in
                        NavigationLink(destination: PhotoDetailView(photo: photo)) {
                            PhotoThumbnailView(photo: photo)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

struct PhotoThumbnailView: View {
    let photo: PetPhoto
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                        )
                }

                // Pet type badge
                Text(photo.petType.emoji)
                    .font(.caption)
                    .padding(6)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(6)
                    .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        // Use PhotoManager's method to load a smaller version
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        let manager = PHImageManager.default()
        let targetSize = CGSize(width: 300, height: 300)

        image = await withCheckedContinuation { continuation in
            manager.requestImage(
                for: photo.asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                continuation.resume(returning: result)
            }
        }
    }
}
