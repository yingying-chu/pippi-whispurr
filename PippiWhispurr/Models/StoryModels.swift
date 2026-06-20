//
//  StoryModels.swift
//  PippiWhispurr
//
//  Durable product models for pets, memories, milestones, and photo references.
//

import Foundation

struct PetProfile: Identifiable, Codable, Hashable {
    enum Gender: String, Codable, CaseIterable {
        case male
        case female
        case neutral
    }

    enum LifeStatus: String, Codable, CaseIterable {
        case current
        case remembered
        case memorial
    }

    let id: UUID
    var name: String
    var species: String
    var breed: String?
    var gender: Gender?
    var isSpayedOrNeutered: Bool?
    var foodName: String?
    var foodBrand: String?
    var birthday: Date?
    var adoptionDate: Date?
    var profilePhotoIdentifier: String?
    var introduction: String
    var lifeStatus: LifeStatus
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        species: String,
        breed: String? = nil,
        gender: Gender? = nil,
        isSpayedOrNeutered: Bool? = nil,
        foodName: String? = nil,
        foodBrand: String? = nil,
        birthday: Date? = nil,
        adoptionDate: Date? = nil,
        profilePhotoIdentifier: String? = nil,
        introduction: String = "",
        lifeStatus: LifeStatus = .current,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.breed = breed
        self.gender = gender
        self.isSpayedOrNeutered = isSpayedOrNeutered
        self.foodName = foodName
        self.foodBrand = foodBrand
        self.birthday = birthday
        self.adoptionDate = adoptionDate
        self.profilePhotoIdentifier = profilePhotoIdentifier
        self.introduction = introduction
        self.lifeStatus = lifeStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ScanHistory: Codable {
    var analyzedPhotoIdentifiers: Set<String> = []
    var lastCompletedAt: Date?
    var completedBatchCount: Int = 0
    var photosPerSecond: Double?
}

struct PhotoRecord: Identifiable, Codable, Hashable {
    var id: String { assetIdentifier }

    let assetIdentifier: String
    var captureDate: Date
    var detectedPetType: PetPhoto.PetType
    var detectionConfidence: Float
    var semanticLabels: [String]?
    var semanticAnalysisVersion: Int?
    var assignedPetIDs: Set<UUID>
    var isFavorite: Bool
    var caption: String
    let createdAt: Date
    var updatedAt: Date

    init(
        assetIdentifier: String,
        captureDate: Date,
        detectedPetType: PetPhoto.PetType,
        detectionConfidence: Float,
        semanticLabels: [String]? = nil,
        semanticAnalysisVersion: Int? = nil,
        assignedPetIDs: Set<UUID> = [],
        isFavorite: Bool = false,
        caption: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.assetIdentifier = assetIdentifier
        self.captureDate = captureDate
        self.detectedPetType = detectedPetType
        self.detectionConfidence = detectionConfidence
        self.semanticLabels = semanticLabels
        self.semanticAnalysisVersion = semanticAnalysisVersion
        self.assignedPetIDs = assignedPetIDs
        self.isFavorite = isFavorite
        self.caption = caption
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct MemoryEntry: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case everyday
        case birthday
        case adoption
        case adventure
        case firstTime
        case health
        case custom
    }

    enum Feeling: String, Codable, CaseIterable {
        case happy
        case grateful
        case playful
        case proud
        case calm
        case worried
        case tender
    }

    let id: UUID
    var title: String
    var body: String
    var memoryDate: Date
    var petIDs: Set<UUID>
    var photoIdentifiers: [String]
    var locationName: String?
    var kind: Kind?
    var feeling: Feeling?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        body: String,
        memoryDate: Date = Date(),
        petIDs: Set<UUID>,
        photoIdentifiers: [String] = [],
        locationName: String? = nil,
        kind: Kind? = .everyday,
        feeling: Feeling? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.memoryDate = memoryDate
        self.petIDs = petIDs
        self.photoIdentifiers = photoIdentifiers
        self.locationName = locationName
        self.kind = kind
        self.feeling = feeling
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Milestone: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case adoption
        case birthday
        case firstDayHome
        case firstTrip
        case training
        case health
        case movingHome
        case remembrance
        case custom
    }

    let id: UUID
    var petID: UUID
    var kind: Kind
    var title: String
    var note: String
    var date: Date
    var isDateApproximate: Bool
    var photoIdentifiers: [String]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        petID: UUID,
        kind: Kind,
        title: String,
        note: String = "",
        date: Date,
        isDateApproximate: Bool = false,
        photoIdentifiers: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.petID = petID
        self.kind = kind
        self.title = title
        self.note = note
        self.date = date
        self.isDateApproximate = isDateApproximate
        self.photoIdentifiers = photoIdentifiers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct HealthCheckIn: Identifiable, Codable, Hashable {
    enum Level: String, Codable, CaseIterable {
        case low
        case normal
        case high
    }

    enum Mood: String, Codable, CaseIterable {
        case happy
        case calm
        case playful
        case anxious
        case unwell
    }

    enum WeightUnit: String, Codable, CaseIterable {
        case pounds
        case kilograms
    }

    let id: UUID
    var petID: UUID
    var date: Date
    var appetite: Level
    var energy: Level
    var mood: Mood
    var weight: Double?
    var weightUnit: WeightUnit
    var notes: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        petID: UUID,
        date: Date = Date(),
        appetite: Level = .normal,
        energy: Level = .normal,
        mood: Mood = .calm,
        weight: Double? = nil,
        weightUnit: WeightUnit = .pounds,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.petID = petID
        self.date = date
        self.appetite = appetite
        self.energy = energy
        self.mood = mood
        self.weight = weight
        self.weightUnit = weightUnit
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct StoryData: Codable {
    static let currentSchemaVersion = 3

    var schemaVersion: Int = currentSchemaVersion
    var pets: [PetProfile] = []
    var photos: [PhotoRecord] = []
    var memories: [MemoryEntry] = []
    var milestones: [Milestone] = []
    var healthCheckIns: [HealthCheckIn] = []
    var scanHistory: ScanHistory = ScanHistory()

    init(
        schemaVersion: Int = currentSchemaVersion,
        pets: [PetProfile] = [],
        photos: [PhotoRecord] = [],
        memories: [MemoryEntry] = [],
        milestones: [Milestone] = [],
        healthCheckIns: [HealthCheckIn] = [],
        scanHistory: ScanHistory = ScanHistory()
    ) {
        self.schemaVersion = schemaVersion
        self.pets = pets
        self.photos = photos
        self.memories = memories
        self.milestones = milestones
        self.healthCheckIns = healthCheckIns
        self.scanHistory = scanHistory
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case pets
        case photos
        case memories
        case milestones
        case healthCheckIns
        case scanHistory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        pets = try container.decodeIfPresent([PetProfile].self, forKey: .pets) ?? []
        photos = try container.decodeIfPresent([PhotoRecord].self, forKey: .photos) ?? []
        memories = try container.decodeIfPresent([MemoryEntry].self, forKey: .memories) ?? []
        milestones = try container.decodeIfPresent([Milestone].self, forKey: .milestones) ?? []
        healthCheckIns = try container.decodeIfPresent([HealthCheckIn].self, forKey: .healthCheckIns) ?? []
        scanHistory = try container.decodeIfPresent(ScanHistory.self, forKey: .scanHistory) ?? ScanHistory()
    }
}
