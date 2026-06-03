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

    private let settings: AppSettings
    private let ocrService: OCRServicing
    private let translationService: InlineTranslationService
    private let clipboard: ClipboardServicing
    private var dragStart: CGPoint?
    private var cachedOCRResult: OCRResult?
    private var cachedTranslationPatches: [InlineTranslationPatch]?
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
        self.settings = settings
        self.ocrService = ocrService
        self.translationService = translationService
        self.clipboard = clipboard
        canvasModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        if startsTranslation {
            Task { await toggleTranslation() }
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
        guard !isTranslating else { return }
        if let cachedTranslationPatches {
            if isTranslationVisible {
                canvasModel.clearPatches()
                isTranslationVisible = false
                setStatus("已隐藏译文", kind: .success)
            } else {
                canvasModel.setPatches(cachedTranslationPatches)
                isTranslationVisible = true
                setStatus(translationVisibleStatus(for: cachedTranslationPatches), kind: .success)
            }
            return
        }

        await translate()
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

    private func translate() async {
        guard !isTranslating else { return }
        isTranslating = true
        setStatus("正在识别文字...", kind: .info)
        defer { isTranslating = false }
        do {
            let ocr = try await recognizeText()
            setStatus("正在请求 AI 翻译...", kind: .info)
            let translationStartedAt = PerformanceMetrics.start()
            let patches = try await translationService.translate(blocks: ocr.blocks, imageSize: screenshot.image.size, settings: settings)
            PerformanceMetrics.log("inline_translation", since: translationStartedAt, metadata: "patches=\(patches.count)")
            setStatus("正在覆盖译文...", kind: .info)
            cachedTranslationPatches = patches
            canvasModel.setPatches(patches)
            isTranslationVisible = true
            setStatus(translationVisibleStatus(for: patches), kind: .success)
        } catch {
            setStatus(error.localizedDescription, kind: .failure)
        }
    }

    private func setStatus(_ message: String, kind: InlineCaptureStatusKind) {
        status = message
        statusKind = kind
    }

    private func translationVisibleStatus(for patches: [InlineTranslationPatch]) -> String {
        patches.isEmpty ? "未发现需要翻译的外语" : "已替换 \(patches.count) 处文字"
    }

    private func recognizeText() async throws -> OCRResult {
        let startedAt = PerformanceMetrics.start()
        if let cachedOCRResult {
            PerformanceMetrics.log("inline_ocr_cache_hit", since: startedAt, metadata: "blocks=\(cachedOCRResult.blocks.count)")
            return cachedOCRResult
        }

        let result = try await ocrService.recognize(image: screenshot.image, languages: settings.ocrLanguages)
        cachedOCRResult = result
        PerformanceMetrics.log("inline_ocr", since: startedAt, metadata: "blocks=\(result.blocks.count)")
        return result
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
