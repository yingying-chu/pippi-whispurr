//
//  PhotoManager.swift
//  PippiWhispurr
//
//  Manages photo library access and pet photo scanning
//

import Foundation
import Photos
import UIKit
import Combine

@MainActor
class PhotoManager: ObservableObject {
    @Published var petPhotos: [PetPhoto] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var photosByDate: [Date: [PetPhoto]] = [:]
    @Published var filteredPhotosByDate: [Date: [PetPhoto]] = [:]
    @Published var totalPhotosToScan: Int = 0
    @Published var scannedPhotosCount: Int = 0
    @Published var scanBatchSize = 1000
    @Published var lastBatchHadNoPhotos = false
    @Published var activeFilter: PetPhoto.PetType? = nil
    @Published var showsFavoritesOnly = false
    @Published var favoriteIDs: Set<String> = []

    private let petDetector = PetDetector()
    private let storyStore: StoryStore
    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?

    private let batchSize = 20

    var analyzedPhotosCount: Int {
        storyStore.scanHistory.analyzedPhotoIdentifiers.count
    }

    var lastCompletedScanDate: Date? {
        storyStore.scanHistory.lastCompletedAt
    }

    convenience init() {
        self.init(storyStore: StoryStore())
    }

    init(storyStore: StoryStore) {
        self.storyStore = storyStore
        checkAuthorizationStatus()
        let persistedFavorites = Set(
            storyStore.photos
                .filter(\.isFavorite)
                .map(\.assetIdentifier)
        )
        let legacyFavorites = Set(
            UserDefaults.standard.stringArray(forKey: "favoritePhotoIDs") ?? []
        )
        favoriteIDs = persistedFavorites.union(legacyFavorites)

        if authorizationStatus == .authorized || authorizationStatus == .limited {
            restorePersistedPhotos()
        }
    }

