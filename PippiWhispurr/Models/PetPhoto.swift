//
//  PetPhoto.swift
//  PippiWhispurr
//
//  Data model for pet photos
//

import Foundation
import Photos
import UIKit

struct PetPhoto: Identifiable, Hashable {
    let id: String
    let asset: PHAsset?
    let localImageFilename: String?
    let date: Date
    let confidence: Float
    var petType: PetType
    var semanticLabels: [String] = []

    init(
        id: String,
        asset: PHAsset? = nil,
        localImageFilename: String? = nil,
        date: Date,
        confidence: Float,
        petType: PetType,
        semanticLabels: [String] = []
    ) {
        self.id = id
        self.asset = asset
        self.localImageFilename = localImageFilename
        self.date = date
        self.confidence = confidence
        self.petType = petType
        self.semanticLabels = semanticLabels
    }

    enum PetType: String, CaseIterable, Codable {
        case dog = "Dog"
        case cat = "Cat"
        case other = "Other Pet"

        var emoji: String {
            switch self {
            case .dog: return "🐕"
            case .cat: return "🐱"
            case .other: return "🐾"
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PetPhoto, rhs: PetPhoto) -> Bool {
        lhs.id == rhs.id
    }
}

struct DayPhotos: Identifiable {
    let id = UUID()
    let date: Date
    let photos: [PetPhoto]

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
