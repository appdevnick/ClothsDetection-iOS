import Foundation
import SwiftData
import Testing
import UIKit
@testable import FashionApp

@MainActor
struct ClothingItemRepositoryTests {
    @Test
    func saveDetectedItemsPersistsAndFetchesMappedDomainItems() async throws {
        let container = try makeInMemoryContainer()
        let repository = SwiftDataClothingItemRepository(modelContext: ModelContext(container))

        let first = ClothingItem(
            id: UUID(),
            label: "shirt",
            confidence: 0.91,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            imageSize: CGSize(width: 640, height: 480),
            thumbnailData: Data([0x11, 0x22, 0x33])
        )
        let second = ClothingItem(
            id: UUID(),
            label: "pants",
            confidence: 0.88,
            boundingBox: CGRect(x: 0.5, y: 0.1, width: 0.2, height: 0.5),
            imageSize: CGSize(width: 640, height: 480),
            thumbnailData: Data([0x44, 0x55, 0x66])
        )

        try await repository.saveDetectedItems(
            [first, second],
            photoAssetIdentifier: "asset-123",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let fetched = try await repository.fetchAllItems()

        #expect(fetched.count == 2)
        #expect(fetched.contains { $0.id == first.id && $0.label == "shirt" && $0.confidence == first.confidence })
        #expect(fetched.contains { $0.id == second.id && $0.label == "pants" && $0.confidence == second.confidence })
        #expect(fetched.contains { $0.boundingBox == first.boundingBox })
        #expect(fetched.contains { $0.boundingBox == second.boundingBox })
        #expect(fetched.allSatisfy { $0.imageSize == CGSize(width: 640, height: 480) })
        #expect(fetched.contains { $0.id == first.id && $0.thumbnailData == Data([0x11, 0x22, 0x33]) })
        #expect(fetched.contains { $0.id == second.id && $0.thumbnailData == Data([0x44, 0x55, 0x66]) })
    }

    @Test
    func deleteAllItemsRemovesPersistedRecords() async throws {
        let container = try makeInMemoryContainer()
        let repository = SwiftDataClothingItemRepository(modelContext: ModelContext(container))

        let item = ClothingItem(
            id: UUID(),
            label: "coat",
            confidence: 0.95,
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3),
            imageSize: CGSize(width: 500, height: 500)
        )

        try await repository.saveDetectedItems(
            [item],
            photoAssetIdentifier: "asset-xyz",
            createdAt: .now
        )
        try await repository.deleteAllItems()

        let fetched = try await repository.fetchAllItems()
        #expect(fetched.isEmpty)
    }

    @Test
    func saveDetectedItemsWithExistingIDUpdatesInsteadOfDuplicating() async throws {
        let container = try makeInMemoryContainer()
        let repository = SwiftDataClothingItemRepository(modelContext: ModelContext(container))

        let sharedID = UUID()
        let initialDate = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedDate = Date(timeIntervalSince1970: 1_800_000_000)

        let initial = ClothingItem(
            id: sharedID,
            label: "shirt",
            confidence: 0.7,
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
            imageSize: CGSize(width: 400, height: 400)
        )

        let updated = ClothingItem(
            id: sharedID,
            label: "tshirt",
            confidence: 0.95,
            boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
            imageSize: CGSize(width: 800, height: 600)
        )

        try await repository.saveDetectedItems(
            [initial],
            photoAssetIdentifier: "asset-old",
            createdAt: initialDate
        )

        try await repository.saveDetectedItems(
            [updated],
            photoAssetIdentifier: "asset-new",
            createdAt: updatedDate
        )

        let fetched = try await repository.fetchAllItems()

        #expect(fetched.count == 1)
        #expect(fetched[0].id == sharedID)
        #expect(fetched[0].label == "tshirt")
        #expect(fetched[0].confidence == 0.95)
        #expect(fetched[0].boundingBox == CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4))
        #expect(fetched[0].imageSize == CGSize(width: 800, height: 600))
        #expect(fetched[0].createdAt == updatedDate)
        #expect(fetched[0].photoAssetIdentifier == "asset-new")
    }

    @Test
    func fetchAllItemsReturnsNewestFirstAndIncludesPersistedMetadata() async throws {
        let container = try makeInMemoryContainer()
        let repository = SwiftDataClothingItemRepository(modelContext: ModelContext(container))

        let older = ClothingItem(
            id: UUID(),
            label: "older-item",
            confidence: 0.8,
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
            imageSize: CGSize(width: 200, height: 200)
        )
        let newer = ClothingItem(
            id: UUID(),
            label: "newer-item",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3),
            imageSize: CGSize(width: 300, height: 300)
        )

        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_800_000_000)

        try await repository.saveDetectedItems(
            [older],
            photoAssetIdentifier: "asset-older",
            createdAt: olderDate
        )
        try await repository.saveDetectedItems(
            [newer],
            photoAssetIdentifier: "asset-newer",
            createdAt: newerDate
        )

        let fetched = try await repository.fetchAllItems()
        #expect(fetched.map(\.label) == ["newer-item", "older-item"])
        #expect(fetched[0].createdAt == newerDate)
        #expect(fetched[0].photoAssetIdentifier == "asset-newer")
        #expect(fetched[1].createdAt == olderDate)
        #expect(fetched[1].photoAssetIdentifier == "asset-older")
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ClothingItemRecord.self, configurations: configuration)
    }
}

