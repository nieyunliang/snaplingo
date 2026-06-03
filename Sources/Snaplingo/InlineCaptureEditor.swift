import AppKit
import SwiftUI

@MainActor
final class InlineCaptureEditorController {
    private var editorPanel: InlineCapturePanel?

    func show(
        screenshot: ScreenshotResult,
        settings: AppSettings,
        ocrService: OCRServicing,
        translationService: InlineTranslationService,
        clipboard: ClipboardServicing,
        initialDrawingTool: AnnotationTool? = nil,
        startsTranslation: Bool = false
    ) {
        close()

        let document = InlineCaptureDocument(
            screenshot: screenshot,
            settings: settings,
            ocrService: ocrService,
            translationService: translationService,
            clipboard: clipboard,
            initialDrawingTool: initialDrawingTool,
            startsTranslation: startsTranslation
        )

        let layout = InlineCaptureEditorLayout.make(for: screenshot.screenRect)
        let editorPanel = makePanel(frame: layout.frame)

        editorPanel.contentViewController = NSHostingController(
            rootView: InlineCaptureEditorView(
                document: document,
                screenshotFrame: layout.screenshotFrame,
                toolbarFrame: layout.toolbarFrame,
                close: { [weak self] in self?.close() }
            )
        )
        editorPanel.onCancel = { [weak self] in
            self?.close()
        }
        self.editorPanel = editorPanel
        editorPanel.makeKeyAndOrderFront(nil)
        editorPanel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        editorPanel?.orderOut(nil)
        editorPanel = nil
    }

    private func makePanel(frame: CGRect) -> InlineCapturePanel {
        let panel = InlineCapturePanel(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.setFrame(frame, display: false)
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }
}
