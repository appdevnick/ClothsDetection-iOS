import Foundation
import Testing
import UIKit
@testable import FashionApp

@MainActor
struct ClothingDetectionViewModelTests {
    @Test
    func detectClothingPersistsItemsAndFallsBackToUnavailableIdentifier() async {
        let image = TestImageFactory.makeSolidImage(size: CGSize(width: 320, height: 240), color: .systemTeal)
        let detectedItem = ClothingItem(
            id: UUID(),
            label: "shirt",
            confidence: 0.92,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            imageSize: image.size
        )

        let repository = SpyClothingItemRepository()
        let viewModel = ClothingDetectionViewModel(
            useCase: MockDetectionUseCase(result: DetectionResult(items: [detectedItem], processingTime: 0.01, imageSize: image.size)),
            croppingUseCase: MockCroppingUseCase(),
            clothingItemRepository: repository
        )

        await viewModel.detectClothing(in: image, photoAssetIdentifier: nil)

        guard case .loaded = viewModel.viewState else {
            Issue.record("Expected loaded state")
            return
        }

        #expect(repository.savedCalls.count == 1)
        #expect(repository.savedCalls.first?.photoAssetIdentifier.hasPrefix("unavailable:") == true)
        #expect(repository.savedCalls.first?.items.first?.thumbnailData != nil)
        #expect(viewModel.savedItems.count == 1)
    }

    @Test
    func loadSavedItemsSetsStatusMessageWhenRepositoryFails() async {
        let repository = SpyClothingItemRepository()
        repository.fetchError = ClothingDetectionError.imageProcessingFailed

        let viewModel = ClothingDetectionViewModel(
            useCase: MockDetectionUseCase(result: DetectionResult(items: [], processingTime: 0, imageSize: CGSize(width: 10, height: 10))),
            croppingUseCase: MockCroppingUseCase(),
            clothingItemRepository: repository
        )

        await viewModel.loadSavedItems()

        #expect(viewModel.savedItemsStatusMessage == "Saved items are temporarily unavailable.")
    }

    @Test
    func cropSelectedItemUsesOriginalImageResolutionWhenAvailable() async {
        let downscaledImage = TestImageFactory.makeSolidImage(size: CGSize(width: 320, height: 240), color: .systemIndigo)
        let originalImage = TestImageFactory.makeSolidImage(size: CGSize(width: 1920, height: 1440), color: .systemTeal)
        let selectedItem = ClothingItem(
            id: UUID(),
            label: "shirt",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            imageSize: downscaledImage.size
        )
        let repository = SpyClothingItemRepository()
        let croppingUseCase = MockCroppingUseCase()
        let viewModel = ClothingDetectionViewModel(
            useCase: MockDetectionUseCase(result: DetectionResult(items: [selectedItem], processingTime: 0.01, imageSize: downscaledImage.size)),
            croppingUseCase: croppingUseCase,
            clothingItemRepository: repository
        )

        viewModel.setImagesForTesting(displayImage: downscaledImage, originalImage: originalImage)
        viewModel.selectClothingItem(selectedItem)
        viewModel.cropSelectedItem()

        // Allow async task in cropSelectedItem to run.
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(croppingUseCase.capturedCropRequests.count == 1)
        #expect(croppingUseCase.capturedCropRequests[0].originalImage.size == originalImage.size)
        #expect(croppingUseCase.capturedCropRequests[0].clothingItem.id == selectedItem.id)
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

private final class MockDetectionUseCase: ClothingDetectionUseCaseProtocol {
    let result: DetectionResult

    init(result: DetectionResult) {
        self.result = result
    }

    func detectClothing(in request: ImageProcessingRequest) async throws -> DetectionResult {
        result
    }
}

private final class MockCroppingUseCase: ImageCroppingUseCaseProtocol {
    var capturedCropRequests: [CropRequest] = []

    func cropImage(from request: CropRequest) async throws -> CroppedImage {
        capturedCropRequests.append(request)
        CroppedImage(image: request.originalImage, sourceItem: request.clothingItem, cropRect: .zero)
    }

    func cropMultipleImages(from requests: [CropRequest]) async throws -> [CroppedImage] {
        requests.map { CroppedImage(image: $0.originalImage, sourceItem: $0.clothingItem, cropRect: .zero) }
    }
}

private final class SpyClothingItemRepository: ClothingItemRepositoryProtocol {
    struct SaveCall {
        let items: [ClothingItem]
        let photoAssetIdentifier: String
        let createdAt: Date
    }

    var savedCalls: [SaveCall] = []
    var fetchResult: [ClothingItem] = []
    var fetchError: Error?

    func saveDetectedItems(_ items: [ClothingItem], photoAssetIdentifier: String, createdAt: Date) async throws {
        savedCalls.append(SaveCall(items: items, photoAssetIdentifier: photoAssetIdentifier, createdAt: createdAt))

        fetchResult = items.map {
            ClothingItem(
                id: $0.id,
                label: $0.label,
                confidence: $0.confidence,
                boundingBox: $0.boundingBox,
                imageSize: $0.imageSize,
                createdAt: createdAt,
                photoAssetIdentifier: photoAssetIdentifier,
                thumbnailData: $0.thumbnailData
            )
        }
    }

    func fetchAllItems() async throws -> [ClothingItem] {
        if let fetchError {
            throw fetchError
        }
        return fetchResult
    }

    func deleteAllItems() async throws {}
}
