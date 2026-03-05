import Foundation
import Testing
import UIKit
@testable import FashionApp

struct ImageCroppingUseCaseTests {
    @Test
    func cropMultipleImagesReturnsResultsInInputOrder() async throws {
        let image = TestImageFactory.makeSolidImage(size: CGSize(width: 120, height: 80), color: .systemBlue)
        let firstItem = ClothingItem(label: "shirt", confidence: 0.9, boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2), imageSize: image.size)
        let secondItem = ClothingItem(label: "pants", confidence: 0.8, boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.2, height: 0.2), imageSize: image.size)

        let repository = MockImageCroppingRepository()
        let useCase = ImageCroppingUseCase(repository: repository)

        let results = try await useCase.cropMultipleImages(from: [
            CropRequest(originalImage: image, clothingItem: firstItem),
            CropRequest(originalImage: image, clothingItem: secondItem)
        ])

        #expect(results.count == 2)
        #expect(results[0].sourceItem.label == "shirt")
        #expect(results[1].sourceItem.label == "pants")
        #expect(repository.capturedRequests.map { $0.clothingItem.label } == ["shirt", "pants"])
    }

    @Test
    func cropMultipleImagesPropagatesRepositoryErrors() async {
        let image = TestImageFactory.makeSolidImage(size: CGSize(width: 100, height: 100), color: .systemOrange)
        let item = ClothingItem(label: "coat", confidence: 0.7, boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3), imageSize: image.size)

        let repository = MockImageCroppingRepository()
        repository.errorToThrow = ClothingDetectionError.imageProcessingFailed
        let useCase = ImageCroppingUseCase(repository: repository)

        do {
            _ = try await useCase.cropMultipleImages(from: [CropRequest(originalImage: image, clothingItem: item)])
            Issue.record("Expected an error")
        } catch {
            #expect(error is ClothingDetectionError)
        }
    }
}

struct CoreImageCroppingDataSourceTests {
    @Test
    func cropImageClampsRectToImageBounds() async throws {
        let source = TestImageFactory.makeSolidImage(size: CGSize(width: 100, height: 100), color: .systemGreen)
        let item = ClothingItem(
            label: "bag",
            confidence: 0.95,
            boundingBox: CGRect(x: 0.85, y: 0.8, width: 0.3, height: 0.3),
            imageSize: source.size
        )

        let dataSource = CoreImageCroppingDataSource()
        let cropped = try await dataSource.cropImage(from: CropRequest(originalImage: source, clothingItem: item, padding: 20))

        #expect(!cropped.cropRect.isNull)
        #expect(cropped.cropRect.maxX <= source.size.width)
        #expect(cropped.cropRect.maxY <= source.size.height)
        #expect(cropped.image.size.width > 0)
        #expect(cropped.image.size.height > 0)
    }
}

struct BoundingBoxMapperTests {
    @Test
    func denormalizedRectConvertsFromVisionCoordinates() {
        let rect = BoundingBoxMapper.denormalizedRect(
            from: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            in: CGSize(width: 200, height: 100)
        )

        #expect(rect.origin.x == 50)
        #expect(rect.origin.y == 25)
        #expect(rect.width == 100)
        #expect(rect.height == 50)
    }

    @Test
    func clampedToImageBoundsReturnsNullForNonIntersectingRect() {
        let clamped = BoundingBoxMapper.clampedToImageBounds(
            CGRect(x: 200, y: 200, width: 20, height: 20),
            imageSize: CGSize(width: 100, height: 100)
        )

        #expect(clamped.isNull)
    }
}

private enum TestImageFactory {
    static func makeSolidImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
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
