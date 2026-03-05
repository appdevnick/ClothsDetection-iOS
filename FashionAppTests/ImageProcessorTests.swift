import Foundation
import Testing
import UIKit
@testable import FashionApp

struct ImageProcessorTests {
    @Test
    func downscaleImageReducesLargestDimensionToLimit() {
        let source = Self.makeImage(size: CGSize(width: 2000, height: 1000))

        let downscaled = ImageProcessor.downscaleImage(source, maxDimension: 640)

        #expect(downscaled != nil)
        #expect(downscaled?.size.width == 640)
        #expect(downscaled?.size.height == 320)
    }

    @Test
    func downscaleImageDoesNotUpscaleSmallImage() {
        let source = Self.makeImage(size: CGSize(width: 120, height: 80))

        let downscaled = ImageProcessor.downscaleImage(source, maxDimension: 640)

        #expect(downscaled != nil)
        #expect(downscaled?.size.width == 120)
        #expect(downscaled?.size.height == 80)
    }

    private static func makeImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
