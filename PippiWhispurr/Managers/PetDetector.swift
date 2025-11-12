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
                      let results = request.results as? [VNRecognizedObjectObservation],
                      let firstResult = results.first else {
                    continuation.resume(returning: DetectionResult(petType: nil, confidence: 0.0))
                    return
                }

                // VNRecognizeAnimalsRequest can detect cats and dogs
                let labels = firstResult.labels
                var bestLabel: VNClassificationObservation?
                var bestConfidence: Float = 0.0

                for label in labels {
                    if label.confidence > bestConfidence {
                        bestConfidence = label.confidence
                        bestLabel = label
                    }
                }

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
                    confidence: bestConfidence
                ))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: DetectionResult(petType: nil, confidence: 0.0))
            }
        }
    }
}
