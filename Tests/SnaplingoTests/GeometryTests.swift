import AppKit
import XCTest
@testable import Snaplingo

final class GeometryTests: XCTestCase {
    func testSelectionGeometrySupportsConfirmFirstResizeFlow() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let initial = SelectionGeometry.normalizedRect(
            from: CGPoint(x: 120, y: 160),
            to: CGPoint(x: 40, y: 80)
        )

        XCTAssertEqual(initial, CGRect(x: 40, y: 80, width: 80, height: 80))
        XCTAssertEqual(SelectionGeometry.hitHandle(in: initial, point: CGPoint(x: 120, y: 120)), .right)
        XCTAssertEqual(SelectionGeometry.hitHandle(in: initial, point: CGPoint(x: 80, y: 120)), .inside)

        let resized = SelectionGeometry.resizedRect(
            initial,
            dragging: .right,
            to: CGPoint(x: 180, y: 120),
            bounds: bounds
        )
        XCTAssertEqual(resized, CGRect(x: 40, y: 80, width: 140, height: 80))
        XCTAssertTrue(SelectionGeometry.isValid(resized))
    }

    func testSelectionGeometryKeepsMovedSelectionInsideBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 120)
        let moved = SelectionGeometry.movedRect(
            CGRect(x: 40, y: 30, width: 80, height: 50),
            by: CGPoint(x: 200, y: 100),
            bounds: bounds
        )

        XCTAssertEqual(moved, CGRect(x: 120, y: 70, width: 80, height: 50))
    }

    func testScreenshotToolbarMovesBesideTallSelectionInsteadOfOverlappingIt() {
        let selection = CGRect(x: 400, y: 0, width: 400, height: 900)
        let toolbar = ScreenshotToolbarLayout.frame(
            near: selection,
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            toolbarSize: CGSize(width: 314, height: 50)
        )

        XCTAssertEqual(toolbar, CGRect(x: 808, y: 425, width: 314, height: 50))
        XCTAssertFalse(toolbar.intersects(selection))
    }

    func testCaptureCoordinateConverterHandlesDisplaysAboveAndBelowPrimaryScreen() {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)

        XCTAssertEqual(
            CaptureCoordinateConverter.displaySpaceRect(
                fromAppKit: CGRect(x: 20, y: 700, width: 100, height: 80),
                primaryAppKitFrame: primary
            ),
            CGRect(x: 20, y: 120, width: 100, height: 80)
        )
        XCTAssertEqual(
            CaptureCoordinateConverter.displaySpaceRect(
                fromAppKit: CGRect(x: 40, y: -700, width: 120, height: 90),
                primaryAppKitFrame: primary
            ),
            CGRect(x: 40, y: 1510, width: 120, height: 90)
        )
    }

    func testCaptureCoordinateConverterProducesDisplayLocalRect() {
        let local = CaptureCoordinateConverter.displayLocalRect(
            fromAppKit: CGRect(x: 1500, y: 500, width: 120, height: 80),
            displaySpaceFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
            primaryAppKitFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        XCTAssertEqual(local, CGRect(x: 60, y: 320, width: 120, height: 80))
    }

    func testCaptureGestureResolverKeepsSmallMovementAsClick() {
        XCTAssertFalse(CaptureGestureResolver.isRegionDrag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 12, y: 12)))
        XCTAssertTrue(CaptureGestureResolver.isRegionDrag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 15, y: 10)))
    }

    @MainActor
    func testSelectionOverlayAcceptsTheFirstMouseEvent() {
        let view = SelectionOverlayView(
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            displayID: 0,
            primaryFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            candidates: [],
            snapshot: nil,
            completion: { _ in }
        )

        XCTAssertTrue(view.acceptsFirstMouse(for: nil))
    }

    @MainActor
    func testSelectionOverlayWaitsForToolbarActionAfterRegionDrag() throws {
        var completedRequest: CaptureRequest?
        let view = SelectionOverlayView(
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            displayID: 7,
            primaryFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            candidates: [],
            snapshot: nil,
            completion: { completedRequest = $0 }
        )

        view.mouseDown(with: try mouseEvent(type: .leftMouseDown, at: CGPoint(x: 10, y: 10)))
        view.mouseDragged(with: try mouseEvent(type: .leftMouseDragged, at: CGPoint(x: 60, y: 50)))
        view.mouseUp(with: try mouseEvent(type: .leftMouseUp, at: CGPoint(x: 60, y: 50)))

        XCTAssertNil(completedRequest)

        view.performAction(.copy)

        guard case .region(let displayID, let rect)? = completedRequest?.selection else {
            return XCTFail("Expected region capture request.")
        }
        XCTAssertEqual(displayID, 7)
        XCTAssertEqual(rect, CGRect(x: 10, y: 10, width: 50, height: 40))
    }

    @MainActor
    func testSelectionOverlayKeepsWindowCandidateWhenClickedWithoutDragging() throws {
        let candidate = WindowCaptureCandidate(
            id: 42,
            frame: CGRect(x: 20, y: 20, width: 40, height: 30)
        )
        var completedRequest: CaptureRequest?
        let view = SelectionOverlayView(
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            displayID: 7,
            primaryFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            candidates: [candidate],
            snapshot: nil,
            completion: { completedRequest = $0 }
        )

        view.mouseUp(with: try mouseEvent(type: .leftMouseUp, at: CGPoint(x: 30, y: 60)))
        view.mouseDown(with: try mouseEvent(type: .leftMouseDown, at: CGPoint(x: 30, y: 60)))
        view.mouseUp(with: try mouseEvent(type: .leftMouseUp, at: CGPoint(x: 30, y: 60)))
        view.performAction(.copy)

        guard case .window(let capturedCandidate)? = completedRequest?.selection else {
            return XCTFail("Expected window capture request.")
        }
        XCTAssertEqual(capturedCandidate.id, candidate.id)
    }

    @MainActor
    func testSelectionOverlayConvertsWindowCandidateToRegionAfterDraggingSelection() throws {
        let candidate = WindowCaptureCandidate(
            id: 42,
            frame: CGRect(x: 20, y: 20, width: 40, height: 30)
        )
        var completedRequest: CaptureRequest?
        let view = SelectionOverlayView(
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            displayID: 7,
            primaryFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            candidates: [candidate],
            snapshot: nil,
            completion: { completedRequest = $0 }
        )

        view.mouseUp(with: try mouseEvent(type: .leftMouseUp, at: CGPoint(x: 30, y: 60)))
        view.mouseDown(with: try mouseEvent(type: .leftMouseDown, at: CGPoint(x: 30, y: 60)))
        view.mouseDragged(with: try mouseEvent(type: .leftMouseDragged, at: CGPoint(x: 40, y: 60)))
        view.mouseUp(with: try mouseEvent(type: .leftMouseUp, at: CGPoint(x: 40, y: 60)))
        view.performAction(.copy)

        guard case .region(let displayID, let rect)? = completedRequest?.selection else {
            return XCTFail("Expected adjusted window selection to become a region capture request.")
        }
        XCTAssertEqual(displayID, 7)
        XCTAssertEqual(rect, CGRect(x: 30, y: 50, width: 40, height: 30))
    }

    func testWindowCaptureCandidateResolverUsesFrontmostEnumerationOrder() {
        let candidates = [
            WindowCaptureCandidate(
                id: 1,
                frame: CGRect(x: 20, y: 20, width: 200, height: 200)
            ),
            WindowCaptureCandidate(
                id: 2,
                frame: CGRect(x: 0, y: 0, width: 300, height: 300)
            )
        ]

        let candidate = WindowCaptureCandidateResolver.candidate(
            at: CGPoint(x: 100, y: 700),
            candidates: candidates,
            primaryFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        XCTAssertEqual(candidate?.id, 1)
    }

    private func mouseEvent(type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.mouseEvent(
                with: type,
                location: point,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
    }
}
