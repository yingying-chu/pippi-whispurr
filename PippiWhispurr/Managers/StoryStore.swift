//
//  StoryStore.swift
//  PippiWhispurr
//
//  Local persistence for the story data that must survive app launches.
//

import Foundation
import Combine

@MainActor
final class StoryStore: ObservableObject {
    @Published private(set) var pets: [PetProfile] = []
    @Published private(set) var photos: [PhotoRecord] = []
    @Published private(set) var memories: [MemoryEntry] = []
    @Published private(set) var milestones: [Milestone] = []
    @Published private(set) var healthCheckIns: [HealthCheckIn] = []
    @Published private(set) var scanHistory = ScanHistory()
    @Published private(set) var persistenceError: String?

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let directory = applicationSupport.appendingPathComponent(
            "PippiWhispurr",
            isDirectory: true
        )

        self.fileManager = fileManager
        fileURL = directory.appendingPathComponent("story-data.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            persistenceError = "Could not prepare local storage: \(error.localizedDescription)"
        }

        load()
    }

    func upsertPet(_ pet: PetProfile) {
        upsert(pet, in: &pets)
        save()
    }

    func deletePet(id: UUID) {
        pets.removeAll { $0.id == id }
        photos = photos.map { photo in
            var updated = photo
            updated.assignedPetIDs.remove(id)
            return updated
        }
        memories = memories.compactMap { memory in
            var updated = memory
            updated.petIDs.remove(id)
            return updated.petIDs.isEmpty ? nil : updated
        }
        milestones.removeAll { $0.petID == id }
        healthCheckIns.removeAll { $0.petID == id }
        save()
    }

    func upsertPhoto(_ photo: PhotoRecord) {
        if let index = photos.firstIndex(where: { $0.id == photo.id }) {
            var merged = photo
            let existing = photos[index]
            merged.assignedPetIDs = existing.assignedPetIDs
            merged.isFavorite = existing.isFavorite
            merged.caption = existing.caption
            photos[index] = merged
        } else {
            photos.append(photo)
        }
        sortPhotos()
        save()
    }

    func upsertPhotos(_ newPhotos: [PhotoRecord]) {
        guard !newPhotos.isEmpty else { return }

        var recordsByID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        for photo in newPhotos {
            if let existing = recordsByID[photo.id] {
                var merged = photo
                merged.assignedPetIDs = existing.assignedPetIDs
                merged.isFavorite = existing.isFavorite
                merged.caption = existing.caption
                recordsByID[photo.id] = merged
            } else {
                recordsByID[photo.id] = photo
            }
        }
        photos = Array(recordsByID.values)
        sortPhotos()
        save()
    }

    func assignPhoto(id: String, to petIDs: Set<UUID>) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].assignedPetIDs = petIDs
        photos[index].updatedAt = Date()
        save()
    }

    func setFavorite(photoID: String, isFavorite: Bool) {
        guard let index = photos.firstIndex(where: { $0.id == photoID }) else { return }
        photos[index].isFavorite = isFavorite
        photos[index].updatedAt = Date()
        save()
    }

    func upsertMemory(_ memory: MemoryEntry) {
        upsert(memory, in: &memories)
        memories.sort { $0.memoryDate > $1.memoryDate }
        save()
    }

    func deleteMemory(id: UUID) {
        memories.removeAll { $0.id == id }
        save()
    }

    func upsertMilestone(_ milestone: Milestone) {
        upsert(milestone, in: &milestones)
        milestones.sort { $0.date > $1.date }
        save()
    }

    func deleteMilestone(id: UUID) {
        milestones.removeAll { $0.id == id }
        save()
    }

    func upsertHealthCheckIn(_ checkIn: HealthCheckIn) {
        upsert(checkIn, in: &healthCheckIns)
        healthCheckIns.sort { $0.date > $1.date }
        save()
    }

    func deleteHealthCheckIn(id: UUID) {
        healthCheckIns.removeAll { $0.id == id }
        save()
    }

    func markPhotosAnalyzed(_ identifiers: [String]) {
        scanHistory.analyzedPhotoIdentifiers.formUnion(identifiers)
        save()
    }

    func completeScanBatch(photosProcessed: Int = 0, duration: TimeInterval = 0) {
        scanHistory.lastCompletedAt = Date()
        scanHistory.completedBatchCount += 1
        if photosProcessed > 0 && duration > 0 {
            let measuredRate = Double(photosProcessed) / duration
            if let previousRate = scanHistory.photosPerSecond {
                scanHistory.photosPerSecond = previousRate * 0.35 + measuredRate * 0.65
            } else {
                scanHistory.photosPerSecond = measuredRate
            }
        }
        save()
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let stored = try decoder.decode(StoryData.self, from: data)
            pets = stored.pets
            photos = stored.photos.sorted { $0.captureDate > $1.captureDate }
            memories = stored.memories.sorted { $0.memoryDate > $1.memoryDate }
            milestones = stored.milestones.sorted { $0.date > $1.date }
            healthCheckIns = stored.healthCheckIns.sorted { $0.date > $1.date }
            scanHistory = stored.scanHistory
            persistenceError = nil
        } catch {
            persistenceError = "Could not load saved stories: \(error.localizedDescription)"
        }
    }

    private func save() {
        let stored = StoryData(
            pets: pets,
            photos: photos,
            memories: memories,
            milestones: milestones,
            healthCheckIns: healthCheckIns,
            scanHistory: scanHistory
        )

        do {
            let data = try encoder.encode(stored)
            try data.write(to: fileURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = "Could not save stories: \(error.localizedDescription)"
        }
    }

    private func sortPhotos() {
        photos.sort { $0.captureDate > $1.captureDate }
    }

    private func upsert<Item: Identifiable>(_ item: Item, in items: inout [Item])
    where Item.ID: Equatable {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }
}
