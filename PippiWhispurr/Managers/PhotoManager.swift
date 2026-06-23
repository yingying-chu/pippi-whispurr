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
    private enum AssetAnalysisResult {
        case analyzed(PetPhoto?)
        case unavailable
    }

    @Published var petPhotos: [PetPhoto] = []
    @Published var isScanning = false
    @Published var isScanPaused = false
    @Published var scanProgress: Double = 0.0
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var photosByDate: [Date: [PetPhoto]] = [:]
    @Published var filteredPhotosByDate: [Date: [PetPhoto]] = [:]
    @Published var totalPhotosToScan: Int = 0
    @Published var scannedPhotosCount: Int = 0
    @Published var scanBatchSize = 1000
    @Published var libraryPhotoCount = 0
    @Published var remainingPhotoCount = 0
    @Published var estimatedSecondsRemaining: TimeInterval?
    @Published var lastBatchHadNoPhotos = false
    @Published var activeFilter: PetPhoto.PetType? = nil
    @Published var showsFavoritesOnly = false
    @Published var favoriteIDs: Set<String> = []

    private let petDetector = PetDetector()
    private let storyStore: StoryStore
    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?
    private var restoreTask: Task<Void, Never>?

    private let batchSize = 20
    private let currentSemanticAnalysisVersion = 2

    var analyzedPhotosCount: Int {
        storyStore.scanHistory.analyzedPhotoIdentifiers.count
    }

    var lastCompletedScanDate: Date? {
        storyStore.scanHistory.lastCompletedAt
    }

    var estimatedPhotosPerSecond: Double {
        storyStore.scanHistory.photosPerSecond ?? 50
    }

    var estimatedTotalSeconds: TimeInterval? {
        guard remainingPhotoCount > 0 else { return nil }
        return Double(remainingPhotoCount) / max(estimatedPhotosPerSecond, 1)
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

        storyStore.$photos
            .dropFirst()
            .sink { [weak self] records in
                guard let self else { return }
                self.favoriteIDs = Set(records.filter(\.isFavorite).map(\.assetIdentifier))
                if self.authorizationStatus == .authorized || self.authorizationStatus == .limited {
                    self.schedulePersistedPhotoRestore()
                    self.refreshLibrarySummary()
                }
            }
            .store(in: &cancellables)

        if authorizationStatus == .authorized || authorizationStatus == .limited {
            schedulePersistedPhotoRestore()
            refreshLibrarySummary()
        }
    }

    func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        if status == .authorized || status == .limited {
            schedulePersistedPhotoRestore()
            refreshLibrarySummary()
        }
    }

    func prepareScanSummary() async {
        if authorizationStatus != .authorized && authorizationStatus != .limited {
            await requestAuthorization()
        } else {
            refreshLibrarySummary()
        }
    }

    func scanAllRemainingPhotos() async {
        refreshLibrarySummary()
        scanBatchSize = max(remainingPhotoCount, 1)
        await scanPhotoLibrary()
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
            let scanStartedAt = Date()
            isScanPaused = false
            isScanning = true
            scanProgress = 0.0
            scannedPhotosCount = 0
            lastBatchHadNoPhotos = false
            estimatedSecondsRemaining = estimatedTotalSeconds
            var detectedPhotos: [PetPhoto] = []
            var allVisiblePhotos = Dictionary(
                uniqueKeysWithValues: petPhotos.map { ($0.id, $0) }
            )

            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            let needsSemanticUpgrade = Set(
                storyStore.photos
                    .filter { $0.semanticAnalysisVersion != currentSemanticAnalysisVersion }
                    .map(\.assetIdentifier)
            )
            let alreadyAnalyzed = storyStore.scanHistory.analyzedPhotoIdentifiers
                .union(storyStore.photos.map(\.assetIdentifier))
                .subtracting(needsSemanticUpgrade)
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
                isScanPaused = false
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

                    switch await analyzeAsset(asset) {
                    case .analyzed(let result):
                        analyzedIdentifiers.append(asset.localIdentifier)
                        if let result {
                            detectedPhotos.append(result)
                            allVisiblePhotos[result.id] = result
                        }
                    case .unavailable:
                        // Keep this asset eligible for a later scan. This is common
                        // when an iCloud photo cannot be downloaded right now.
                        break
                    }

                    processedCount += 1
                    scannedPhotosCount = processedCount
                    scanProgress = Double(processedCount) / Double(totalCount)
                    let elapsed = Date().timeIntervalSince(scanStartedAt)
                    if processedCount >= 20 && elapsed > 0 {
                        let currentRate = Double(processedCount) / elapsed
                        estimatedSecondsRemaining = Double(totalCount - processedCount) / max(currentRate, 1)
                    }
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
                let duration = Date().timeIntervalSince(scanStartedAt)
                storyStore.completeScanBatch(
                    photosProcessed: processedCount,
                    duration: duration
                )
                isScanPaused = false
            }

            isScanning = false
            estimatedSecondsRemaining = 0
            refreshLibrarySummary()
        }

        await scanTask?.value
    }

    func pauseScan() {
        guard isScanning else { return }
        isScanPaused = true
        scanTask?.cancel()
    }

    private func analyzeAsset(_ asset: PHAsset) async -> AssetAnalysisResult {
        guard let image = await loadImage(for: asset) else {
            return .unavailable
        }

        let detection = await petDetector.detectPet(in: image)

        guard let petType = detection.petType, detection.confidence > 0.6 else {
            return .analyzed(nil)
        }

        return .analyzed(PetPhoto(
            id: asset.localIdentifier,
            asset: asset,
            date: asset.creationDate ?? Date(),
            confidence: detection.confidence,
            petType: petType,
            semanticLabels: detection.semanticLabels
        ))
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
            ) { image, info in
                guard !hasResumed else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil
                guard !isDegraded || isCancelled || hasError else { return }
                hasResumed = true
                continuation.resume(returning: image)
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
            ) { image, info in
                guard !hasResumed else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil
                guard !isDegraded || isCancelled || hasError else { return }
                hasResumed = true
                continuation.resume(returning: image)
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

    func correctPetType(_ photo: PetPhoto, to petType: PetPhoto.PetType) {
        guard let index = petPhotos.firstIndex(where: { $0.id == photo.id }) else { return }
        petPhotos[index].petType = petType
        storyStore.setDetectedPetType(photoID: photo.id, petType: petType)
        updatePhotosByDate(petPhotos)
    }

    func removeFromPiPi(_ photo: PetPhoto) {
        petPhotos.removeAll { $0.id == photo.id }
        favoriteIDs.remove(photo.id)
        storyStore.removePhoto(id: photo.id)
        updatePhotosByDate(petPhotos)
        refreshLibrarySummary()
    }

    func deleteFromPhotoLibrary(_ photo: PetPhoto) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([photo.asset] as NSArray)
        }
        removeFromPiPi(photo)
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

    private func schedulePersistedPhotoRestore() {
        let records = storyStore.photos
        guard !records.isEmpty else { return }

        restoreTask?.cancel()
        restoreTask = Task {
            let restoredPhotos: [PetPhoto] = await Task.detached(priority: .userInitiated) { () -> [PetPhoto] in
                let assets = PHAsset.fetchAssets(
                    withLocalIdentifiers: records.map(\.assetIdentifier),
                    options: nil
                )
                var assetsByID: [String: PHAsset] = [:]
                assets.enumerateObjects { asset, _, _ in
                    assetsByID[asset.localIdentifier] = asset
                }

                let restored: [PetPhoto] = records.compactMap { record in
                    guard let asset = assetsByID[record.assetIdentifier] else { return nil }
                    return PetPhoto(
                        id: record.assetIdentifier,
                        asset: asset,
                        date: record.captureDate,
                        confidence: record.detectionConfidence,
                        petType: record.detectedPetType,
                        semanticLabels: record.semanticLabels ?? []
                    )
                }
                return restored
            }.value

            guard !Task.isCancelled else { return }
            petPhotos = restoredPhotos
            favoriteIDs = Set(records.filter(\.isFavorite).map(\.assetIdentifier))
            updatePhotosByDate(restoredPhotos)
        }
    }


    private func refreshLibrarySummary() {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            libraryPhotoCount = 0
            remainingPhotoCount = 0
            return
        }

        let assets = PHAsset.fetchAssets(with: .image, options: nil)
        libraryPhotoCount = assets.count
        let analyzed = storyStore.scanHistory.analyzedPhotoIdentifiers
        let semanticUpgrades = storyStore.photos
            .filter { $0.semanticAnalysisVersion != currentSemanticAnalysisVersion }
            .count
        remainingPhotoCount = max(0, assets.count - analyzed.count) + semanticUpgrades
    }
}

private extension PhotoRecord {
    init(_ photo: PetPhoto, isFavorite: Bool) {
        self.init(
            assetIdentifier: photo.id,
            captureDate: photo.date,
            detectedPetType: photo.petType,
            detectionConfidence: photo.confidence,
            semanticLabels: photo.semanticLabels,
            semanticAnalysisVersion: 2,
            isFavorite: isFavorite
        )
    }
}
