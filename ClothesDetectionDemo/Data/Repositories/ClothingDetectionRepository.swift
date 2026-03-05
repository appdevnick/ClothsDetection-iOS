import Foundation
@preconcurrency import Vision
import UIKit

// MARK: - Repository Protocol

protocol ClothingDetectionRepositoryProtocol {
    func detectClothing(in request: ImageProcessingRequest) async throws -> [VNRecognizedObjectObservation]
}

// MARK: - Repository Implementation

class ClothingDetectionRepository: ClothingDetectionRepositoryProtocol {
    private let dataSource: ClothingDetectionDataSourceProtocol

    init(dataSource: ClothingDetectionDataSourceProtocol) {
        self.dataSource = dataSource
    }

    func detectClothing(in request: ImageProcessingRequest) async throws -> [VNRecognizedObjectObservation] {
        try await dataSource.performDetection(on: request.image)
    }
}

// MARK: - Data Source Protocol

protocol ClothingDetectionDataSourceProtocol {
    func performDetection(on image: UIImage) async throws -> [VNRecognizedObjectObservation]
}

// MARK: - Data Source Implementation

class VisionClothingDetectionDataSource: ClothingDetectionDataSourceProtocol {
    private let model: VNCoreMLModel

    init() throws {
        guard let model = try? VNCoreMLModel(for: best().model) else {
            throw ClothingDetectionError.modelLoadingFailed
        }
        self.model = model
    }

    func performDetection(on image: UIImage) async throws -> [VNRecognizedObjectObservation] {
        try await VisionObjectDetector.detectObjects(on: image, using: model)
    }
}
