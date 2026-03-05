import CoreGraphics

/// Converts Vision's normalized bounding boxes into image/view coordinates.
enum BoundingBoxMapper {
    static func denormalizedRect(
        from normalizedBoundingBox: CGRect,
        in size: CGSize,
        padding: CGFloat = 0,
        integral: Bool = false
    ) -> CGRect {
        var rect = CGRect(
            x: normalizedBoundingBox.origin.x * size.width - padding,
            y: (1 - normalizedBoundingBox.origin.y - normalizedBoundingBox.size.height) * size.height - padding,
            width: normalizedBoundingBox.size.width * size.width + (padding * 2),
            height: normalizedBoundingBox.size.height * size.height + (padding * 2)
        )

        if integral {
            rect = rect.integral
        }

        return rect
    }

    static func clampedToImageBounds(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        let bounds = CGRect(origin: .zero, size: imageSize)
        let clamped = rect.intersection(bounds)

        guard !clamped.isNull, clamped.width > 0, clamped.height > 0 else {
            return .null
        }

        return clamped
    }
}
