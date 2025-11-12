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

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }

                // Photo info
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

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))

                            Text("\(Int(photo.confidence * 100))%")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }

                    if let location = photo.asset.location {
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
        .task {
            await loadFullImage()
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: photo.date)
    }

    private func loadFullImage() async {
        image = await photoManager.loadFullImage(for: photo.asset)
    }
}
