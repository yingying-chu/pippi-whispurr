//
//  PetDetector.swift
//  PippiWhispurr
//
//  Uses Vision framework to detect pets in photos
//

import Foundation
import Vision
import UIKit

class PetDetector {
    struct DetectionResult {
        let petType: PetPhoto.PetType?
        let confidence: Float
        let semanticLabels: [String]
    }

    func detectPet(in image: UIImage) async -> DetectionResult {
        guard let cgImage = image.cgImage else {
            return DetectionResult(petType: nil, confidence: 0.0, semanticLabels: [])
        }

        return await Task.detached(priority: .utility) {
            let animalRequest = VNRecognizeAnimalsRequest()
            let classificationRequest = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: image.imageOrientation.cgImageOrientation,
                options: [:]
            )

            do {
                try handler.perform([animalRequest, classificationRequest])
            } catch {
                return DetectionResult(petType: nil, confidence: 0.0, semanticLabels: [])
            }

            let bestLabel = animalRequest.results?
                .flatMap(\.labels)
                .max { $0.confidence < $1.confidence }

            let petType: PetPhoto.PetType?
            switch bestLabel?.identifier.lowercased() {
            case "dog": petType = .dog
            case "cat": petType = .cat
            case .some(_): petType = .other
            case .none: petType = nil
            }

            let semanticLabels = (classificationRequest.results ?? [])
                .filter { $0.confidence >= 0.08 }
                .sorted { $0.confidence > $1.confidence }
                .prefix(10)
                .map { $0.identifier.lowercased() }

            return DetectionResult(
                petType: petType,
                confidence: bestLabel?.confidence ?? 0,
                semanticLabels: semanticLabels
            )
        }.value
    }
}

private extension UIImage.Orientation {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
