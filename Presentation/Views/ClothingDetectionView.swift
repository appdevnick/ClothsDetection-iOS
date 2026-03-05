import SwiftUI
import PhotosUI
import Photos

struct ClothingDetectionView: View {
    @StateObject private var viewModel: ClothingDetectionViewModel
    @State private var showingCroppedImages = false
    
    init(viewModel: ClothingDetectionViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            headerView

            savedItemsSection
            
            if viewModel.isLoading || viewModel.isCropping {
                loadingView
            } else {
                contentView
            }

            if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Clothing Detection")
        .sheet(isPresented: $showingCroppedImages) {
            NavigationStack {
                CroppedImagesView(
                    croppedImages: viewModel.croppedImages
                )
                .navigationTitle("Cropped Images")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(item: $viewModel.selectedSavedItemDetail, onDismiss: {
            viewModel.clearSavedItemDetail()
        }) { detail in
            NavigationStack {
                savedItemDetailView(detail)
            }
        }
        .task {
            await viewModel.loadSavedItems()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                PhotosPicker(
                    "Pick Image",
                    selection: $viewModel.selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                )
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading || viewModel.isCropping)
                
                if viewModel.selectedImage != nil {
                    Button("Clear Results") {
                        viewModel.clearResults()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Cropping controls
            if !viewModel.clothingItems.isEmpty {
                HStack(spacing: 12) {
                    Button("Crop All Items") {
                        viewModel.cropAllDetectedItems()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isCropping)
                    
                    if viewModel.selectedClothingItem != nil {
                        Button("Crop Selected") {
                            viewModel.cropSelectedItem()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isCropping)
                    }
                    
                    if !viewModel.croppedImages.isEmpty {
                        Button("View Cropped (\(viewModel.croppedImages.count))") {
                            showingCroppedImages = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            ProgressView(viewModel.isCropping ? "Cropping image..." : "Detecting clothing...")
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content View
    private var contentView: some View {
        Group {
            if let image = viewModel.selectedImage {
                imageView(image)
            } else {
                placeholderView
            }
        }
    }
    
    // MARK: - Saved Items Section
    private var savedItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Saved Items (\(viewModel.savedItems.count))")
                    .font(.headline)
                Spacer()
                if !viewModel.savedItems.isEmpty {
                    Button("Delete All (Debug)") {
                        Task {
                            await viewModel.deleteAllSavedItems()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

            if let statusMessage = viewModel.savedItemsStatusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if viewModel.savedItems.isEmpty {
                Text("No saved items yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.savedItems.prefix(12), id: \.id) { item in
                            Button {
                                Task {
                                    await viewModel.showSavedItemDetail(for: item)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    if let thumbnail = viewModel.savedItemThumbnails[item.id] {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 84, height: 84)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(width: 84, height: 84)
                                            .overlay {
                                                Image(systemName: "photo")
                                                    .foregroundColor(.secondary)
                                            }
                                    }

                                    Text(item.label)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Text(String(format: "%.0f%%", item.confidence * 100))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 100, alignment: .leading)
                                .padding(10)
                                .background(Color.gray.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if viewModel.isLoadingSavedItemDetail {
                ProgressView("Loading item details...")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func savedItemDetailView(_ detail: SavedItemDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(uiImage: detail.croppedImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)

                Group {
                    Text("Label: \(detail.item.label)")
                    Text(String(format: "Confidence: %.1f%%", detail.item.confidence * 100))
                    Text("Saved: \(detail.item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("Asset: \(detail.item.photoAssetIdentifier ?? "Unavailable")")
                }
                .font(.body)

                if detail.item.photoAssetIdentifier?.hasPrefix("unavailable:") != true {
                    Button("Open Full Photo") {
                        Task {
                            await viewModel.showSourcePhoto(for: detail.item)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if detail.isSourceUnavailable {
                    Text("Original photo source is unavailable. Showing placeholder preview.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Saved Item")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $viewModel.selectedSourcePhoto, onDismiss: {
            viewModel.clearSourcePhoto()
        }) { sourcePhoto in
            NavigationStack {
                sourcePhotoDetailView(sourcePhoto)
            }
        }
    }

    private func sourcePhotoDetailView(_ sourcePhoto: SourcePhotoDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Image(uiImage: sourcePhoto.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)

                Text("Asset: \(sourcePhoto.assetIdentifier)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Original Photo")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Image View
    private func imageView(_ image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .cornerRadius(12)
                .shadow(radius: 8)
            
            if !viewModel.clothingItems.isEmpty {
                DetectionBoxesOverlay(
                    items: viewModel.clothingItems,
                    selectedItem: viewModel.selectedClothingItem,
                    onItemTap: { item in
                        viewModel.selectClothingItem(item)
                    }
                )
            }
        }
        .overlay(
            detectionInfoOverlay,
            alignment: .topTrailing
        )
    }
    
    // MARK: - Placeholder View
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Select an image to detect clothing")
                .font(.title2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Detection Info Overlay
    private var detectionInfoOverlay: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if !viewModel.clothingItems.isEmpty {
                Text("\(viewModel.clothingItems.count) items detected")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.red)
            
            Text(message)
                .font(.body)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                viewModel.retryDetection()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}
