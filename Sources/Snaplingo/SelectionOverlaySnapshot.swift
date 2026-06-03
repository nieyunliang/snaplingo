import AppKit

struct SelectionOverlaySnapshot {
    private let image: CGImage

    init?(screen: NSScreen) {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let image = CGDisplayCreateImage(CGDirectDisplayID(screenNumber.uint32Value))
        else {
            return nil
        }
        self.image = image
    }

    func croppedImage(around point: CGPoint, in bounds: CGRect, diameter: CGFloat, zoom: CGFloat) -> NSImage? {
        guard bounds.width > 0, bounds.height > 0, zoom > 0 else {
            return nil
        }

        let sourceSize = diameter / zoom
        let scaleX = CGFloat(image.width) / bounds.width
        let scaleY = CGFloat(image.height) / bounds.height
        let pixelRect = CGRect(
            x: (point.x - sourceSize / 2) * scaleX,
            y: (bounds.height - point.y - sourceSize / 2) * scaleY,
            width: sourceSize * scaleX,
            height: sourceSize * scaleY
        ).intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard !pixelRect.isNull,
              let cropped = image.cropping(to: pixelRect.integral)
        else {
            return nil
        }

        return NSImage(cgImage: cropped, size: CGSize(width: sourceSize, height: sourceSize))
    }
}
