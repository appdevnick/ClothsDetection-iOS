#if canImport(Testing)
import Foundation
import Testing
import UIKit
@testable import FashionApp

struct ImageCroppingUseCaseTests {
    @Test
    func cropMultipleImagesReturnsImagesInRequestOrder() async throws {
        let image = Self.makeImage(size: CGSize(width: 120, height: 80))
        let itemA = ClothingItem(label: "shirt", confidence: 0.9, boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2), imageSize: image.size)
        let itemB = ClothingItem(label: "pants", confidence: 0.8, boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.2, height: 0.2), imageSize: image.size)

        let requestA = CropRequest(originalImage: image, clothingItem: itemA)
        let requestB = CropRequest(originalImage: image, clothingItem: itemB)

        let mockRepository = MockImageCroppingRepository()
        let useCase = ImageCroppingUseCase(repository: mockRepository)

        let results = try await useCase.cropMultipleImages(from: [requestA, requestB])

        #expect(results.count == 2)
        #expect(results[0].sourceItem.label == "shirt")
        #expect(results[1].sourceItem.label == "pants")
        #expect(mockRepository.capturedRequests.count == 2)
        #expect(mockRepository.capturedRequests[0].clothingItem.label == "shirt")
        #expect(mockRepository.capturedRequests[1].clothingItem.label == "pants")
    }

    @Test
    func cropMultipleImagesPropagatesRepositoryError() async {
        let image = Self.makeImage(size: CGSize(width: 100, height: 100))
        let item = ClothingItem(label: "coat", confidence: 0.7, boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3), imageSize: image.size)
        let request = CropRequest(originalImage: image, clothingItem: item)

        let mockRepository = MockImageCroppingRepository()
        mockRepository.errorToThrow = ClothingDetectionError.imageProcessingFailed
        let useCase = ImageCroppingUseCase(repository: mockRepository)

        do {
            _ = try await useCase.cropMultipleImages(from: [request])
            Issue.record("Expected an error to be thrown")
        } catch {
            #expect(error is ClothingDetectionError)
        }
    }

    private static func makeImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

private final class MockImageCroppingRepository: ImageCroppingRepositoryProtocol {
    var capturedRequests: [CropRequest] = []
    var errorToThrow: Error?

    func cropImage(from request: CropRequest) async throws -> CroppedImage {
        capturedRequests.append(request)

        if let errorToThrow {
            throw errorToThrow
        }

        return CroppedImage(
            image: request.originalImage,
            sourceItem: request.clothingItem,
            cropRect: CGRect(origin: .zero, size: request.originalImage.size)
        )
    }
}
#endif
