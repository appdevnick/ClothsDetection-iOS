import Foundation
import SwiftUI
import PhotosUI
import UIKit

// MARK: - View State

enum ClothingDetectionViewState {
    case idle
    case loading
    case loaded(DetectionResult)
    case error(ClothingDetectionError)
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
    @Published var detectionResult: DetectionResult?
    @Published var croppedImages: [CroppedImage] = []
    @Published var selectedClothingItem: ClothingItem?
    @Published var isCropping: Bool = false

    // MARK: - Private Properties
    private let useCase: ClothingDetectionUseCaseProtocol
    private let croppingUseCase: ImageCroppingUseCaseProtocol
    private var selectionTask: Task<Void, Never>?

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
    init(useCase: ClothingDetectionUseCaseProtocol, croppingUseCase: ImageCroppingUseCaseProtocol) {
        self.useCase = useCase
        self.croppingUseCase = croppingUseCase
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

            selectedImage = downscaledImage
            await performDetection(on: downscaledImage)
        } catch {
            guard !Task.isCancelled else { return }
            viewState = .error(.imageProcessingFailed)
        }
    }

    private func performDetection(on image: UIImage) async {
        viewState = .loading

        do {
            let request = ImageProcessingRequest(image: image)
            let result = try await useCase.detectClothing(in: request)
            viewState = .loaded(result)
            detectionResult = result
        } catch let error as ClothingDetectionError {
            viewState = .error(error)
        } catch {
            viewState = .error(.detectionFailed(error.localizedDescription))
        }
    }

    // MARK: - Public Methods
    func clearResults() {
        selectionTask?.cancel()
        viewState = .idle
        selectedImage = nil
        selectedItem = nil
        detectionResult = nil
        croppedImages = []
        selectedClothingItem = nil
    }

    func retryDetection() {
        guard let image = selectedImage else { return }
        Task {
            await performDetection(on: image)
        }
    }

    func selectClothingItem(_ item: ClothingItem) {
        selectedClothingItem = item
    }

    func cropSelectedItem() {
        guard let image = selectedImage,
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
        guard let image = selectedImage else { return }

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
}
