import AppKit
import Combine

@MainActor
final class InlineCaptureDocument: ObservableObject {
    let screenshot: ScreenshotResult
    let locksRegionMovement: Bool
    let startsTranslationOnAppear: Bool
    @Published var annotations: [AnnotationItem] = []
    @Published var draftAnnotation: AnnotationItem?
    @Published var patches: [InlineTranslationPatch] = []
    @Published var drawingTool: AnnotationTool?
    @Published var isTranslating = false
    @Published var isTranslationVisible = false
    @Published var status = ""

    private let settings: AppSettings
    private let ocrService: OCRServicing
    private let translationService: InlineTranslationService
    private let clipboard: ClipboardServicing
    private var dragStart: CGPoint?
    private var cachedOCRResult: OCRResult?
    private var cachedTranslationPatches: [InlineTranslationPatch]?

    init(
        screenshot: ScreenshotResult,
        settings: AppSettings,
        ocrService: OCRServicing,
        translationService: InlineTranslationService,
        clipboard: ClipboardServicing,
        initialDrawingTool: AnnotationTool? = nil,
        locksRegionMovement: Bool = false,
        startsTranslation: Bool = false
    ) {
        self.screenshot = screenshot
        self.locksRegionMovement = locksRegionMovement
        self.startsTranslationOnAppear = startsTranslation
        self.settings = settings
        self.ocrService = ocrService
        self.translationService = translationService
        self.clipboard = clipboard
        self.drawingTool = initialDrawingTool
    }

    var canUndo: Bool { !annotations.isEmpty }

    func toggleDrawingTool(_ tool: AnnotationTool) {
        drawingTool = drawingTool == tool ? nil : tool
    }

    func beginDrawing(at point: CGPoint) {
        guard let drawingTool else { return }
        dragStart = point
        draftAnnotation = makeAnnotation(tool: drawingTool, from: point, to: point)
    }

    func dragDrawing(to point: CGPoint) {
        guard let dragStart, let drawingTool else { return }
        draftAnnotation = makeAnnotation(tool: drawingTool, from: dragStart, to: point)
    }

    func endDrawing(at point: CGPoint) {
        dragDrawing(to: point)
        if let draftAnnotation,
           draftAnnotation.rect.width > 4 || draftAnnotation.rect.height > 4 {
            annotations.append(draftAnnotation)
        }
        draftAnnotation = nil
        dragStart = nil
    }

    func undo() {
        _ = annotations.popLast()
    }

    func toggleTranslation() async {
        guard !isTranslating else { return }
        if let cachedTranslationPatches {
            if isTranslationVisible {
                patches = []
                isTranslationVisible = false
                status = "已隐藏译文"
            } else {
                patches = cachedTranslationPatches
                isTranslationVisible = true
                status = translationVisibleStatus(for: cachedTranslationPatches)
            }
            return
        }

        await translate()
    }

    func copy() {
        clipboard.copyImage(renderedImage())
        status = "已复制图片"
    }

    func save() {
        do {
            if try ImageFileExporter.promptAndWritePNG(renderedImage()) {
                status = "已保存图片"
            }
        } catch {
            status = "保存失败：\(error.localizedDescription)"
        }
    }

    func renderedImage() -> NSImage {
        InlineCaptureRenderer.render(image: screenshot.image, annotations: annotations, patches: patches)
    }

    private func translate() async {
        guard !isTranslating else { return }
        isTranslating = true
        status = "正在识别文字..."
        defer { isTranslating = false }
        do {
            let ocr = try await recognizeText()
            status = "正在请求 AI 翻译..."
            let translationStartedAt = PerformanceMetrics.start()
            let patches = try await translationService.translate(blocks: ocr.blocks, imageSize: screenshot.image.size, settings: settings)
            PerformanceMetrics.log("inline_translation", since: translationStartedAt, metadata: "patches=\(patches.count)")
            status = "正在覆盖译文..."
            cachedTranslationPatches = patches
            self.patches = patches
            isTranslationVisible = true
            status = translationVisibleStatus(for: patches)
        } catch {
            status = error.localizedDescription
        }
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