@MainActor
struct ClothingDetectionPersistenceFlowTests {
    @Test
    func detectClothingPersistsDetectedItemsWithAssetIdentifierAndTimestamp() async {
        let image = Self.makeImage(size: CGSize(width: 320, height: 240))
        let detectedItem = ClothingItem(
            id: UUID(),
            label: "shirt",
            confidence: 0.92,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            imageSize: image.size
        )
        let detectionResult = DetectionResult(items: [detectedItem], processingTime: 0.01, imageSize: image.size)
        let detectionUseCase = VMPTMockDetectionUseCase(result: detectionResult)
        let croppingUseCase = VMPTMockCroppingUseCase()
        let repository = VMPTSpyClothingItemRepository()

        let viewModel = ClothingDetectionViewModel(
            useCase: detectionUseCase,
            croppingUseCase: croppingUseCase,
            clothingItemRepository: repository
        )

        let startedAt = Date()
        await viewModel.detectClothing(in: image, photoAssetIdentifier: "asset-123")
        let endedAt = Date()

        #expect(repository.savedCalls.count == 1)
        let firstCall = repository.savedCalls.first
        #expect(firstCall != nil)

        if let firstCall {
            #expect(firstCall.photoAssetIdentifier == "asset-123")
            #expect(firstCall.createdAt >= startedAt)
            #expect(firstCall.createdAt <= endedAt)
            #expect(firstCall.items.map(\.id) == [detectedItem.id])
            #expect(firstCall.items.first?.thumbnailData != nil)
            #expect((firstCall.items.first?.thumbnailData?.isEmpty ?? true) == false)
        }
    }

    @Test
    func loadSavedItemsPopulatesSavedItemsState() async {
        let image = Self.makeImage(size: CGSize(width: 320, height: 240))
        let saved = ClothingItem(
            id: UUID(),
            label: "saved-item",
            confidence: 0.85,
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
            imageSize: image.size,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            photoAssetIdentifier: "asset-saved"
        )

        let detectionUseCase = VMPTMockDetectionUseCase(
            result: DetectionResult(items: [], processingTime: 0, imageSize: image.size)
        )
        let croppingUseCase = VMPTMockCroppingUseCase()
        let repository = VMPTSpyClothingItemRepository()
        repository.fetchResult = [saved]

        let viewModel = ClothingDetectionViewModel(
            useCase: detectionUseCase,
            croppingUseCase: croppingUseCase,
            clothingItemRepository: repository
        )

        await viewModel.loadSavedItems()

        #expect(viewModel.savedItems.count == 1)
        #expect(viewModel.savedItems[0].id == saved.id)
        #expect(viewModel.savedItems[0].photoAssetIdentifier == "asset-saved")
    }

    private static func makeImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

private final class VMPTMockDetectionUseCase: ClothingDetectionUseCaseProtocol {
    let result: DetectionResult

    init(result: DetectionResult) {
        self.result = result
    }

    func detectClothing(in request: ImageProcessingRequest) async throws -> DetectionResult {
        result
    }
}

private final class VMPTMockCroppingUseCase: ImageCroppingUseCaseProtocol {
    func cropImage(from request: CropRequest) async throws -> CroppedImage {
        CroppedImage(image: request.originalImage, sourceItem: request.clothingItem, cropRect: .zero)
    }

    func cropMultipleImages(from requests: [CropRequest]) async throws -> [CroppedImage] {
        requests.map { CroppedImage(image: $0.originalImage, sourceItem: $0.clothingItem, cropRect: .zero) }
    }
}

private final class VMPTSpyClothingItemRepository: ClothingItemRepositoryProtocol {
    struct SaveCall {
        let items: [ClothingItem]
        let photoAssetIdentifier: String
        let createdAt: Date
    }

    var savedCalls: [SaveCall] = []
    var fetchResult: [ClothingItem] = []

    func saveDetectedItems(_ items: [ClothingItem], photoAssetIdentifier: String, createdAt: Date) async throws {
        savedCalls.append(SaveCall(items: items, photoAssetIdentifier: photoAssetIdentifier, createdAt: createdAt))
    }

    func fetchAllItems() async throws -> [ClothingItem] {
        fetchResult
    }

    func deleteAllItems() async throws {}
}


