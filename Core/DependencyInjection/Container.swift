import Foundation
import SwiftUI
import SwiftData

// MARK: - Dependency Injection Container

class DIContainer {
    static let shared = DIContainer()
    
    private init() {}
    
    // MARK: - Data Sources
    private lazy var clothingDetectionDataSource: ClothingDetectionDataSourceProtocol = {
        do {
            return try VisionClothingDetectionDataSource()
        } catch {
            fatalError("Failed to initialize clothing detection data source: \(error)")
        }
    }()
    
    // MARK: - Repositories
    private lazy var clothingDetectionRepository: ClothingDetectionRepositoryProtocol = {
        return ClothingDetectionRepository(dataSource: clothingDetectionDataSource)
    }()
    
    // MARK: - Use Cases
    private lazy var clothingDetectionUseCase: ClothingDetectionUseCaseProtocol = {
        return ClothingDetectionUseCase(repository: clothingDetectionRepository)
    }()
    
    private lazy var imageCroppingUseCase: ImageCroppingUseCaseProtocol = {
        return ImageCroppingUseCase(repository: imageCroppingRepository)
    }()
    
    // MARK: - Cropping Dependencies
    private lazy var imageCroppingDataSource: ImageCroppingDataSourceProtocol = {
        return CoreImageCroppingDataSource()
    }()
    
    private lazy var imageCroppingRepository: ImageCroppingRepositoryProtocol = {
        return ImageCroppingRepository(dataSource: imageCroppingDataSource)
    }()
    
    // MARK: - View Models
    @MainActor func makeClothingDetectionViewModel(modelContext: ModelContext) -> ClothingDetectionViewModel {
        let clothingItemRepository = SwiftDataClothingItemRepository(modelContext: modelContext)

        return ClothingDetectionViewModel(
            useCase: clothingDetectionUseCase,
            croppingUseCase: imageCroppingUseCase,
            clothingItemRepository: clothingItemRepository
        )
    }
    
    // MARK: - Views
    @MainActor func makeClothingDetectionView(modelContext: ModelContext) -> ClothingDetectionView {
        let viewModel = makeClothingDetectionViewModel(modelContext: modelContext)
        return ClothingDetectionView(viewModel: viewModel)
    }
}

// MARK: - Environment Key

struct DIContainerKey: EnvironmentKey {
    static let defaultValue = DIContainer.shared
}

extension EnvironmentValues {
    var container: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}
