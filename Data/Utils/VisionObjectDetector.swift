import Foundation
@preconcurrency import Vision
import UIKit

// Namespace-style utility type: static-only helpers, not meant to be instantiated, which enum enforces.
enum VisionObjectDetector {
    static func detectObjects(on image: UIImage, using model: VNCoreMLModel) async throws -> [VNRecognizedObjectObservation] {
        guard let cgImage = image.cgImage else {
            throw ClothingDetectionError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    continuation.resume(throwing: ClothingDetectionError.detectionFailed(error.localizedDescription))
                    return
                }

                guard let results = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(throwing: ClothingDetectionError.detectionFailed("No results returned"))
                    return
                }

                continuation.resume(returning: results)
            }

            request.imageCropAndScaleOption = .scaleFit
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: ClothingDetectionError.detectionFailed(error.localizedDescription))
                }
            }
        }
    }
}
