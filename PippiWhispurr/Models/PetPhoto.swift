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
    let asset: PHAsset
    let date: Date
    let confidence: Float
    let petType: PetType
    var semanticLabels: [String] = []

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
