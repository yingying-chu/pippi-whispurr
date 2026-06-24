//
//  PhotoManager.swift
//  PippiWhispurr
//
//  Manages photo library access and pet photo scanning
//

import Foundation
import Photos
import PhotosUI
import SwiftUI
import UIKit
import Combine
import BackgroundTasks

@MainActor
class PhotoManager: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    static let backgroundScanTaskIdentifier = "com.pippiwhispurr.pet-photo-scan"
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
    @Published var isRestoringLibrary = false
    @Published var unavailableSavedPhotoCount = 0
    @Published var activeFilter: PetPhoto.PetType? = nil
    @Published var activePetFilterID: UUID? = nil
    @Published var showsFavoritesOnly = false
    @Published var favoriteIDs: Set<String> = []

    private let petDetector = PetDetector()
    private let storyStore: StoryStore
    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?
    private var restoreTask: Task<Void, Never>?
    private var isScannerPresented = false
    private var immediateBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var limitedSelectionBaseline: Set<String>?

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

    override convenience init() {
        self.init(storyStore: StoryStore())
    }

    init(storyStore: StoryStore) {
        self.storyStore = storyStore
        super.init()
        PHPhotoLibrary.shared().register(self)
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
                    // Scan batches already add their new PetPhoto values directly.
                    // Re-fetching every saved asset after each batch competes with
                    // Vision and makes the rest of the app visibly stutter.
                    if !self.isScanning {
                        self.schedulePersistedPhotoRestore()
                    }
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

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func chooseMoreLimitedPhotos() {
        limitedSelectionBaseline = accessiblePhotoIdentifiers()
        presentLimitedLibraryPicker()
    }

    func presentLimitedLibraryPicker() {
        guard authorizationStatus == .limited,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let rootViewController = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return
        }

        var presenter = rootViewController
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.checkAuthorizationStatus()
            self.refreshLibrarySummary()

            if let baseline = self.limitedSelectionBaseline {
                self.limitedSelectionBaseline = nil
                let newlyAccessible = self.accessiblePhotoIdentifiers().subtracting(baseline)
                if !newlyAccessible.isEmpty {
                    await self.importSelectedPhotos(assetIdentifiers: Array(newlyAccessible))
                    return
                }
            }

            if self.isScanning == false {
                self.schedulePersistedPhotoRestore()
            }
        }
    }

    func prepareScanSummary() async {
        checkAuthorizationStatus()
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            refreshLibrarySummary()
        }
    }

    func setScannerPresented(_ isPresented: Bool) {
        isScannerPresented = isPresented
    }

    func applicationDidEnterBackground() {
        isScannerPresented = false
        guard isScanning || remainingPhotoCount > 0 else { return }
        scheduleBackgroundScan()

        guard isScanning, immediateBackgroundTask == .invalid else { return }
        immediateBackgroundTask = UIApplication.shared.beginBackgroundTask(
            withName: "PiPi Pet Photo Scan"
        ) { [weak self] in
            Task { @MainActor in
                self?.endImmediateBackgroundTask()
            }
        }
    }

    func applicationDidBecomeActive() {
        endImmediateBackgroundTask()
    }

    func handleBackgroundProcessingTask(_ task: BGProcessingTask) async {
        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                self?.pauseScan()
            }
        }

        while !storyStore.isLoaded && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        await scanAllRemainingPhotos()
        let completedSuccessfully = !isScanPaused && !Task.isCancelled
        task.setTaskCompleted(success: completedSuccessfully)

        refreshLibrarySummary()
        if remainingPhotoCount > 0 {
            scheduleBackgroundScan()
        }
    }

    private func scheduleBackgroundScan() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundScanTaskIdentifier)
        let request = BGProcessingTaskRequest(identifier: Self.backgroundScanTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func endImmediateBackgroundTask() {
        guard immediateBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(immediateBackgroundTask)
        immediateBackgroundTask = .invalid
    }

    func scanAllRemainingPhotos() async {
        if authorizationStatus != .authorized && authorizationStatus != .limited {
            await requestAuthorization()
            guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        }
        refreshLibrarySummary()
        scanBatchSize = max(remainingPhotoCount, 1)
        await scanPhotoLibrary()
    }

    func rescanEntireLibrary() async {
        if authorizationStatus != .authorized && authorizationStatus != .limited {
            await requestAuthorization()
            guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        }
        refreshLibrarySummary()
        scanBatchSize = max(libraryPhotoCount, 1)
        await scanPhotoLibrary(forceRescan: true)
    }

    func scanRecentPhotos(days: Int = 30) async {
        if authorizationStatus != .authorized && authorizationStatus != .limited {
            await requestAuthorization()
            guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        }
        refreshLibrarySummary()
        scanBatchSize = max(libraryPhotoCount, 1)
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        // "Start with Recent Photos" is an explicit request to inspect that
        // period now. Do not let stale scan history silently skip everything,
        // especially when the visible Library is empty after a rebuild.
        await scanPhotoLibrary(forceRescan: true, createdAfter: cutoff)
    }

    func scanSelectedPhotos(assetIdentifiers: [String]) async {
        let identifiers = Set(assetIdentifiers)
        guard !identifiers.isEmpty else { return }
        if authorizationStatus != .authorized && authorizationStatus != .limited {
            await requestAuthorization()
            guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        }
        scanBatchSize = identifiers.count
        await scanPhotoLibrary(includedIdentifiers: identifiers)
    }

    func importSelectedPhotos(assetIdentifiers: [String]) async {
        let identifiers = Array(Set(assetIdentifiers))
        guard !identifiers.isEmpty else { return }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        guard !assets.isEmpty else {
            if authorizationStatus == .limited {
                presentLimitedLibraryPicker()
            }
            return
        }

        isScanning = true
        isScanPaused = false
        scanProgress = 0
        scannedPhotosCount = 0
        totalPhotosToScan = assets.count

        var importedPhotos: [PetPhoto] = []
        for (index, asset) in assets.enumerated() {
            let importedPhoto: PetPhoto
            switch await analyzeAsset(asset) {
            case .analyzed(let detectedPhoto):
                importedPhoto = detectedPhoto ?? PetPhoto(
                    id: asset.localIdentifier,
                    asset: asset,
                    date: asset.creationDate ?? Date(),
                    confidence: 0,
                    petType: .other
                )
            case .unavailable:
                // The user explicitly chose this asset, so keep it even if its
                // full-resolution data is temporarily in iCloud.
                importedPhoto = PetPhoto(
                    id: asset.localIdentifier,
                    asset: asset,
                    date: asset.creationDate ?? Date(),
                    confidence: 0,
                    petType: .other
                )
            }

            importedPhotos.append(importedPhoto)
            scannedPhotosCount = index + 1
            scanProgress = Double(index + 1) / Double(assets.count)
        }

        let records = importedPhotos.map {
            PhotoRecord($0, isFavorite: favoriteIDs.contains($0.id))
        }
        storyStore.storeScanBatch(records, analyzedIdentifiers: identifiers)

        var photosByID = Dictionary(uniqueKeysWithValues: petPhotos.map { ($0.id, $0) })
        importedPhotos.forEach { photosByID[$0.id] = $0 }
        petPhotos = photosByID.values.sorted { $0.date > $1.date }
        updatePhotosByDate(petPhotos)
        isScanning = false
        scanProgress = 1
        refreshLibrarySummary()
    }

    @discardableResult
    func importSelectedPhotos(items: [PhotosPickerItem]) async -> Int {
        guard !items.isEmpty else { return 0 }

        isScanning = true
        isScanPaused = false
        scanProgress = 0
        scannedPhotosCount = 0
        totalPhotosToScan = items.count

        var importedPhotos: [PetPhoto] = []
        for (index, item) in items.enumerated() {
            var importedPhoto: PetPhoto?

            if let identifier = item.itemIdentifier {
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                if let asset = result.firstObject {
                    switch await analyzeAsset(asset) {
                    case .analyzed(let detectedPhoto):
                        importedPhoto = detectedPhoto ?? PetPhoto(
                            id: asset.localIdentifier,
                            asset: asset,
                            date: asset.creationDate ?? Date(),
                            confidence: 0,
                            petType: .other
                        )
                    case .unavailable:
                        importedPhoto = PetPhoto(
                            id: asset.localIdentifier,
                            asset: asset,
                            date: asset.creationDate ?? Date(),
                            confidence: 0,
                            petType: .other
                        )
                    }
                }
            }

            // PhotosPicker can legally return no PhotoKit identifier even though
            // the user selected a valid image. Keep an app-owned copy instead of
            // silently dropping the selection or duplicating it in Photos.
            if importedPhoto == nil,
               let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let filename = saveImportedImage(image) {
                let detection = await petDetector.detectPet(in: image)
                let detectedType = detection.confidence > 0.6
                    ? (detection.petType ?? .other)
                    : .other
                importedPhoto = PetPhoto(
                    id: "local-import:\(UUID().uuidString)",
                    localImageFilename: filename,
                    date: Date(),
                    confidence: detection.confidence,
                    petType: detectedType,
                    semanticLabels: detection.semanticLabels
                )
            }

            if let importedPhoto {
                importedPhotos.append(importedPhoto)
            }
            scannedPhotosCount = index + 1
            scanProgress = Double(index + 1) / Double(items.count)
        }

        let records = importedPhotos.map {
            PhotoRecord($0, isFavorite: favoriteIDs.contains($0.id))
        }
        storyStore.storeScanBatch(
            records,
            analyzedIdentifiers: importedPhotos.map(\.id)
        )

        var photosByID = Dictionary(uniqueKeysWithValues: petPhotos.map { ($0.id, $0) })
        importedPhotos.forEach { photosByID[$0.id] = $0 }
        petPhotos = photosByID.values.sorted { $0.date > $1.date }
        updatePhotosByDate(petPhotos)
        isScanning = false
        scanProgress = 1
        refreshLibrarySummary()
        return importedPhotos.count
    }

    private func saveImportedImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        let url = importedPhotosDirectory.appendingPathComponent(filename)
        do {
            try FileManager.default.createDirectory(
                at: importedPhotosDirectory,
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    private var importedPhotosDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PiPiImportedPhotos", isDirectory: true)
    }

    private func localImage(filename: String) -> UIImage? {
        UIImage(contentsOfFile: importedPhotosDirectory.appendingPathComponent(filename).path)
    }

    func scanPhotoLibrary(
        forceRescan: Bool = false,
        includedIdentifiers: Set<String>? = nil,
        createdAfter: Date? = nil
    ) async {
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
            let alreadyAnalyzed: Set<String>
            if forceRescan {
                alreadyAnalyzed = []
            } else {
                alreadyAnalyzed = storyStore.scanHistory.analyzedPhotoIdentifiers
                    .union(storyStore.photos.map(\.assetIdentifier))
                    .subtracting(needsSemanticUpgrade)
            }
            var photosForThisBatch: [PHAsset] = []
            photosForThisBatch.reserveCapacity(scanBatchSize)

            for index in 0..<allPhotos.count {
                let asset = allPhotos.object(at: index)
                if let includedIdentifiers,
                   !includedIdentifiers.contains(asset.localIdentifier) {
                    continue
                }
                if let createdAfter,
                   (asset.creationDate ?? .distantPast) < createdAfter {
                    continue
                }
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
                endImmediateBackgroundTask()
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

                // Keep a small number of Vision requests in flight. Four-way
                // concurrency is substantially faster than the old serial loop
                // without creating the memory spikes of launching a whole batch.
                let assetsInBatch = Array(photosForThisBatch[batchStart..<batchEnd])
                let preferredConcurrency = isScannerPresented ? 3 : 1
                let maxConcurrentAnalyses = min(preferredConcurrency, assetsInBatch.count)
                await withTaskGroup(of: (String, AssetAnalysisResult).self) { group in
                    var nextAssetIndex = 0

                    for _ in 0..<maxConcurrentAnalyses {
                        let asset = assetsInBatch[nextAssetIndex]
                        nextAssetIndex += 1
                        group.addTask(priority: .utility) { [self] in
                            (asset.localIdentifier, await analyzeAsset(asset))
                        }
                    }

                    while let (identifier, analysis) = await group.next() {
                        if Task.isCancelled {
                            group.cancelAll()
                            break
                        }

                        switch analysis {
                        case .analyzed(let result):
                            analyzedIdentifiers.append(identifier)
                            if let result {
                                detectedPhotos.append(result)
                                allVisiblePhotos[result.id] = result
                            }
                        case .unavailable:
                            // Keep iCloud-only assets eligible for a later scan.
                            break
                        }

                        processedCount += 1
                        scannedPhotosCount = processedCount
                        scanProgress = Double(processedCount) / Double(totalCount)
                        let elapsed = Date().timeIntervalSince(scanStartedAt)
                        if processedCount >= 8 && elapsed > 0 {
                            let currentRate = Double(processedCount) / elapsed
                            estimatedSecondsRemaining = Double(totalCount - processedCount) / max(currentRate, 1)
                        }

                        if nextAssetIndex < assetsInBatch.count {
                            let asset = assetsInBatch[nextAssetIndex]
                            nextAssetIndex += 1
                            group.addTask(priority: .utility) { [self] in
                                (asset.localIdentifier, await analyzeAsset(asset))
                            }
                        }
                    }
                }

                // Update UI after each batch
                let records = detectedPhotos.map {
                    PhotoRecord($0, isFavorite: favoriteIDs.contains($0.id))
                }
                storyStore.storeScanBatch(records, analyzedIdentifiers: analyzedIdentifiers)
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
            endImmediateBackgroundTask()
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
                targetSize: CGSize(width: 1600, height: 1600),
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

    func loadFullImage(for photo: PetPhoto) async -> UIImage? {
        if let asset = photo.asset {
            return await loadFullImage(for: asset)
        }
        if let filename = photo.localImageFilename {
            return localImage(filename: filename)
        }
        return nil
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
        activePetFilterID = nil
        showsFavoritesOnly = false
        applyFilter()
    }

    func setPetFilter(_ petID: UUID) {
        activeFilter = nil
        activePetFilterID = petID
        showsFavoritesOnly = false
        applyFilter()
    }

    func showFavorites() {
        activeFilter = nil
        activePetFilterID = nil
        showsFavoritesOnly = true
        applyFilter()
    }

    private func applyFilter() {
        let filtered: [PetPhoto]
        if showsFavoritesOnly {
            filtered = petPhotos.filter { favoriteIDs.contains($0.id) }
        } else if let activePetFilterID {
            let assignedIdentifiers = Set(storyStore.photos
                .filter { $0.assignedPetIDs.contains(activePetFilterID) }
                .map(\.assetIdentifier))
            filtered = petPhotos.filter { assignedIdentifiers.contains($0.id) }
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
        if let filename = photo.localImageFilename {
            try? FileManager.default.removeItem(
                at: importedPhotosDirectory.appendingPathComponent(filename)
            )
        }
        petPhotos.removeAll { $0.id == photo.id }
        favoriteIDs.remove(photo.id)
        storyStore.removePhoto(id: photo.id)
        updatePhotosByDate(petPhotos)
        refreshLibrarySummary()
    }

    func deleteFromPhotoLibrary(_ photo: PetPhoto) async throws {
        guard let asset = photo.asset else {
            removeFromPiPi(photo)
            return
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
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
        if let activePetFilterID {
            let assignedIdentifiers = Set(storyStore.photos
                .filter { $0.assignedPetIDs.contains(activePetFilterID) }
                .map(\.assetIdentifier))
            return petPhotos.filter { assignedIdentifiers.contains($0.id) }
        }
        if let activeFilter {
            return petPhotos.filter { $0.petType == activeFilter }
        }
        return petPhotos
    }

    private func schedulePersistedPhotoRestore() {
        let records = storyStore.photos
        guard !records.isEmpty else {
            isRestoringLibrary = false
            unavailableSavedPhotoCount = 0
            return
        }

        restoreTask?.cancel()
        isRestoringLibrary = true
        let importedDirectory = importedPhotosDirectory
        restoreTask = Task {
            let restoredPhotos: [PetPhoto] = await Task.detached(priority: .userInitiated) { () -> [PetPhoto] in
                var assetsByID: [String: PHAsset] = [:]

                // A single PhotoKit lookup with thousands of local identifiers
                // can exceed the underlying query's parameter limit and return
                // no assets at all. Restore in bounded chunks so a large saved
                // Library survives every app launch.
                let photoKitIdentifiers = records
                    .filter { $0.localImageFilename == nil }
                    .map(\.assetIdentifier)
                for batchStart in stride(from: 0, to: photoKitIdentifiers.count, by: 200) {
                    let batchEnd = min(batchStart + 200, photoKitIdentifiers.count)
                    let batch = Array(photoKitIdentifiers[batchStart..<batchEnd])
                    let assets = PHAsset.fetchAssets(
                        withLocalIdentifiers: batch,
                        options: nil
                    )
                    assets.enumerateObjects { asset, _, _ in
                        assetsByID[asset.localIdentifier] = asset
                    }
                }

                let restored: [PetPhoto] = records.compactMap { record in
                    if let asset = assetsByID[record.assetIdentifier] {
                        return PetPhoto(
                            id: record.assetIdentifier,
                            asset: asset,
                            date: record.captureDate,
                            confidence: record.detectionConfidence,
                            petType: record.detectedPetType,
                            semanticLabels: record.semanticLabels ?? []
                        )
                    }
                    if let filename = record.localImageFilename,
                       FileManager.default.fileExists(
                        atPath: importedDirectory.appendingPathComponent(filename).path
                       ) {
                        return PetPhoto(
                            id: record.assetIdentifier,
                            localImageFilename: filename,
                            date: record.captureDate,
                            confidence: record.detectionConfidence,
                            petType: record.detectedPetType,
                            semanticLabels: record.semanticLabels ?? []
                        )
                    }
                    return nil
                }
                return restored
            }.value

            guard !Task.isCancelled else { return }
            // A restore can finish while a scan is adding fresh results. Merge the
            // two collections so a late restore never wipes the visible Library.
            var photosByID = Dictionary(uniqueKeysWithValues: petPhotos.map { ($0.id, $0) })
            restoredPhotos.forEach { photosByID[$0.id] = $0 }
            petPhotos = photosByID.values.sorted { $0.date > $1.date }
            favoriteIDs = Set(records.filter(\.isFavorite).map(\.assetIdentifier))
            unavailableSavedPhotoCount = max(0, records.count - restoredPhotos.count)
            updatePhotosByDate(petPhotos)
            isRestoringLibrary = false
            refreshLibrarySummary()
        }
    }


    private func refreshLibrarySummary() {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            libraryPhotoCount = 0
            remainingPhotoCount = 0
            return
        }

        let accessibleIdentifiers = accessiblePhotoIdentifiers()

        libraryPhotoCount = accessibleIdentifiers.count
        let needsSemanticUpgrade = Set(storyStore.photos
            .filter { $0.semanticAnalysisVersion != currentSemanticAnalysisVersion }
            .map(\.assetIdentifier))
        let alreadyAnalyzed = storyStore.scanHistory.analyzedPhotoIdentifiers
            .union(storyStore.photos.map(\.assetIdentifier))
            .subtracting(needsSemanticUpgrade)

        // Scan history can contain identifiers that are no longer accessible
        // (deleted photos, a rebuilt simulator, or Limited Photos permission).
        // Count actual accessible identifiers instead of subtracting two totals.
        remainingPhotoCount = accessibleIdentifiers.subtracting(alreadyAnalyzed).count
    }

    private func accessiblePhotoIdentifiers() -> Set<String> {
        let assets = PHAsset.fetchAssets(with: .image, options: nil)
        var identifiers = Set<String>()
        identifiers.reserveCapacity(assets.count)
        assets.enumerateObjects { asset, _, _ in
            identifiers.insert(asset.localIdentifier)
        }
        return identifiers
    }
}

private extension PhotoRecord {
    init(_ photo: PetPhoto, isFavorite: Bool) {
        self.init(
            assetIdentifier: photo.id,
            localImageFilename: photo.localImageFilename,
            captureDate: photo.date,
            detectedPetType: photo.petType,
            detectionConfidence: photo.confidence,
            semanticLabels: photo.semanticLabels,
            semanticAnalysisVersion: 2,
            isFavorite: isFavorite
        )
    }
}
