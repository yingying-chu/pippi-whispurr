//
//  PhotoDetailView.swift
//  PippiWhispurr
//
//  Detailed view of a single pet photo
//

import SwiftUI
import Photos

struct PhotoDetailView: View {
    @EnvironmentObject var photoManager: PhotoManager
    let photo: PetPhoto
    @State private var image: UIImage?
    @Environment(\.dismiss) var dismiss

    private var isFavorite: Bool { photoManager.isFavorite(photo) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(photo.petType.emoji)
                            .font(.title)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(photo.petType.rawValue)
                                .font(.headline)
                                .foregroundColor(.white)

                            Text(formattedDate)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()

                        Button(action: { photoManager.toggleFavorite(photo) }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(isFavorite ? .red : .white)
                                .padding(8)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))

                            Text("\(Int(photo.confidence * 100))%")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }

                    if photo.asset.location != nil {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.white.opacity(0.6))
                            Text("Location available")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { photoManager.toggleFavorite(photo) }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .primary)
                }
            }
        }
        .task {
            image = await photoManager.loadFullImage(for: photo.asset)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: photo.date)
    }
}
