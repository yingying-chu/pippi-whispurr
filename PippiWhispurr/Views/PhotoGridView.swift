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
    var onScrollOffset: (CGFloat) -> Void = { _ in }

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
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: VerticalScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("datedPhotoGridScroll")).minY
                    )
                }
                .frame(height: 0)

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
                        NavigationLink(destination: PhotoDetailView(photo: photo, photos: photos)) {
                            PhotoThumbnailView(photo: photo)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .coordinateSpace(name: "datedPhotoGridScroll")
        .onPreferenceChange(VerticalScrollOffsetPreferenceKey.self) { offset in
            onScrollOffset(offset)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

struct PhotoThumbnailView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject private var storyStore: StoryStore
    let photo: PetPhoto
    @State private var image: UIImage?
    @State private var imageRequestID: PHImageRequestID?

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
                        .overlay(ProgressView())
                }

                VStack(alignment: .trailing, spacing: 4) {
                    if photoManager.isFavorite(photo) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(6)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(6)
                    }

                    if isAssigned {
                        Image(systemName: "pawprint.fill")
                            .font(.caption)
                            .foregroundColor(.forestInk)
                            .padding(6)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(6)
                    }

                }
                .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            requestThumbnail()
        }
        .onDisappear {
            if let imageRequestID {
                PHImageManager.default().cancelImageRequest(imageRequestID)
            }
        }
    }

    private var isAssigned: Bool {
        guard let record = storyStore.photos.first(where: { $0.assetIdentifier == photo.id }) else {
            return false
        }
        return !record.assignedPetIDs.isEmpty
    }

    private func requestThumbnail() {
        if photo.asset == nil {
            Task {
                let loaded = await photoManager.loadFullImage(for: photo)
                await MainActor.run { image = loaded }
            }
            return
        }
        if let imageRequestID {
            PHImageManager.default().cancelImageRequest(imageRequestID)
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        let manager = PHImageManager.default()
        let targetSize = CGSize(width: 600, height: 600)

        guard let asset = photo.asset else { return }
        imageRequestID = manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { result, info in
            guard let result else { return }
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            guard !isCancelled else { return }
            Task { @MainActor in
                image = result
            }
        }
    }
}
