//
//  ContentView.swift
//  FashionApp
//
//  Created by User on 2026-03-05.
//

import SwiftUI
import Vision
import PhotosUI

struct ContentView: View {
    @State private var image: UIImage?
    @State private var detectedBoxes: [VNRectangleObservation] = []
    @State private var selectedBoxes: Set<Int> = []
    @State private var croppedImages: [UIImage] = []
    @State private var isShowingImagePicker = false
    @State private var isShowingCroppedResults = false
    
    private let imageCropper = ImageCropper()
    
    var body: some View {
        NavigationView {
            VStack {
                if let image {
                    GeometryReader { geo in
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                            
                            ForEach(detectedBoxes.indices, id: \.self) { index in
                                let box = detectedBoxes[index]
                                BoxView(box: box, imageSize: image.size, containerSize: geo.size)
                                    .onTapGesture {
                                        toggleSelection(index)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(selectedBoxes.contains(index) ? Color.red : Color.yellow, lineWidth: 3)
                                    )
                            }
                        }
                    }
                    .padding()
                    
                    if !detectedBoxes.isEmpty {
                        HStack {
                            Button("Crop Selected") {
                                cropSelected()
                            }
                            .disabled(selectedBoxes.isEmpty)
                            Spacer()
                            Button("Crop All") {
                                cropAll()
                            }
                        }
                        .padding([.horizontal, .bottom])
                    }
                } else {
                    Text("Pick an image to start")
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                Button("Pick Image") {
                    isShowingImagePicker = true
                }
                .padding(.bottom)
            }
            .navigationTitle("FashionApp")
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(image: $image, onDismiss: detectClothing)
            }
            .sheet(isPresented: $isShowingCroppedResults) {
                CroppedResultsView(images: croppedImages)
            }
        }
    }
    
    private func toggleSelection(_ index: Int) {
        if selectedBoxes.contains(index) {
            selectedBoxes.remove(index)
        } else {
            selectedBoxes.insert(index)
        }
    }
    
    private func detectClothing() {
        guard let image else { return }
        detectedBoxes.removeAll()
        selectedBoxes.removeAll()
        croppedImages.removeAll()
        
        let request = VNDetectHumanRectanglesRequest { request, error in
            if let results = request.results as? [VNHumanObservation] {
                DispatchQueue.main.async {
                    detectedBoxes = results.map { observation in
                        VNRectangleObservation(boundingBox: observation.boundingBox)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    detectedBoxes = []
                }
            }
        }
        
        guard let cgImage = image.cgImage else { return }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
    
    private func cropSelected() {
        guard let image else { return }
        let indexes = selectedBoxes.sorted()
        croppedImages = indexes.compactMap { idx in
            guard idx < detectedBoxes.count else { return nil }
            let box = detectedBoxes[idx]
            return imageCropper.crop(image: image, boundingBox: box.boundingBox)
        }
        isShowingCroppedResults = true
    }
    
    private func cropAll() {
        guard let image else { return }
        croppedImages = detectedBoxes.compactMap { box in
            imageCropper.crop(image: image, boundingBox: box.boundingBox)
        }
        isShowingCroppedResults = true
    }
}

struct BoxView: View {
    let box: VNRectangleObservation
    let imageSize: CGSize
    let containerSize: CGSize
    
    var body: some View {
        // VNBoundingBox is normalized with origin bottom-left, but SwiftUI coordinate system origin is top-left
        let rect = box.boundingBox
        let width = rect.size.width * containerSize.width
        let height = rect.size.height * containerSize.height
        let x = rect.origin.x * containerSize.width
        // Flip Y coordinate
        let y = (1 - rect.origin.y - rect.size.height) * containerSize.height
        
        return Rectangle()
            .frame(width: width, height: height)
            .position(x: x + width / 2, y: y + height / 2)
            .foregroundColor(.clear)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onDismiss: () -> Void

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else {
                parent.onDismiss()
                return
            }
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                        self.parent.onDismiss()
                    }
                }
            } else {
                parent.onDismiss()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}

struct CroppedResultsView: View {
    let images: [UIImage]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                    ForEach(images.indices, id: \.self) { idx in
                        Image(uiImage: images[idx])
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(8)
                            .shadow(radius: 4)
                    }
                }
                .padding()
            }
            .navigationTitle("Cropped Items")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

class ImageCropper {
    func crop(image: UIImage, boundingBox: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        // VN boundingBox origin is bottom-left, normalize to top-left
        let rect = CGRect(
            x: boundingBox.origin.x * width,
            y: (1 - boundingBox.origin.y - boundingBox.size.height) * height,
            width: boundingBox.size.width * width,
            height: boundingBox.size.height * height
        ).integral
        
        guard let croppedCgImage = cgImage.cropping(to: rect) else { return nil }
        return UIImage(cgImage: croppedCgImage)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
