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
    @EnvironmentObject private var storyStore: StoryStore
    private let initialPhoto: PetPhoto
    private let initialBrowsingPhotos: [PetPhoto]
    @State private var currentPhotoID: String
    @State private var browsingPhotos: [PetPhoto] = []
    @State private var showingPetAssignment = false
    @State private var showingLocationMap = false
    @State private var showingDeleteConfirmation = false
    @State private var deletionError: String?
    @Environment(\.dismiss) var dismiss

    init(photo: PetPhoto, photos: [PetPhoto] = []) {
        initialPhoto = photo
        initialBrowsingPhotos = photos
        _currentPhotoID = State(initialValue: photo.id)
    }

    private var photo: PetPhoto {
        browsingPhotos.first { $0.id == currentPhotoID } ?? initialPhoto
    }

    private var isFavorite: Bool { photoManager.isFavorite(photo) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                TabView(selection: $currentPhotoID) {
                    ForEach(Array(pagePhotos.enumerated()), id: \.element.id) { index, pagePhoto in
                        FullPhotoPage(
                            photo: pagePhoto,
                            shouldLoad: abs(index - (currentPhotoIndex ?? 0)) <= 1
                        )
                            .tag(pagePhoto.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .overlay(alignment: .bottom) {
                    if pagePhotos.count > 1 {
                        HStack(spacing: 12) {
                            Button(action: showPreviousPhoto) {
                                Image(systemName: "chevron.left")
                            }
                            .disabled(!hasPreviousPhoto)

                            Label("Swipe for more", systemImage: "hand.draw")
                                .font(.caption.weight(.semibold))

                            Text(photoPositionText)
                                .font(.caption.monospacedDigit().weight(.semibold))

                            Button(action: showNextPhoto) {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(!hasNextPhoto)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.black.opacity(0.68))
                        .clipShape(Capsule())
                        .padding(.bottom, 12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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

                    if let coordinate = photo.asset?.location?.coordinate {
                        PhotoLocationCard(coordinate: coordinate) {
                            showingLocationMap = true
                        }
                    }

                    Button {
                        showingPetAssignment = true
                    } label: {
                        HStack {
                            Image(systemName: "pawprint.fill")
                            Text(assignedPetsText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { photoManager.toggleFavorite(photo) }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .primary)
                }
                .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")

                Menu {
                    Section("Correct recognition") {
                        Button("Mark as Cat") { correctType(.cat) }
                        Button("Mark as Dog") { correctType(.dog) }
                    }

                    Button("Remove from PiPi", role: .destructive) {
                        removeCurrentPhotoFromPiPi()
                    }

                    Button("Delete from iPhone Photos", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            guard browsingPhotos.isEmpty else { return }
            if initialBrowsingPhotos.contains(where: { $0.id == initialPhoto.id }) {
                browsingPhotos = initialBrowsingPhotos
                return
            }
            let filtered = photoManager.filteredPetPhotos
            browsingPhotos = filtered.contains(where: { $0.id == initialPhoto.id })
                ? filtered
                : photoManager.petPhotos
        }
        .sheet(isPresented: $showingPetAssignment) {
            PhotoAssignmentView(
                photo: photo,
                assignedPetIDs: assignedPetIDs
            )
        }
        .sheet(isPresented: $showingLocationMap) {
            PhotoLocationFullMap(photo: photo)
        }
        .alert("Delete this photo from iPhone Photos?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Photo", role: .destructive) {
                deleteCurrentPhotoFromLibrary()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("iOS will ask you to confirm this change. The photo will also disappear from PiPi.")
        }
        .alert(
            "Photo Could Not Be Deleted",
            isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionError ?? "Please try again.")
        }
    }

    private var assignedPetIDs: Set<UUID> {
        storyStore.photos
            .first { $0.assetIdentifier == photo.id }?
            .assignedPetIDs ?? []
    }

    private var assignedPetsText: String {
        let names = storyStore.pets
            .filter { assignedPetIDs.contains($0.id) }
            .map(\.name)
        return names.isEmpty ? "Assign to a pet" : names.joined(separator: ", ")
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: photo.date)
    }

    private var photoPositionText: String {
        guard let index = browsingPhotos.firstIndex(where: { $0.id == photo.id }) else {
            return ""
        }
        return "\(index + 1) / \(browsingPhotos.count)"
    }

    private var pagePhotos: [PetPhoto] {
        browsingPhotos.isEmpty ? [initialPhoto] : browsingPhotos
    }

    private var currentPhotoIndex: Int? {
        pagePhotos.firstIndex(where: { $0.id == currentPhotoID })
    }

    private var hasPreviousPhoto: Bool {
        (currentPhotoIndex ?? 0) > 0
    }

    private var hasNextPhoto: Bool {
        guard let currentPhotoIndex else { return false }
        return currentPhotoIndex < pagePhotos.count - 1
    }

    private func showPreviousPhoto() {
        guard let currentPhotoIndex, currentPhotoIndex > 0 else { return }
        withAnimation { currentPhotoID = pagePhotos[currentPhotoIndex - 1].id }
    }

    private func showNextPhoto() {
        guard let currentPhotoIndex, currentPhotoIndex < pagePhotos.count - 1 else { return }
        withAnimation { currentPhotoID = pagePhotos[currentPhotoIndex + 1].id }
    }

    private func correctType(_ petType: PetPhoto.PetType) {
        photoManager.correctPetType(photo, to: petType)
        if let index = browsingPhotos.firstIndex(where: { $0.id == photo.id }) {
            browsingPhotos[index].petType = petType
        }
    }

    private func removeCurrentPhotoFromPiPi() {
        let photoToRemove = photo
        moveAwayFromCurrentPhoto()
        photoManager.removeFromPiPi(photoToRemove)
    }

    private func deleteCurrentPhotoFromLibrary() {
        let photoToDelete = photo
        Task {
            do {
                try await photoManager.deleteFromPhotoLibrary(photoToDelete)
                moveAwayFromCurrentPhoto(removing: photoToDelete.id)
            } catch {
                deletionError = error.localizedDescription
            }
        }
    }

    private func moveAwayFromCurrentPhoto(removing identifier: String? = nil) {
        let removedID = identifier ?? photo.id
        guard let index = browsingPhotos.firstIndex(where: { $0.id == removedID }) else {
            dismiss()
            return
        }

        browsingPhotos.remove(at: index)
        guard !browsingPhotos.isEmpty else {
            dismiss()
            return
        }
        currentPhotoID = browsingPhotos[min(index, browsingPhotos.count - 1)].id
    }
}

private struct FullPhotoPage: View {
    @EnvironmentObject private var photoManager: PhotoManager
    let photo: PetPhoto
    let shouldLoad: Bool
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: "\(photo.id)-\(shouldLoad)") {
            guard shouldLoad else {
                image = nil
                return
            }
            image = await photoManager.loadFullImage(for: photo)
        }
    }
}
