import Testing
import UIKit
@testable import FashionApp

struct ImageProcessorTests {
    @Test
    func downscaleImageShrinksLargeLandscapeImageToMaxDimension() {
        let source = TestImageFactory.makeSolidImage(size: CGSize(width: 2000, height: 1000), color: .systemRed)

        let downscaled = ImageProcessor.downscaleImage(source, maxDimension: 640)

        #expect(downscaled != nil)
        #expect(downscaled?.size.width == 640)
        #expect(downscaled?.size.height == 320)
    }

    @Test
    func downscaleImageDoesNotUpscaleSmallImage() {
        let source = TestImageFactory.makeSolidImage(size: CGSize(width: 120, height: 80), color: .systemPink)

        let downscaled = ImageProcessor.downscaleImage(source, maxDimension: 640)

        #expect(downscaled != nil)
        #expect(downscaled?.size.width == 120)
        #expect(downscaled?.size.height == 80)
    }

    @Test
    func downscaleImagePreservesAspectRatioForPortraitImage() {
        let source = TestImageFactory.makeSolidImage(size: CGSize(width: 1000, height: 2000), color: .systemIndigo)

        let downscaled = ImageProcessor.downscaleImage(source, maxDimension: 500)

        #expect(downscaled != nil)
        #expect(downscaled?.size.width == 250)
        #expect(downscaled?.size.height == 500)
    }
}

private enum TestImageFactory {
    static func makeSolidImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
