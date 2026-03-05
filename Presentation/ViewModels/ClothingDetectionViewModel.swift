import Foundation
import SwiftUI
import Photos
import PhotosUI
import UIKit

// MARK: - View State

enum ClothingDetectionViewState {
    case idle
    case loading
    case loaded(DetectionResult)
    case error(ClothingDetectionError)
}

struct SavedItemDetail: Identifiable {
    let id: UUID
    let item: ClothingItem
    let croppedImage: UIImage
    let isSourceUnavailable: Bool
}

struct SourcePhotoDetail: Identifiable {
    let id: UUID
    let image: UIImage
    let assetIdentifier: String
}

// MARK: - View Model

@MainActor
class ClothingDetectionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var viewState: ClothingDetectionViewState = .idle

    // When a new photo is selected, cancel prior work and start loading/detection for the latest item.
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            guard let selectedItem else { return }
            selectionTask?.cancel()
            selectionTask = Task { [weak self] in
                await self?.loadImage(from: selectedItem)
            }
        }
    }
    @Published var selectedImage: UIImage?
    @Published var savedItems: [ClothingItem] = []
    @Published var savedItemThumbnails: [UUID: UIImage] = [:]
    @Published var savedItemsStatusMessage: String?
    @Published var selectedSavedItemDetail: SavedItemDetail?
    @Published var selectedSourcePhoto: SourcePhotoDetail?
    @Published var isLoadingSavedItemDetail: Bool = false
    @Published var croppedImages: [CroppedImage] = []
    @Published var selectedClothingItem: ClothingItem?
    @Published var isCropping: Bool = false

    // MARK: - Private Properties
    private let useCase: ClothingDetectionUseCaseProtocol
    private let croppingUseCase: ImageCroppingUseCaseProtocol
    private let clothingItemRepository: ClothingItemRepositoryProtocol
    private var selectionTask: Task<Void, Never>?
    private var originalSelectedImage: UIImage?

    // MARK: - Computed Properties
    var clothingItems: [ClothingItem] {
        if case .loaded(let result) = viewState {
            return result.items
        }
        return []
    }

    var isLoading: Bool {
        if case .loading = viewState {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .error(let error) = viewState {
            return error.localizedDescription
        }
        return nil
    }

    // MARK: - Initialization
    init(
        useCase: ClothingDetectionUseCaseProtocol,
        croppingUseCase: ImageCroppingUseCaseProtocol,
        clothingItemRepository: ClothingItemRepositoryProtocol
    ) {
        self.useCase = useCase
        self.croppingUseCase = croppingUseCase
        self.clothingItemRepository = clothingItemRepository
    }

    deinit {
        selectionTask?.cancel()
    }

    // MARK: - Private Methods
    private func loadImage(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let downscaledImage = ImageProcessor.downscaleImage(uiImage) else {
                viewState = .error(.imageProcessingFailed)
                return
            }

            originalSelectedImage = uiImage
            selectedImage = downscaledImage
            await detectClothing(in: downscaledImage, photoAssetIdentifier: item.itemIdentifier)
        } catch {
            guard !Task.isCancelled else { return }
            viewState = .error(.imageProcessingFailed)
        }
    }

    func detectClothing(in image: UIImage, photoAssetIdentifier: String?) async {
        viewState = .loading

        do {
            let request = ImageProcessingRequest(image: image)
            let result = try await useCase.detectClothing(in: request)
            let itemsWithThumbnails = enrichItemsWithThumbnails(result.items, sourceImage: image)

            if !itemsWithThumbnails.isEmpty {
                let resolvedAssetIdentifier = photoAssetIdentifier ?? "unavailable:\(UUID().uuidString)"
                let createdAt = Date()
                try await clothingItemRepository.saveDetectedItems(
                    itemsWithThumbnails,
                    photoAssetIdentifier: resolvedAssetIdentifier,
                    createdAt: createdAt
                )
                let latestSavedItems = try await clothingItemRepository.fetchAllItems()
                savedItems = latestSavedItems
                await preloadThumbnails(for: latestSavedItems)
            }

            let updatedResult = DetectionResult(
                items: itemsWithThumbnails,
                processingTime: result.processingTime,
                imageSize: result.imageSize
            )
            viewState = .loaded(updatedResult)
        } catch let error as ClothingDetectionError {
            viewState = .error(error)
        } catch {
            viewState = .error(.detectionFailed(error.localizedDescription))
        }
    }

    // MARK: - Public Methods
    func loadSavedItems() async {
        do {
            let latestSavedItems = try await clothingItemRepository.fetchAllItems()
            savedItems = latestSavedItems
            savedItemsStatusMessage = nil
            await preloadThumbnails(for: latestSavedItems)
        } catch {
            // Keep detection flow errors separate from saved-items hydration errors.
            savedItemsStatusMessage = "Saved items are temporarily unavailable."
        }
    }

    func showSavedItemDetail(for item: ClothingItem) async {
        isLoadingSavedItemDetail = true
        defer { isLoadingSavedItemDetail = false }

        do {
            let croppedImage = try await loadCroppedImageForSavedItem(item)
            selectedSavedItemDetail = SavedItemDetail(
                id: item.id,
                item: item,
                croppedImage: croppedImage,
                isSourceUnavailable: false
            )
            savedItemsStatusMessage = nil
        } catch {
            let fallbackImage = item.thumbnailData.flatMap(UIImage.init(data:)) ?? placeholderSavedItemImage()
            selectedSavedItemDetail = SavedItemDetail(
                id: item.id,
                item: item,
                croppedImage: fallbackImage,
                isSourceUnavailable: true
            )
            savedItemsStatusMessage = "Some photo sources are unavailable."
        }
    }

    func clearSavedItemDetail() {
        selectedSavedItemDetail = nil
    }

    func showSourcePhoto(for item: ClothingItem) async {
        guard let assetIdentifier = item.photoAssetIdentifier,
              !assetIdentifier.hasPrefix("unavailable:") else {
            savedItemsStatusMessage = "Original photo source is unavailable."
            return
        }

        do {
            let sourceImage = try await loadSourceImageFromPhotos(assetIdentifier: assetIdentifier)
            selectedSourcePhoto = SourcePhotoDetail(
                id: item.id,
                image: sourceImage,
                assetIdentifier: assetIdentifier
            )
            savedItemsStatusMessage = nil
        } catch {
            savedItemsStatusMessage = "Unable to load original photo."
        }
    }

    func clearSourcePhoto() {
        selectedSourcePhoto = nil
    }

    func deleteAllSavedItems() async {
        do {
            try await clothingItemRepository.deleteAllItems()
            savedItems = []
            savedItemThumbnails = [:]
            selectedSavedItemDetail = nil
            selectedSourcePhoto = nil
            savedItemsStatusMessage = "Deleted all saved items."
        } catch {
            savedItemsStatusMessage = "Failed to delete saved items."
        }
    }

    func clearResults() {
        selectionTask?.cancel()
        viewState = .idle
        selectedImage = nil
        originalSelectedImage = nil
        selectedItem = nil
        croppedImages = []
        selectedClothingItem = nil
    }

    func retryDetection() {
        guard let image = selectedImage else { return }
        Task {
            await detectClothing(in: image, photoAssetIdentifier: nil)
        }
    }

    func selectClothingItem(_ item: ClothingItem) {
        selectedClothingItem = item
    }

    func cropSelectedItem() {
        guard let image = originalSelectedImage ?? selectedImage,
              let item = selectedClothingItem else { return }

        Task {
            isCropping = true
            defer { isCropping = false }

            do {
                let request = CropRequest(originalImage: image, clothingItem: item)
                let croppedImage = try await croppingUseCase.cropImage(from: request)
                croppedImages.append(croppedImage)
                selectedClothingItem = nil
            } catch let error as ClothingDetectionError {
                viewState = .error(error)
            } catch {
                viewState = .error(.imageProcessingFailed)
            }
        }
    }

    func cropAllDetectedItems() {
        guard let image = originalSelectedImage ?? selectedImage else { return }

        Task {
            isCropping = true
            defer { isCropping = false }

            do {
                let requests = clothingItems.map {
                    CropRequest(originalImage: image, clothingItem: $0)
                }
                let newCroppedImages = try await croppingUseCase.cropMultipleImages(from: requests)
                croppedImages.append(contentsOf: newCroppedImages)
            } catch let error as ClothingDetectionError {
                viewState = .error(error)
            } catch {
                viewState = .error(.imageProcessingFailed)
            }
        }
    }

    func removeCroppedImage(_ croppedImage: CroppedImage) {
        croppedImages.removeAll { $0.id == croppedImage.id }
    }

    func clearCroppedImages() {
        croppedImages = []
    }

    private func preloadThumbnails(for items: [ClothingItem]) async {
        for item in items {
            guard savedItemThumbnails[item.id] == nil else { continue }

            if let thumbnailData = item.thumbnailData,
               let persistedThumbnail = UIImage(data: thumbnailData) {
                savedItemThumbnails[item.id] = persistedThumbnail
                continue
            }

            if item.photoAssetIdentifier?.hasPrefix("unavailable:") == true {
                savedItemThumbnails[item.id] = placeholderSavedItemImage()
                continue
            }

            if let thumbnail = try? await loadCroppedImageForSavedItem(item) {
                savedItemThumbnails[item.id] = thumbnail
            } else {
                savedItemThumbnails[item.id] = placeholderSavedItemImage()
            }
        }
    }

    private func loadCroppedImageForSavedItem(_ item: ClothingItem) async throws -> UIImage {
        guard let assetIdentifier = item.photoAssetIdentifier,
              !assetIdentifier.hasPrefix("unavailable:") else {
            throw ClothingDetectionError.invalidImage
        }

        let sourceImage = try await loadSourceImageFromPhotos(assetIdentifier: assetIdentifier)
        let cropRequest = CropRequest(originalImage: sourceImage, clothingItem: item, padding: 0)
        let croppedImage = try await croppingUseCase.cropImage(from: cropRequest)
        return croppedImage.image
    }

    private func enrichItemsWithThumbnails(_ items: [ClothingItem], sourceImage: UIImage) -> [ClothingItem] {
        let thumbnailSourceImage = originalSelectedImage ?? sourceImage
        return items.map { item in
            let thumbnailData = makeThumbnailData(for: item, sourceImage: thumbnailSourceImage)
            return ClothingItem(
                id: item.id,
                label: item.label,
                confidence: item.confidence,
                boundingBox: item.boundingBox,
                imageSize: item.imageSize,
                createdAt: item.createdAt,
                photoAssetIdentifier: item.photoAssetIdentifier,
                thumbnailData: thumbnailData
            )
        }
    }

    private func makeThumbnailData(for item: ClothingItem, sourceImage: UIImage) -> Data? {
        let imageSize = sourceImage.size
        let cropRect = BoundingBoxMapper.denormalizedRect(
            from: item.boundingBox,
            in: imageSize,
            integral: true
        )

        let boundedRect = BoundingBoxMapper.clampedToImageBounds(cropRect, imageSize: imageSize)
        guard !boundedRect.isNull,
              boundedRect.width > 1,
              boundedRect.height > 1,
              let cgImage = sourceImage.cgImage,
              let croppedCGImage = cgImage.cropping(to: boundedRect) else {
            return nil
        }

        let croppedImage = UIImage(cgImage: croppedCGImage, scale: sourceImage.scale, orientation: sourceImage.imageOrientation)
        let thumbnail = renderSquareThumbnail(from: croppedImage, side: 144)
        return thumbnail.jpegData(compressionQuality: 0.65)
    }

    private func renderSquareThumbnail(from image: UIImage, side: CGFloat) -> UIImage {
        let targetSize = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            let sourceSize = image.size
            let scale = max(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
            let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            let origin = CGPoint(
                x: (targetSize.width - drawSize.width) / 2,
                y: (targetSize.height - drawSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }

    private func loadSourceImageFromPhotos(assetIdentifier: String) async throws -> UIImage {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = assets.firstObject else {
            throw ClothingDetectionError.invalidImage
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let isCancelled = info?[PHImageCancelledKey] as? Bool, isCancelled {
                    continuation.resume(throwing: ClothingDetectionError.imageProcessingFailed)
                    return
                }

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data, let image = UIImage(data: data) else {
                    continuation.resume(throwing: ClothingDetectionError.imageProcessingFailed)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func placeholderSavedItemImage() -> UIImage {
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let symbol = UIImage(systemName: "photo")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
            let symbolSize = CGSize(width: 36, height: 36)
            let symbolOrigin = CGPoint(
                x: (size.width - symbolSize.width) / 2,
                y: (size.height - symbolSize.height) / 2
            )
            symbol?.draw(in: CGRect(origin: symbolOrigin, size: symbolSize))
        }
    }

#if DEBUG
    func setImagesForTesting(displayImage: UIImage?, originalImage: UIImage?) {
        selectedImage = displayImage
        originalSelectedImage = originalImage
    }
#endif
}
