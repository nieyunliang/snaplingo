import AppKit
import Combine

@MainActor
final class InlineCaptureDocument: ObservableObject {
    let screenshot: ScreenshotResult
    let canvasModel: InlineCaptureCanvasModel
    @Published var isTranslating = false
    @Published var isTranslationVisible = false
    @Published private(set) var status = ""
    @Published private(set) var statusKind: InlineCaptureStatusKind?

    private let clipboard: ClipboardServicing
    private let translationFlow: TranslationFlowController
    private var dragStart: CGPoint?
    private var cancellables: Set<AnyCancellable> = []

    init(
        screenshot: ScreenshotResult,
        settings: AppSettings,
        ocrService: OCRServicing,
        translationService: InlineTranslationService,
        clipboard: ClipboardServicing,
        initialDrawingTool: AnnotationTool? = nil,
        startsTranslation: Bool = false
    ) {
        self.screenshot = screenshot
        self.canvasModel = InlineCaptureCanvasModel(
            screenshot: screenshot,
            initialDrawingTool: initialDrawingTool
        )
        self.clipboard = clipboard
        self.translationFlow = TranslationFlowController(
            screenshot: screenshot,
            settings: settings,
            ocrService: ocrService,
            translationService: translationService,
            canvasModel: canvasModel
        )
        canvasModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        translationFlow.onStateChange = { [weak self] in
            guard let self else { return }
            self.isTranslating = self.translationFlow.isTranslating
            self.isTranslationVisible = self.translationFlow.isTranslationVisible
            self.status = self.translationFlow.status
            self.statusKind = self.translationFlow.statusKind
        }
        if startsTranslation {
            triggerTranslation()
        }
    }

    var annotations: [AnnotationItem] { canvasModel.annotations }
    var draftAnnotation: AnnotationItem? { canvasModel.draftAnnotation }
    var patches: [InlineTranslationPatch] { canvasModel.patches }
    var drawingTool: AnnotationTool? { canvasModel.drawingTool }
    var canUndo: Bool { canvasModel.canUndo }

    func toggleDrawingTool(_ tool: AnnotationTool) {
        canvasModel.drawingTool = canvasModel.drawingTool == tool ? nil : tool
    }

    func beginDrawing(at point: CGPoint) {
        guard let drawingTool = canvasModel.drawingTool else { return }
        dragStart = point
        canvasModel.draftAnnotation = makeAnnotation(tool: drawingTool, from: point, to: point)
    }

    func dragDrawing(to point: CGPoint) {
        guard let dragStart, let drawingTool = canvasModel.drawingTool else { return }
        canvasModel.draftAnnotation = makeAnnotation(tool: drawingTool, from: dragStart, to: point)
    }

    func endDrawing(at point: CGPoint) {
        dragDrawing(to: point)
        if let draftAnnotation = canvasModel.draftAnnotation,
           draftAnnotation.rect.width > 4 || draftAnnotation.rect.height > 4 {
            canvasModel.appendAnnotation(draftAnnotation)
        }
        canvasModel.draftAnnotation = nil
        dragStart = nil
    }

    func undo() {
        canvasModel.removeLastAnnotation()
    }

    func toggleTranslation() async {
        await translationFlow.toggleTranslation()
    }

    func triggerTranslation() {
        translationFlow.triggerTranslation()
    }

    func copy() {
        clipboard.copyImage(renderedImage())
        setStatus("已复制图片", kind: .success)
    }

    func save() {
        do {
            if try ImageFileExporter.promptAndWritePNG(renderedImage()) {
                setStatus("已保存图片", kind: .success)
            }
        } catch {
            setStatus("保存失败：\(error.localizedDescription)", kind: .failure)
        }
    }

    func renderedImage() -> NSImage {
        canvasModel.renderedImageForExport()
    }

    private func setStatus(_ message: String, kind: InlineCaptureStatusKind) {
        status = message
        statusKind = kind
    }

    private func makeAnnotation(tool: AnnotationTool, from start: CGPoint, to end: CGPoint) -> AnnotationItem {
        AnnotationItem(
            tool: tool,
            rect: SelectionGeometry.normalizedRect(from: start, to: end),
            colorHex: AnnotationItem.defaultColorHex,
            lineWidth: 3,
            arrowStart: tool == .arrow ? start : nil,
            arrowEnd: tool == .arrow ? end : nil
        )
    }
}

enum InlineCaptureStatusKind: Equatable {
    case info
    case success
    case failure
}
