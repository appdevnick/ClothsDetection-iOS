import Foundation
import UIKit

// MARK: - Image Processing Utilities

class ImageProcessor {
    static func downscaleImage(_ image: UIImage, maxDimension: CGFloat = 640) -> UIImage? {
        let size = image.size
        let scaleFactor = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)

        // Use UIGraphicsImageRenderer to render a new UIImage at the target size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale // preserve original image scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let newImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return newImage
    }
    
}
