import CoreGraphics

enum SelectionHandle: Equatable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
    case inside
}

enum SelectionGeometry {
    static let minimumSize: CGFloat = 6
    private static let defaultTolerance: CGFloat = 8

    static func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(start.x - end.x),
            height: abs(start.y - end.y)
        )
    }

    static func isValid(_ rect: CGRect) -> Bool {
        rect.width >= minimumSize && rect.height >= minimumSize
    }

    static func hitHandle(in rect: CGRect, point: CGPoint, tolerance: CGFloat = defaultTolerance) -> SelectionHandle? {
        guard rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point) else {
            return nil
        }

        let nearLeft = abs(point.x - rect.minX) <= tolerance
        let nearRight = abs(point.x - rect.maxX) <= tolerance
        let nearBottom = abs(point.y - rect.minY) <= tolerance
        let nearTop = abs(point.y - rect.maxY) <= tolerance

        switch (nearLeft, nearRight, nearBottom, nearTop) {
        case (true, false, false, true): return .topLeft
        case (false, true, false, true): return .topRight
        case (false, true, true, false): return .bottomRight
        case (true, false, true, false): return .bottomLeft
        case (false, false, false, true): return .top
        case (false, true, false, false): return .right
        case (false, false, true, false): return .bottom
        case (true, false, false, false): return .left
        default:
            return rect.contains(point) ? .inside : nil
        }
    }

    static func resizedRect(
        _ rect: CGRect,
        dragging handle: SelectionHandle,
        to point: CGPoint,
        bounds: CGRect
    ) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        let clampedPoint = CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )

        switch handle {
        case .topLeft:
            minX = min(clampedPoint.x, maxX - minimumSize)
            maxY = max(clampedPoint.y, minY + minimumSize)
        case .top:
            maxY = max(clampedPoint.y, minY + minimumSize)
        case .topRight:
            maxX = max(clampedPoint.x, minX + minimumSize)
            maxY = max(clampedPoint.y, minY + minimumSize)
        case .right:
            maxX = max(clampedPoint.x, minX + minimumSize)
        case .bottomRight:
            maxX = max(clampedPoint.x, minX + minimumSize)
            minY = min(clampedPoint.y, maxY - minimumSize)
        case .bottom:
            minY = min(clampedPoint.y, maxY - minimumSize)
        case .bottomLeft:
            minX = min(clampedPoint.x, maxX - minimumSize)
            minY = min(clampedPoint.y, maxY - minimumSize)
        case .left:
            minX = min(clampedPoint.x, maxX - minimumSize)
        case .inside:
            return rect
        }

        return clampedRect(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY), bounds: bounds)
    }

    static func movedRect(_ rect: CGRect, by delta: CGPoint, bounds: CGRect) -> CGRect {
        var moved = rect.offsetBy(dx: delta.x, dy: delta.y)
        if moved.minX < bounds.minX {
            moved.origin.x = bounds.minX
        }
        if moved.maxX > bounds.maxX {
            moved.origin.x = bounds.maxX - moved.width
        }
        if moved.minY < bounds.minY {
            moved.origin.y = bounds.minY
        }
        if moved.maxY > bounds.maxY {
            moved.origin.y = bounds.maxY - moved.height
        }
        return moved
    }

    static func clampedRect(_ rect: CGRect, bounds: CGRect) -> CGRect {
        rect.intersection(bounds)
    }

    static func intersectionArea(of lhs: CGRect, with rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else {
            return 0
        }
        return intersection.width * intersection.height
    }

    static func handlePoints(for rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.midY)
        ]
    }
}
