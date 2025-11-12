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
    @Published var totalPhotosToScan: Int = 0
    @Published var scannedPhotosCount: Int = 0

    private let petDetector = PetDetector()
    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?

    // Limit to most recent photos to avoid memory issues with large libraries
    private let maxPhotosToScan = 1000
    private let batchSize = 20

    init() {
        checkAuthorizationStatus()
    }

    func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
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
            var detectedPhotos: [PetPhoto] = []

            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            // Limit the number of photos to scan to avoid memory issues
            fetchOptions.fetchLimit = maxPhotosToScan

            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            let totalCount = min(allPhotos.count, maxPhotosToScan)
            totalPhotosToScan = totalCount

            var processedCount = 0

            // Process in batches to manage memory
            for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
                // Check for cancellation
                if Task.isCancelled {
                    break
                }

                let batchEnd = min(batchStart + batchSize, totalCount)

                // Process batch
                for index in batchStart..<batchEnd {
                    if Task.isCancelled {
                        break
                    }

                    let asset = allPhotos.object(at: index)

                    if let result = await analyzeAsset(asset) {
                        detectedPhotos.append(result)
                    }

                    processedCount += 1
                    scannedPhotosCount = processedCount
                    scanProgress = Double(processedCount) / Double(totalCount)
                }

                // Update UI after each batch
                petPhotos = detectedPhotos
                updatePhotosByDate(detectedPhotos)

                // Small delay between batches to prevent memory spikes
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }

            if !Task.isCancelled {
                petPhotos = detectedPhotos
                updatePhotosByDate(detectedPhotos)
                scanProgress = 1.0
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
            if grouped[startOfDay] != nil {
                grouped[startOfDay]?.append(photo)
            } else {
                grouped[startOfDay] = [photo]
            }
        }

        photosByDate = grouped
    }

    func photosForDate(_ date: Date) -> [PetPhoto] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return photosByDate[startOfDay] ?? []
    }
}
