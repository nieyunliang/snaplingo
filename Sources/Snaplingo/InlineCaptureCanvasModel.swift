import AppKit
import Combine

@MainActor
final class InlineCaptureCanvasModel: ObservableObject {
    let screenshot: ScreenshotResult

    @Published private(set) var renderedImage: NSImage
    @Published var draftAnnotation: AnnotationItem?
    @Published var drawingTool: AnnotationTool?

    private(set) var annotations: [AnnotationItem] = []
    private(set) var patches: [InlineTranslationPatch] = []

    init(screenshot: ScreenshotResult, initialDrawingTool: AnnotationTool? = nil) {
        self.screenshot = screenshot
        self.renderedImage = screenshot.image
        self.drawingTool = initialDrawingTool
    }

    var canUndo: Bool { !annotations.isEmpty }

    func appendAnnotation(_ annotation: AnnotationItem) {
        annotations.append(annotation)
        updateRenderedImage()
    }

    func removeLastAnnotation() {
        guard !annotations.isEmpty else { return }
        _ = annotations.popLast()
        updateRenderedImage()
    }

    func setPatches(_ patches: [InlineTranslationPatch]) {
        self.patches = patches
        updateRenderedImage()
    }

    func clearPatches() {
        setPatches([])
    }

    func renderedImageForExport() -> NSImage {
        renderedImage
    }

    private func updateRenderedImage() {
        guard !annotations.isEmpty || !patches.isEmpty else {
            renderedImage = screenshot.image
            return
        }
        renderedImage = InlineCaptureRenderer.render(
            image: screenshot.image,
            annotations: annotations,
            patches: patches
        )
    }
}
