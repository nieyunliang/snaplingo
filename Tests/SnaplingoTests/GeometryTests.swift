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

        assertToolbarLayout(toolbar: toolbar, expected: CGRect(x: 808, y: 425, width: 314, height: 50), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), selection: selection)
    }

    func testScreenshotToolbarStaysInsideVisibleFrameWhenSelectionAtRightEdge() {
        let selection = CGRect(x: 1300, y: 100, width: 100, height: 100)
        let toolbar = ScreenshotToolbarLayout.frame(
            near: selection,
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            toolbarSize: CGSize(width: 314, height: 50)
        )

        // Toolbar goes above the selection when right edge is tight
        assertToolbarLayout(toolbar: toolbar, expected: CGRect(x: 1126, y: 42, width: 314, height: 50), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), selection: selection)
    }

    func testScreenshotToolbarStaysInsideVisibleFrameWhenSelectionAtBottom() {
        let selection = CGRect(x: 200, y: 800, width: 200, height: 80)
        let toolbar = ScreenshotToolbarLayout.frame(
            near: selection,
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            toolbarSize: CGSize(width: 314, height: 50)
        )

        // Toolbar goes above the selection when bottom space is tight
        assertToolbarLayout(toolbar: toolbar, expected: CGRect(x: 143, y: 742, width: 314, height: 50), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), selection: selection)
    }

    func testScreenshotToolbarClampsToLeftEdgeWhenSelectionAtLeftEdge() {
        let selection = CGRect(x: 0, y: 100, width: 100, height: 100)
        let toolbar = ScreenshotToolbarLayout.frame(
            near: selection,
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            toolbarSize: CGSize(width: 314, height: 50)
        )

        // Toolbar goes above and is clamped to the left edge (x = visibleFrame.minX)
        assertToolbarLayout(toolbar: toolbar, expected: CGRect(x: 0, y: 42, width: 314, height: 50), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), selection: selection)
    }

    func testScreenshotToolbarFallsBackToVisibleCandidatesWhenNoNaturalPositionFits() {
        // Selection nearly fills the visible frame, so none of the four natural
        // toolbar positions (above, below, left, right) can fully contain the
        // toolbar. The code falls back to visibleCandidates — toolbar pinned
        // to each visible-frame edge — and picks the one with the least overlap
        // with the selection.
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let selection = CGRect(x: 20, y: 20, width: 1380, height: 860)
        let toolbar = ScreenshotToolbarLayout.frame(
            near: selection,
            visibleFrame: visibleFrame,
            toolbarSize: CGSize(width: 314, height: 50)
        )

        // Both top-edge and bottom-edge candidates have the same minimal
        // intersection area (9420); stable min picks the first (top).
        XCTAssertEqual(toolbar, CGRect(x: 553, y: 0, width: 314, height: 50))
        XCTAssertTrue(visibleFrame.contains(toolbar))
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

        view.performAction(.finish)

        guard case .region(let displayID, let rect)? = completedRequest?.selection else {
            return XCTFail("Expected region capture request.")
        }
        guard case .finish? = completedRequest?.action else {
            return XCTFail("Expected finish action.")
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
        view.performAction(.finish)

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
        view.performAction(.finish)

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

    private func assertToolbarLayout(
        toolbar: CGRect,
        expected: CGRect,
        visibleFrame: CGRect,
        selection: CGRect,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(toolbar, expected, file: file, line: line)
        XCTAssertTrue(visibleFrame.contains(toolbar), "Toolbar must be inside visible frame", file: file, line: line)
        XCTAssertFalse(toolbar.intersects(selection), "Toolbar must not overlap selection", file: file, line: line)
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