    func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        if status == .authorized || status == .limited {
            restorePersistedPhotos()
        }
    }

    func scanPhotoLibrary() async {
        if authorizationStatus != .authorized && authorizationStatus != .limited {
            await requestAuthorization()
            guard authorizationStatus == .authorized || authorizationStatus == .limited else {
                return
            }
        }

        // Cancel any existing scan
        scanTask?.cancel()

        scanTask = Task {
            isScanning = true
            scanProgress = 0.0
            scannedPhotosCount = 0
            lastBatchHadNoPhotos = false
            var detectedPhotos: [PetPhoto] = []
            var allVisiblePhotos = Dictionary(
                uniqueKeysWithValues: petPhotos.map { ($0.id, $0) }
            )

            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            let alreadyAnalyzed = storyStore.scanHistory.analyzedPhotoIdentifiers
                .union(storyStore.photos.map(\.assetIdentifier))
            var photosForThisBatch: [PHAsset] = []
            photosForThisBatch.reserveCapacity(scanBatchSize)

            for index in 0..<allPhotos.count {
                let asset = allPhotos.object(at: index)
                guard !alreadyAnalyzed.contains(asset.localIdentifier) else { continue }
                photosForThisBatch.append(asset)
                if photosForThisBatch.count == scanBatchSize { break }
            }

            let totalCount = photosForThisBatch.count
            totalPhotosToScan = totalCount

            guard totalCount > 0 else {
                lastBatchHadNoPhotos = true
                scanProgress = 1.0
                isScanning = false
                return
            }

            var processedCount = 0

            // Process in batches to manage memory
            for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
                // Check for cancellation
                if Task.isCancelled {
                    break
                }

                let batchEnd = min(batchStart + batchSize, totalCount)
                var analyzedIdentifiers: [String] = []

                // Process batch
                for index in batchStart..<batchEnd {
                    if Task.isCancelled {
                        break
                    }

                    let asset = photosForThisBatch[index]

                    if let result = await analyzeAsset(asset) {
                        detectedPhotos.append(result)
                        allVisiblePhotos[result.id] = result
                    }
                    analyzedIdentifiers.append(asset.localIdentifier)

                    processedCount += 1
                    scannedPhotosCount = processedCount
                    scanProgress = Double(processedCount) / Double(totalCount)
                }

                // Update UI after each batch
                let records = detectedPhotos.map {
                    PhotoRecord($0, isFavorite: favoriteIDs.contains($0.id))
                }
                storyStore.upsertPhotos(records)
                storyStore.markPhotosAnalyzed(analyzedIdentifiers)
                detectedPhotos.removeAll(keepingCapacity: true)

                petPhotos = allVisiblePhotos.values.sorted { $0.date > $1.date }
                updatePhotosByDate(petPhotos)

                // Small delay between batches to prevent memory spikes
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }

            if !Task.isCancelled {
                if !detectedPhotos.isEmpty {
                    let records = detectedPhotos.map {
                        PhotoRecord($0, isFavorite: favoriteIDs.contains($0.id))
                    }
                    storyStore.upsertPhotos(records)
                }
                petPhotos = allVisiblePhotos.values.sorted { $0.date > $1.date }
                updatePhotosByDate(petPhotos)
                scanProgress = 1.0
                storyStore.completeScanBatch()
            }

            isScanning = false
        }

        await scanTask?.value
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
    }

    private func analyzeAsset(_ asset: PHAsset) async -> PetPhoto? {
        guard let image = await loadImage(for: asset) else {
            return nil
        }

        let detection = await petDetector.detectPet(in: image)

        guard let petType = detection.petType, detection.confidence > 0.6 else {
            return nil
        }

        return PetPhoto(
            id: asset.localIdentifier,
            asset: asset,
            date: asset.creationDate ?? Date(),
            confidence: detection.confidence,
            petType: petType
        )
    }

    private func loadImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            var hasResumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                // Only resume once - PHImageManager can call this multiple times
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func loadFullImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            var hasResumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                // Only resume once - PHImageManager can call this multiple times
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    private func updatePhotosByDate(_ photos: [PetPhoto]) {
        let calendar = Calendar.current
        var grouped: [Date: [PetPhoto]] = [:]

        for photo in photos {
            let startOfDay = calendar.startOfDay(for: photo.date)
            grouped[startOfDay, default: []].append(photo)
        }

        photosByDate = grouped
        applyFilter()
    }

    func photosForDate(_ date: Date) -> [PetPhoto] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return filteredPhotosByDate[startOfDay] ?? []
    }

    func setFilter(_ filter: PetPhoto.PetType?) {
        activeFilter = filter
        showsFavoritesOnly = false
        applyFilter()
    }

    func showFavorites() {
        activeFilter = nil
        showsFavoritesOnly = true
        applyFilter()
    }

    private func applyFilter() {
        let filtered: [PetPhoto]
        if showsFavoritesOnly {
            filtered = petPhotos.filter { favoriteIDs.contains($0.id) }
        } else if let filter = activeFilter {
            filtered = petPhotos.filter { $0.petType == filter }
        } else {
            filtered = petPhotos
        }
        updateFilteredPhotosByDate(filtered)
    }

    private func updateFilteredPhotosByDate(_ photos: [PetPhoto]) {
        let calendar = Calendar.current
        var grouped: [Date: [PetPhoto]] = [:]
        for photo in photos {
            let startOfDay = calendar.startOfDay(for: photo.date)
            grouped[startOfDay, default: []].append(photo)
        }
        filteredPhotosByDate = grouped
    }

    func toggleFavorite(_ photo: PetPhoto) {
        if favoriteIDs.contains(photo.id) {
            favoriteIDs.remove(photo.id)
            storyStore.setFavorite(photoID: photo.id, isFavorite: false)
        } else {
            favoriteIDs.insert(photo.id)
            storyStore.setFavorite(photoID: photo.id, isFavorite: true)
        }
        applyFilter()
    }

    func isFavorite(_ photo: PetPhoto) -> Bool {
        favoriteIDs.contains(photo.id)
    }

    var favoritePhotos: [PetPhoto] {
        petPhotos.filter { favoriteIDs.contains($0.id) }
    }

    var filteredPetPhotos: [PetPhoto] {
        if showsFavoritesOnly {
            return petPhotos.filter { favoriteIDs.contains($0.id) }
        }
        if let activeFilter {
            return petPhotos.filter { $0.petType == activeFilter }
        }
        return petPhotos
    }

    private func restorePersistedPhotos() {
        let records = storyStore.photos
        guard !records.isEmpty else { return }

        let assets = PHAsset.fetchAssets(
            withLocalIdentifiers: records.map(\.assetIdentifier),
            options: nil
        )
        var assetsByID: [String: PHAsset] = [:]
        assets.enumerateObjects { asset, _, _ in
            assetsByID[asset.localIdentifier] = asset
        }

        petPhotos = records.compactMap { record in
            guard let asset = assetsByID[record.assetIdentifier] else { return nil }
            return PetPhoto(
                id: record.assetIdentifier,
                asset: asset,
                date: record.captureDate,
                confidence: record.detectionConfidence,
                petType: record.detectedPetType
            )
        }
        favoriteIDs = Set(records.filter(\.isFavorite).map(\.assetIdentifier))
        updatePhotosByDate(petPhotos)
    }
}

private extension PhotoRecord {
    init(_ photo: PetPhoto, isFavorite: Bool) {
        self.init(
            assetIdentifier: photo.id,
            captureDate: photo.date,
            detectedPetType: photo.petType,
            detectionConfidence: photo.confidence,
            isFavorite: isFavorite
        )
    }
}
