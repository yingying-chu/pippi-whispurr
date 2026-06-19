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
    }

    func detectPet(in image: UIImage) async -> DetectionResult {
        guard let cgImage = image.cgImage else {
            return DetectionResult(petType: nil, confidence: 0.0)
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeAnimalsRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(returning: DetectionResult(petType: nil, confidence: 0.0))
                    return
                }

                // VNRecognizeAnimalsRequest can detect cats and dogs
                let bestLabel = results
                    .flatMap(\.labels)
                    .max { $0.confidence < $1.confidence }

                guard let label = bestLabel else {
                    continuation.resume(returning: DetectionResult(petType: nil, confidence: 0.0))
                    return
                }

                let petType: PetPhoto.PetType
                switch label.identifier.lowercased() {
                case "dog":
                    petType = .dog
                case "cat":
                    petType = .cat
                default:
                    petType = .other
                }

                continuation.resume(returning: DetectionResult(
                    petType: petType,
                    confidence: label.confidence
                ))
            }

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: image.imageOrientation.cgImageOrientation,
                options: [:]
            )

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: DetectionResult(petType: nil, confidence: 0.0))
            }
        }
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
