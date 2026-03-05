import Foundation
import UIKit

// MARK: - Use Case Protocol

protocol ClothingDetectionUseCaseProtocol {
    func detectClothing(in request: ImageProcessingRequest) async throws -> DetectionResult
}

// MARK: - Use Case Implementation

class ClothingDetectionUseCase: ClothingDetectionUseCaseProtocol {
    private let repository: ClothingDetectionRepositoryProtocol

    init(repository: ClothingDetectionRepositoryProtocol) {
        self.repository = repository
    }

    func detectClothing(in request: ImageProcessingRequest) async throws -> DetectionResult {
        let startTime = Date()
        let observations = try await repository.detectClothing(in: request)

        let items = observations
            .filter { $0.confidence > request.confidenceThreshold }
            .map { ClothingItem(from: $0, imageSize: request.image.size) }

        return DetectionResult(
            items: items,
            processingTime: Date().timeIntervalSince(startTime),
            imageSize: request.image.size
        )
    }
}

// MARK: - Domain Errors

enum ClothingDetectionError: Error, LocalizedError {
    case modelLoadingFailed
    case imageProcessingFailed
    case detectionFailed(String)
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .modelLoadingFailed:
            return "Failed to load the clothing detection model"
        case .imageProcessingFailed:
            return "Failed to process the image"
        case .detectionFailed(let message):
            return "Detection failed: \(message)"
        case .invalidImage:
            return "Invalid image provided"
        }
    }
}
