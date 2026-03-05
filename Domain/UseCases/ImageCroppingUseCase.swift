import Foundation
import UIKit

// MARK: - Use Case Protocol

protocol ImageCroppingUseCaseProtocol {
    func cropImage(from request: CropRequest) async throws -> CroppedImage
    func cropMultipleImages(from requests: [CropRequest]) async throws -> [CroppedImage]
}

// MARK: - Use Case Implementation

class ImageCroppingUseCase: ImageCroppingUseCaseProtocol {
    private let repository: ImageCroppingRepositoryProtocol

    init(repository: ImageCroppingRepositoryProtocol) {
        self.repository = repository
    }

    func cropImage(from request: CropRequest) async throws -> CroppedImage {
        try await repository.cropImage(from: request)
    }

    func cropMultipleImages(from requests: [CropRequest]) async throws -> [CroppedImage] {
        var croppedImages: [CroppedImage] = []
        croppedImages.reserveCapacity(requests.count)

        for request in requests {
            let croppedImage = try await cropImage(from: request)
            croppedImages.append(croppedImage)
        }

        return croppedImages
    }
}

// MARK: - Repository Protocol

protocol ImageCroppingRepositoryProtocol {
    func cropImage(from request: CropRequest) async throws -> CroppedImage
}

// MARK: - Repository Implementation

class ImageCroppingRepository: ImageCroppingRepositoryProtocol {
    private let dataSource: ImageCroppingDataSourceProtocol

    init(dataSource: ImageCroppingDataSourceProtocol) {
        self.dataSource = dataSource
    }

    func cropImage(from request: CropRequest) async throws -> CroppedImage {
        try await dataSource.cropImage(from: request)
    }
}

// MARK: - Data Source Protocol

protocol ImageCroppingDataSourceProtocol {
    func cropImage(from request: CropRequest) async throws -> CroppedImage
}

// MARK: - Data Source Implementation

class CoreImageCroppingDataSource: ImageCroppingDataSourceProtocol {
    func cropImage(from request: CropRequest) async throws -> CroppedImage {
        let originalImage = request.originalImage
        let item = request.clothingItem
        let padding = request.padding

        // Convert normalized coordinates to image-space and clamp to source bounds.
        let imageSize = originalImage.size
        let cropRect = BoundingBoxMapper.denormalizedRect(
            from: item.boundingBox,
            in: imageSize,
            padding: padding
        )
        let clampedRect = BoundingBoxMapper.clampedToImageBounds(cropRect, imageSize: imageSize)

        guard let cgImage = originalImage.cgImage,
              let croppedCGImage = cgImage.cropping(to: clampedRect) else {
            throw ClothingDetectionError.imageProcessingFailed
        }

        let croppedImage = UIImage(
            cgImage: croppedCGImage,
            scale: originalImage.scale,
            orientation: originalImage.imageOrientation
        )

        return CroppedImage(image: croppedImage, sourceItem: item, cropRect: clampedRect)
    }
}
