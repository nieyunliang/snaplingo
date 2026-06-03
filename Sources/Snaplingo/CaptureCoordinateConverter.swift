import CoreGraphics

enum CaptureCoordinateConverter {
    static func displaySpaceRect(fromAppKit rect: CGRect, primaryAppKitFrame: CGRect) -> CGRect {
        flippedRect(rect, primaryAppKitFrame: primaryAppKitFrame)
    }

    static func appKitRect(fromDisplaySpace rect: CGRect, primaryAppKitFrame: CGRect) -> CGRect {
        flippedRect(rect, primaryAppKitFrame: primaryAppKitFrame)
    }

    private static func flippedRect(_ rect: CGRect, primaryAppKitFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryAppKitFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func displayLocalRect(
        fromAppKit rect: CGRect,
        displaySpaceFrame: CGRect,
        primaryAppKitFrame: CGRect
    ) -> CGRect {
        displaySpaceRect(fromAppKit: rect, primaryAppKitFrame: primaryAppKitFrame)
            .offsetBy(dx: -displaySpaceFrame.minX, dy: -displaySpaceFrame.minY)
    }
}
