import AppKit

enum SelectionOverlayRenderer {
    static let selectionChromeLineWidth: CGFloat = 2

    private static let magnifierDiameter: CGFloat = 116
    private static let magnifierZoom: CGFloat = 3

    static func draw(
        _ dirtyRect: NSRect,
        selection: CGRect?,
        mouseLocation: CGPoint?,
        snapshot: SelectionOverlaySnapshot?,
        bounds: CGRect
    ) {
        NSColor.black.withAlphaComponent(0.45).setFill()
        dirtyRect.fill()

        if let selection {
            NSGraphicsContext.current?.cgContext.clear(selection)
        }

        drawMagnifierIfNeeded(mouseLocation: mouseLocation, snapshot: snapshot, bounds: bounds)
    }

    static func drawSelectionChrome(
        in selection: CGRect,
        showsFill: Bool = true,
        showsHandles: Bool = true,
        showsSizeLabel: Bool = true
    ) {
        if showsFill {
            NSColor.systemBlue.withAlphaComponent(0.18).setFill()
            selection.fill()
        }

        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: selection)
        path.lineWidth = selectionChromeLineWidth
        path.stroke()

        if showsHandles {
            drawHandles(for: selection)
        }

        if showsSizeLabel {
            drawSizeLabel(for: selection)
        }
    }

    private static func drawHandles(for rect: CGRect) {
        NSColor.systemBlue.setFill()
        for point in SelectionGeometry.handlePoints(for: rect) {
            let handleRect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            NSBezierPath(roundedRect: handleRect, xRadius: 2, yRadius: 2).fill()
        }
    }

    private static func drawSizeLabel(for selection: CGRect) {
        let label = "\(Int(selection.width)) x \(Int(selection.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.65)
        ]
        label.draw(
            at: CGPoint(x: selection.minX, y: max(selection.minY - 20, 8)),
            withAttributes: attributes
        )
    }

    private static func drawMagnifierIfNeeded(
        mouseLocation: CGPoint?,
        snapshot: SelectionOverlaySnapshot?,
        bounds: CGRect
    ) {
        guard let mouseLocation,
              bounds.contains(mouseLocation),
              let snapshot,
              let croppedImage = snapshot.croppedImage(
                  around: mouseLocation,
                  in: bounds,
                  diameter: magnifierDiameter,
                  zoom: magnifierZoom
              )
        else {
            return
        }

        let loupeRect = magnifierRect(around: mouseLocation, bounds: bounds)

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: loupeRect).addClip()
        croppedImage.draw(in: loupeRect)
        drawMagnifierCrosshair(in: loupeRect)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.96).setStroke()
        let border = NSBezierPath(ovalIn: loupeRect)
        border.lineWidth = 2
        border.stroke()
    }

    private static func magnifierRect(around mouseLocation: CGPoint, bounds: CGRect) -> CGRect {
        let offset = CGPoint(x: 22, y: 22)
        var loupeRect = CGRect(
            x: mouseLocation.x + offset.x,
            y: mouseLocation.y + offset.y,
            width: magnifierDiameter,
            height: magnifierDiameter
        )
        if loupeRect.maxX > bounds.maxX - 12 {
            loupeRect.origin.x = mouseLocation.x - magnifierDiameter - offset.x
        }
        if loupeRect.maxY > bounds.maxY - 12 {
            loupeRect.origin.y = mouseLocation.y - magnifierDiameter - offset.y
        }
        return loupeRect
    }

    private static func drawMagnifierCrosshair(in loupeRect: CGRect) {
        NSColor.systemBlue.withAlphaComponent(0.9).setStroke()
        let center = CGPoint(x: loupeRect.midX, y: loupeRect.midY)
        let horizontal = NSBezierPath()
        horizontal.move(to: CGPoint(x: center.x - 12, y: center.y))
        horizontal.line(to: CGPoint(x: center.x + 12, y: center.y))
        horizontal.stroke()

        let vertical = NSBezierPath()
        vertical.move(to: CGPoint(x: center.x, y: center.y - 12))
        vertical.line(to: CGPoint(x: center.x, y: center.y + 12))
        vertical.stroke()
    }
}
