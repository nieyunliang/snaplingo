import AppKit
import SwiftUI

@MainActor
final class InlineCaptureEditorController {
    private var editorPanel: InlineCapturePanel?
    private var displayID: CGDirectDisplayID = 0
    private var originalScreenRect: CGRect = .zero
    private var initialPanelOrigin: CGPoint = .zero
    private var lastSettings: AppSettings?
    private var lastOCRService: OCRServicing?
    private var lastTranslationService: InlineTranslationService?
    private var lastClipboard: ClipboardServicing?

    var onCapture: ((CGRect, CGDirectDisplayID) async throws -> ScreenshotResult)?

    func show(
        screenshot: ScreenshotResult,
        settings: AppSettings,
        ocrService: OCRServicing,
        translationService: InlineTranslationService,
        clipboard: ClipboardServicing,
        initialDrawingTool: AnnotationTool? = nil,
        locksRegionMovement: Bool = false,
        startsTranslation: Bool = false
    ) {
        close()

        displayID = resolveDisplayID(for: screenshot.screenRect)
        originalScreenRect = screenshot.screenRect
        lastSettings = settings
        lastOCRService = ocrService
        lastTranslationService = translationService
        lastClipboard = clipboard

        let document = InlineCaptureDocument(
            screenshot: screenshot,
            settings: settings,
            ocrService: ocrService,
            translationService: translationService,
            clipboard: clipboard,
            initialDrawingTool: initialDrawingTool,
            locksRegionMovement: locksRegionMovement,
            startsTranslation: startsTranslation
        )

        let layout = InlineCaptureEditorLayout.make(for: screenshot.screenRect)
        let editorPanel = makePanel(frame: layout.frame)
        initialPanelOrigin = layout.frame.origin

        let onMoveRegion: (CGSize) -> Void = { [weak editorPanel] delta in
            guard let panel = editorPanel else { return }
            var frame = panel.frame
            frame.origin.x += delta.width
            frame.origin.y -= delta.height
            panel.setFrame(frame, display: true)
        }

        let onMoveEnded: @MainActor () -> Void = { [weak self, weak editorPanel] in
            guard let self, let panel = editorPanel else { return }
            let dx = panel.frame.origin.x - self.initialPanelOrigin.x
            let dy = panel.frame.origin.y - self.initialPanelOrigin.y
            guard abs(dx) > 1 || abs(dy) > 1 else { return }
            let newRect = self.originalScreenRect.offsetBy(dx: dx, dy: dy)
            Task { await self.recapture(at: newRect) }
        }

        editorPanel.contentViewController = NSHostingController(
            rootView: InlineCaptureEditorView(
                document: document,
                screenshotFrame: layout.screenshotFrame,
                toolbarFrame: layout.toolbarFrame,
                close: { [weak self] in self?.close() },
                onMoveRegion: onMoveRegion,
                onMoveEnded: onMoveEnded
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

    private func recapture(at rect: CGRect) async {
        guard let onCapture,
              let settings = lastSettings,
              let ocrService = lastOCRService,
              let translationService = lastTranslationService,
              let clipboard = lastClipboard
        else {
            return
        }
        do {
            let screenshot = try await onCapture(rect, displayID)
            show(
                screenshot: screenshot,
                settings: settings,
                ocrService: ocrService,
                translationService: translationService,
                clipboard: clipboard
            )
        } catch {
            // Keep the current screenshot visible on failure.
        }
    }

    private func resolveDisplayID(for rect: CGRect) -> CGDirectDisplayID {
        NSScreen.screens.first(where: { $0.frame.intersects(rect) })?.displayID
            ?? NSScreen.main?.displayID
            ?? 0
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
