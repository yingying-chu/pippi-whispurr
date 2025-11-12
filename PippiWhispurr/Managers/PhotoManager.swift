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

    private let petDetector = PetDetector()
    private var cancellables = Set<AnyCancellable>()

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

        isScanning = true
        scanProgress = 0.0
        var detectedPhotos: [PetPhoto] = []

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let totalCount = allPhotos.count

        var processedCount = 0

        for index in 0..<totalCount {
            let asset = allPhotos.object(at: index)

            if let result = await analyzeAsset(asset) {
                detectedPhotos.append(result)
            }

            processedCount += 1
            scanProgress = Double(processedCount) / Double(totalCount)

            // Update UI periodically
            if processedCount % 10 == 0 {
                petPhotos = detectedPhotos
                updatePhotosByDate(detectedPhotos)
            }
        }

        petPhotos = detectedPhotos
        updatePhotosByDate(detectedPhotos)
        isScanning = false
        scanProgress = 1.0
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

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func loadFullImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
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
