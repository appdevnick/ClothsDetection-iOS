import Foundation
import SwiftData
import CoreGraphics

// MARK: - Persisted Clothing Items Repository

protocol ClothingItemRepositoryProtocol {
    /// Persists detected items associated with a Photos asset.
    func saveDetectedItems(
        _ items: [ClothingItem],
        photoAssetIdentifier: String,
        createdAt: Date
    ) async throws

    /// Fetches all persisted clothing items.
    func fetchAllItems() async throws -> [ClothingItem]

    /// Deletes all persisted clothing items.
    func deleteAllItems() async throws
}

final class SwiftDataClothingItemRepository: ClothingItemRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func saveDetectedItems(
        _ items: [ClothingItem],
        photoAssetIdentifier: String,
        createdAt: Date
    ) async throws {
        for item in items {
            modelContext.insert(
                ClothingItemRecord(
                    id: item.id,
                    createdAt: createdAt,
                    photoAssetIdentifier: photoAssetIdentifier,
                    label: item.label,
                    confidence: item.confidence,
                    boundingBoxX: item.boundingBox.origin.x,
                    boundingBoxY: item.boundingBox.origin.y,
                    boundingBoxWidth: item.boundingBox.size.width,
                    boundingBoxHeight: item.boundingBox.size.height,
                    imageWidth: item.imageSize.width,
                    imageHeight: item.imageSize.height,
                    thumbnailData: item.thumbnailData
                )
            )
        }

        try modelContext.save()
    }

    func fetchAllItems() async throws -> [ClothingItem] {
        let descriptor = FetchDescriptor<ClothingItemRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let records = try modelContext.fetch(descriptor)
        return records.map(Self.mapToDomain)
    }

    func deleteAllItems() async throws {
        let descriptor = FetchDescriptor<ClothingItemRecord>()
        let records = try modelContext.fetch(descriptor)
        for record in records {
            modelContext.delete(record)
        }
        try modelContext.save()
    }
}

private extension SwiftDataClothingItemRepository {
    static func mapToDomain(_ record: ClothingItemRecord) -> ClothingItem {
        ClothingItem(
            id: record.id,
            label: record.label,
            confidence: record.confidence,
            boundingBox: CGRect(
                x: record.boundingBoxX,
                y: record.boundingBoxY,
                width: record.boundingBoxWidth,
                height: record.boundingBoxHeight
            ),
            imageSize: CGSize(width: record.imageWidth, height: record.imageHeight),
            createdAt: record.createdAt,
            photoAssetIdentifier: record.photoAssetIdentifier,
            thumbnailData: record.thumbnailData
        )
    }
}
