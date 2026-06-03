import AppKit

enum ImageRenderContext {
    static func renderCopy(of image: NSImage, drawing: () -> Void) -> NSImage {
        let pointSize = image.size
        guard pointSize.width > 0, pointSize.height > 0 else {
            return image
        }

        let pixelSize = pixelDimensions(for: image)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize.width,
            pixelsHigh: pixelSize.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return legacyRenderCopy(of: image, drawing: drawing)
        }

        bitmap.size = pointSize
        context.imageInterpolation = .high
        context.shouldAntialias = true

        let output = NSImage(size: pointSize)
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = context
        context.cgContext.saveGState()
        context.cgContext.scaleBy(
            x: CGFloat(pixelSize.width) / pointSize.width,
            y: CGFloat(pixelSize.height) / pointSize.height
        )
        image.draw(
            in: CGRect(origin: .zero, size: pointSize),
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        drawing()
        context.cgContext.restoreGState()
        NSGraphicsContext.current = previous

        output.addRepresentation(bitmap)
        return output
    }

    private static func legacyRenderCopy(of image: NSImage, drawing: () -> Void) -> NSImage {
        let output = NSImage(size: image.size)
        output.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: image.size))
        drawing()
        output.unlockFocus()
        return output
    }

    private static func pixelDimensions(for image: NSImage) -> (width: Int, height: Int) {
        if let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).max(by: {
            $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh
        }) {
            return (
                max(1, bitmap.pixelsWide),
                max(1, bitmap.pixelsHigh)
            )
        }

        var proposedRect = CGRect(origin: .zero, size: image.size)
        if let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            return (
                max(1, cgImage.width),
                max(1, cgImage.height)
            )
        }

        return (
            max(1, Int(ceil(image.size.width))),
            max(1, Int(ceil(image.size.height)))
        )
    }
}
