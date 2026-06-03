import AppKit
import CoreGraphics

@MainActor
final class SelectionOverlayController {
    private var windows: [SelectionOverlayWindow] = []
    private var completion: ((CaptureRequest?) -> Void)?

    func beginSelection(candidates: [WindowCaptureCandidate], completion: @escaping (CaptureRequest?) -> Void) {
        self.completion = completion
        let primaryFrame = NSScreen.primaryFrame
        windows = NSScreen.screens.compactMap { screen in
            guard let displayID = screen.displayID else {
                return nil
            }
            let window = SelectionOverlayWindow(
                screen: screen,
                displayID: displayID,
                primaryFrame: primaryFrame,
                candidates: candidates
            )
            window.onComplete = { [weak self] selection in
                self?.finish(selection)
            }
            return window
        }

        for window in windows {
            window.makeKeyAndOrderFront(nil)
        }
        NSCursor.crosshair.push()
    }

    private func finish(_ request: CaptureRequest?) {
        NSCursor.pop()
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        let completion = completion
        self.completion = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            completion?(request)
        }
    }
}

final class SelectionOverlayWindow: NSWindow {
    var onComplete: ((CaptureRequest?) -> Void)?

    init(
        screen: NSScreen,
        displayID: CGDirectDisplayID,
        primaryFrame: CGRect,
        candidates: [WindowCaptureCandidate]
    ) {
        let screenRect = screen.frame
        super.init(contentRect: screenRect, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(screenRect, display: false)
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = SelectionOverlayView(
            frame: CGRect(origin: .zero, size: screenRect.size),
            screenFrame: screenRect,
            displayID: displayID,
            primaryFrame: primaryFrame,
            candidates: candidates,
            snapshot: SelectionOverlaySnapshot(screen: screen)
        ) { [weak self] request in
            self?.onComplete?(request)
        }
    }

    override var canBecomeKey: Bool { true }
}

final class SelectionOverlayView: NSView {
    private static let dragThreshold: CGFloat = 4

    private let screenFrame: CGRect
    private let displayID: CGDirectDisplayID
    private let primaryFrame: CGRect
    private let candidates: [WindowCaptureCandidate]
    private let snapshot: SelectionOverlaySnapshot?
    private let completion: (CaptureRequest?) -> Void
    private var trackingArea: NSTrackingArea?
    private var hovered: WindowCaptureCandidate?
    private var mouseLocation: CGPoint?
    private var selection: CGRect?
    private var dragMode: SelectionDragMode?

    init(
        frame frameRect: CGRect,
        screenFrame: CGRect,
        displayID: CGDirectDisplayID,
        primaryFrame: CGRect,
        candidates: [WindowCaptureCandidate],
        snapshot: SelectionOverlaySnapshot?,
        completion: @escaping (CaptureRequest?) -> Void
    ) {
        self.screenFrame = screenFrame
        self.displayID = displayID
        self.primaryFrame = primaryFrame
        self.candidates = candidates
        self.snapshot = snapshot
        self.completion = completion
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = clamped(convert(event.locationInWindow, from: nil))
        mouseLocation = point
        hovered = selection == nil ? candidate(at: point) : nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = clamped(convert(event.locationInWindow, from: nil))
        mouseLocation = point
        hovered = nil
        if let selection,
           let handle = SelectionGeometry.hitHandle(in: selection, point: point) {
            dragMode = .adjusting(selection: selection, handle: handle, startPoint: point)
        } else {
            dragMode = .drawing(startPoint: point)
            selection = nil
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragMode else {
            return
        }
        let point = clamped(convert(event.locationInWindow, from: nil))
        mouseLocation = point
        switch dragMode {
        case .drawing(let startPoint):
            if CaptureGestureResolver.isRegionDrag(from: startPoint, to: point, threshold: Self.dragThreshold) {
                selection = SelectionGeometry.normalizedRect(from: startPoint, to: point)
            }
        case .adjusting(let initialSelection, let handle, let startPoint):
            if handle == .inside {
                selection = SelectionGeometry.movedRect(
                    initialSelection,
                    by: CGPoint(x: point.x - startPoint.x, y: point.y - startPoint.y),
                    bounds: bounds
                )
            } else {
                selection = SelectionGeometry.resizedRect(
                    initialSelection,
                    dragging: handle,
                    to: point,
                    bounds: bounds
                )
            }
            hovered = nil
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = clamped(convert(event.locationInWindow, from: nil))
        mouseLocation = point
        defer {
            dragMode = nil
            needsDisplay = true
        }

        if let selection, SelectionGeometry.isValid(selection) {
            completeRegion(selection)
            return
        }

        if let candidate = candidate(at: point) {
            completion(CaptureRequest(selection: .window(candidate)))
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            completion(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: CGRect) {
        SelectionOverlayRenderer.draw(
            dirtyRect,
            selection: selection,
            mouseLocation: mouseLocation,
            snapshot: snapshot,
            bounds: bounds
        )
        guard selection == nil, let hovered else {
            return
        }
        let rect = localRect(for: hovered.appKitFrame(primaryFrame: primaryFrame))
        NSGraphicsContext.current?.cgContext.clear(rect)
        NSColor.systemBlue.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        NSColor.systemBlue.setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        border.lineWidth = 3
        border.stroke()
    }

    private func candidate(at point: CGPoint) -> WindowCaptureCandidate? {
        let screenPoint = CGPoint(x: point.x + screenFrame.minX, y: point.y + screenFrame.minY)
        return WindowCaptureCandidateResolver.candidate(at: screenPoint, candidates: candidates, primaryFrame: primaryFrame)
    }

    private func localRect(for screenRect: CGRect) -> CGRect {
        screenRect.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    private func completeRegion(_ selection: CGRect) {
        let appKitRect = window?.convertToScreen(selection) ?? selection.offsetBy(dx: screenFrame.minX, dy: screenFrame.minY)
        completion(
            CaptureRequest(
                selection: .region(displayID: displayID, appKitRect: appKitRect)
            )
        )
    }
}

private enum SelectionDragMode {
    case drawing(startPoint: CGPoint)
    case adjusting(selection: CGRect, handle: SelectionHandle, startPoint: CGPoint)
}

enum CaptureGestureResolver {
    static func isRegionDrag(from start: CGPoint, to end: CGPoint, threshold: CGFloat = 4) -> Bool {
        hypot(end.x - start.x, end.y - start.y) >= threshold
    }
}

enum WindowCaptureCandidateResolver {
    static func candidate(
        at appKitPoint: CGPoint,
        candidates: [WindowCaptureCandidate],
        primaryFrame: CGRect
    ) -> WindowCaptureCandidate? {
        candidates.first { candidate in
            candidate.appKitFrame(primaryFrame: primaryFrame).contains(appKitPoint)
        }
    }
}

extension NSScreen {
    static var primaryFrame: CGRect {
        screens.first(where: { $0.frame.origin == .zero })?.frame ?? main?.frame ?? .zero
    }

    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}
