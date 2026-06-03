import AppKit

enum AnnotationRenderer {
    static func render(image: NSImage, annotations: [AnnotationItem]) -> NSImage {
        let output = NSImage(size: image.size)
        output.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: image.size))

        for annotation in annotations {
            draw(renderingAnnotation(annotation, imageSize: image.size))
        }

        output.unlockFocus()
        return output
    }

    static func drawPreview(_ annotation: AnnotationItem, in imageRect: CGRect, imageSize: CGSize) {
        let mapped = map(annotation, into: imageRect, imageSize: imageSize)
        draw(mapped)
    }

    private static func map(_ annotation: AnnotationItem, into imageRect: CGRect, imageSize: CGSize) -> AnnotationItem {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return annotation
        }
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        var copy = annotation
        copy.rect = CGRect(
            x: imageRect.minX + annotation.rect.minX * scaleX,
            y: imageRect.minY + annotation.rect.minY * scaleY,
            width: annotation.rect.width * scaleX,
            height: annotation.rect.height * scaleY
        )
        copy.arrowStart = annotation.arrowStart.map {
            CGPoint(x: imageRect.minX + $0.x * scaleX, y: imageRect.minY + $0.y * scaleY)
        }
        copy.arrowEnd = annotation.arrowEnd.map {
            CGPoint(x: imageRect.minX + $0.x * scaleX, y: imageRect.minY + $0.y * scaleY)
        }
        copy.lineWidth = max(1, annotation.lineWidth * min(scaleX, scaleY))
        return copy
    }

    private static func renderingAnnotation(_ annotation: AnnotationItem, imageSize: CGSize) -> AnnotationItem {
        var copy = annotation
        let rect = annotation.rect.standardized
        copy.rect = CGRect(
            x: rect.minX,
            y: imageSize.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        copy.arrowStart = annotation.arrowStart.map { CGPoint(x: $0.x, y: imageSize.height - $0.y) }
        copy.arrowEnd = annotation.arrowEnd.map { CGPoint(x: $0.x, y: imageSize.height - $0.y) }
        return copy
    }

    private static func draw(_ annotation: AnnotationItem) {
        let rect = annotation.rect.standardized
        guard rect.width > 1, rect.height > 1 else {
            return
        }

        switch annotation.tool {
        case .rectangle:
            stroke(rect, color: annotation.nsColor, width: annotation.lineWidth)
        case .circle:
            strokeCircle(rect, color: annotation.nsColor, width: annotation.lineWidth)
        case .arrow:
            drawArrow(
                from: annotation.arrowStart ?? CGPoint(x: rect.minX, y: rect.minY),
                to: annotation.arrowEnd ?? CGPoint(x: rect.maxX, y: rect.maxY),
                color: annotation.nsColor,
                width: annotation.lineWidth
            )
        }
    }

    private static func stroke(_ rect: CGRect, color: NSColor, width: CGFloat) {
        color.setStroke()
        let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        path.lineWidth = width
        path.stroke()
    }

    private static func strokeCircle(_ rect: CGRect, color: NSColor, width: CGFloat) {
        color.setStroke()
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = width
        path.stroke()
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor, width: CGFloat) {
        color.setStroke()
        color.setFill()

        let headLength: CGFloat = 14
        let headAngle: CGFloat = .pi / 7
        let shaftEnd = arrowShaftEnd(
            from: start,
            to: end,
            headLength: headLength,
            headAngle: headAngle,
            width: width
        )
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: shaftEnd)
        path.lineWidth = width
        path.lineCapStyle = .butt
        path.stroke()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let left = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let right = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )
        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: left)
        head.line(to: right)
        head.close()
        head.fill()
    }

    static func arrowShaftEnd(
        from start: CGPoint,
        to end: CGPoint,
        headLength: CGFloat,
        headAngle: CGFloat,
        width: CGFloat
    ) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 0 else {
            return start
        }

        let headBaseOffset = headLength * cos(headAngle)
        let inset = min(distance, max(width / 2, headBaseOffset - width))
        return CGPoint(
            x: end.x - inset * dx / distance,
            y: end.y - inset * dy / distance
        )
    }

}

private extension AnnotationItem {
    var nsColor: NSColor {
        NSColor(hex: colorHex) ?? .controlAccentColor
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else {
            return nil
        }
        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
