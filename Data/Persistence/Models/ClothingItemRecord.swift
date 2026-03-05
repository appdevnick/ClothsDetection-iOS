import Foundation
import SwiftData

@Model
final class ClothingItemRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var photoAssetIdentifier: String
    var label: String
    var confidence: Float
    var boundingBoxX: Double
    var boundingBoxY: Double
    var boundingBoxWidth: Double
    var boundingBoxHeight: Double
    var imageWidth: Double
    var imageHeight: Double
    var thumbnailData: Data?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        photoAssetIdentifier: String,
        label: String,
        confidence: Float,
        boundingBoxX: Double,
        boundingBoxY: Double,
        boundingBoxWidth: Double,
        boundingBoxHeight: Double,
        imageWidth: Double,
        imageHeight: Double,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.photoAssetIdentifier = photoAssetIdentifier
        self.label = label
        self.confidence = confidence
        self.boundingBoxX = boundingBoxX
        self.boundingBoxY = boundingBoxY
        self.boundingBoxWidth = boundingBoxWidth
        self.boundingBoxHeight = boundingBoxHeight
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.thumbnailData = thumbnailData
    }
}
