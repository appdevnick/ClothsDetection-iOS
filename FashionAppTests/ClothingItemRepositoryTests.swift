import Foundation
import SwiftData
import Testing
import UIKit
@testable import FashionApp

@MainActor
struct ClothingItemRepositoryTests {
    @Test
    func saveAndFetchMapsPersistedFieldsAndSortsNewestFirst() async throws {
        let container = try makeInMemoryContainer()
        let repository = SwiftDataClothingItemRepository(modelContext: ModelContext(container))

        let older = ClothingItem(
            id: UUID(),
            label: "shirt",
            confidence: 0.81,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            imageSize: CGSize(width: 640, height: 480),
            thumbnailData: Data([0x01, 0x02])
        )
        let newer = ClothingItem(
            id: UUID(),
            label: "pants",
            confidence: 0.93,
            boundingBox: CGRect(x: 0.2, y: 0.1, width: 0.2, height: 0.5),
            imageSize: CGSize(width: 800, height: 600),
            thumbnailData: Data([0xAA, 0xBB])
        )

        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_800_000_000)

        try await repository.saveDetectedItems([older], photoAssetIdentifier: "asset-older", createdAt: olderDate)
        try await repository.saveDetectedItems([newer], photoAssetIdentifier: "asset-newer", createdAt: newerDate)

        let fetched = try await repository.fetchAllItems()

        #expect(fetched.count == 2)
        #expect(fetched.map(\.id) == [newer.id, older.id])
        #expect(fetched[0].createdAt == newerDate)
        #expect(fetched[1].createdAt == olderDate)
        #expect(fetched[0].photoAssetIdentifier == "asset-newer")
        #expect(fetched[1].photoAssetIdentifier == "asset-older")
        #expect(fetched[0].thumbnailData == Data([0xAA, 0xBB]))
        #expect(fetched[1].thumbnailData == Data([0x01, 0x02]))
        #expect(fetched[0].boundingBox == newer.boundingBox)
        #expect(fetched[1].boundingBox == older.boundingBox)
    }

    @Test
    func saveWithExistingIDUpdatesInsteadOfDuplicating() async throws {
        let container = try makeInMemoryContainer()
        let repository = SwiftDataClothingItemRepository(modelContext: ModelContext(container))

        let sharedID = UUID()
        let initial = ClothingItem(
            id: sharedID,
            label: "tshirt",
            confidence: 0.7,
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
            imageSize: CGSize(width: 320, height: 240)
        )
        let updated = ClothingItem(
            id: sharedID,
            label: "hoodie",
            confidence: 0.95,
            boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
            imageSize: CGSize(width: 1024, height: 768)
        )

        try await repository.saveDetectedItems([initial], photoAssetIdentifier: "asset-old", createdAt: .now)
        try await repository.saveDetectedItems([updated], photoAssetIdentifier: "asset-new", createdAt: .now)

        let fetched = try await repository.fetchAllItems()

        #expect(fetched.count == 1)
        #expect(fetched[0].id == sharedID)
        #expect(fetched[0].label == "hoodie")
        #expect(fetched[0].photoAssetIdentifier == "asset-new")
    }

    @Test
    func deleteAllRemovesPersistedItems() async throws {
        let container = try makeInMemoryContainer()
        let repository = SwiftDataClothingItemRepository(modelContext: ModelContext(container))

        let item = ClothingItem(
            id: UUID(),
            label: "coat",
            confidence: 0.88,
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3),
            imageSize: CGSize(width: 400, height: 400)
        )

        try await repository.saveDetectedItems([item], photoAssetIdentifier: "asset-1", createdAt: .now)
        try await repository.deleteAllItems()

        let fetched = try await repository.fetchAllItems()
        #expect(fetched.isEmpty)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ClothingItemRecord.self, configurations: configuration)
    }
}
