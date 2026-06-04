import AppKit
import SwiftUI

@MainActor
final class SelectionToolbarHost {
    private weak var parentView: NSView?
    private var hostingView: NSHostingView<ScreenshotToolbar>?

    var isVisible: Bool { hostingView != nil }

    func show(
        in parent: NSView,
        selection: CGRect,
        screenFrame: CGRect,
        onAction: @escaping (CaptureAction) -> Void,
        onClose: @escaping () -> Void
    ) {
        if hostingView != nil {
            updatePosition(selection: selection, screenFrame: screenFrame)
            return
        }
        let toolbarView = ScreenshotToolbar(
            state: .selecting(
                onAction: onAction,
                onClose: onClose
            )
        )
        let hostingView = NSHostingView(rootView: toolbarView)
        parent.addSubview(hostingView)
        self.hostingView = hostingView
        self.parentView = parent
        updatePosition(selection: selection, screenFrame: screenFrame)
    }

    func hide() {
        hostingView?.removeFromSuperview()
        hostingView = nil
        parentView = nil
    }

    func updatePosition(selection: CGRect, screenFrame: CGRect) {
        guard let hostingView else { return }
        let screenSelection = CGRect(
            x: selection.minX + screenFrame.minX,
            y: selection.minY + screenFrame.minY,
            width: selection.width,
            height: selection.height
        )
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(screenSelection) }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        let toolbarSize = ScreenshotToolbarLayout.size(fitting: visibleFrame)
        let screenToolbarFrame = ScreenshotToolbarLayout.frame(
            near: screenSelection,
            visibleFrame: visibleFrame,
            toolbarSize: toolbarSize
        )
        let localToolbarFrame = CGRect(
            x: screenToolbarFrame.minX - screenFrame.minX,
            y: screenToolbarFrame.minY - screenFrame.minY,
            width: screenToolbarFrame.width,
            height: screenToolbarFrame.height
        )
        hostingView.frame = localToolbarFrame
    }
}
