import AppKit

struct InlineCaptureEditorLayout {
    let frame: CGRect
    let screenshotFrame: CGRect
    let toolbarFrame: CGRect

    static func make(for screenshotRect: CGRect) -> InlineCaptureEditorLayout {
        let toolbarRect = toolbarFrame(near: screenshotRect)
        let frame = screenshotRect.union(toolbarRect)
        return InlineCaptureEditorLayout(
            frame: frame,
            screenshotFrame: topLeftLocalFrame(for: screenshotRect, in: frame),
            toolbarFrame: topLeftLocalFrame(for: toolbarRect, in: frame)
        )
    }

    private static func toolbarFrame(near screenshotRect: CGRect) -> CGRect {
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(screenshotRect) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? screenshotRect
        let toolbarSize = CGSize(width: min(430, visible.width), height: 50)
        return ScreenshotToolbarLayout.frame(
            near: screenshotRect,
            visibleFrame: visible,
            toolbarSize: toolbarSize
        )
    }

    private static func topLeftLocalFrame(for rect: CGRect, in parent: CGRect) -> CGRect {
        CGRect(
            x: rect.minX - parent.minX,
            y: parent.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}
