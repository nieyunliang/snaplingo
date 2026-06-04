import AppKit

@MainActor
final class TranslationFlowController {
    // MARK: - Observable state
    private(set) var isTranslating = false
    private(set) var isTranslationVisible = false
    private(set) var status = ""
    private(set) var statusKind: InlineCaptureStatusKind?

    // MARK: - Dependencies
    private let screenshot: ScreenshotResult
    private let settings: AppSettings
    private let ocrService: OCRServicing
    private let translationService: InlineTranslationService

    // MARK: - Caches
    private var cachedOCRResult: OCRResult?
    private var cachedTranslationPatches: [InlineTranslationPatch]?

    // MARK: - Task management
    private var translationTask: Task<Void, Never>?
    private let canvasModel: InlineCaptureCanvasModel
    var onStateChange: (() -> Void)?

    init(
        screenshot: ScreenshotResult,
        settings: AppSettings,
        ocrService: OCRServicing,
        translationService: InlineTranslationService,
        canvasModel: InlineCaptureCanvasModel
    ) {
        self.screenshot = screenshot
        self.settings = settings
        self.ocrService = ocrService
        self.translationService = translationService
        self.canvasModel = canvasModel
    }

    deinit {
        translationTask?.cancel()
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

    func triggerTranslation() {
        guard translationTask == nil else { return }
        translationTask = Task { [weak self] in
            await self?.toggleTranslation()
        }
    }

    func cancelTasks() {
        translationTask?.cancel()
        translationTask = nil
    }

    // MARK: - Private

    private func translate() async {
        guard !isTranslating else { return }
        setIsTranslating(true)
        setStatus("正在识别文字...", kind: .info)
        defer {
            setIsTranslating(false)
            translationTask = nil
        }
        do {
            let ocr = try await recognizeText()
            setStatus("正在请求 AI 翻译...", kind: .info)
            let translationStartedAt = PerformanceMetrics.start()
            let patches = try await translationService.translate(
                blocks: ocr.blocks,
                imageSize: screenshot.image.size,
                settings: settings
            )
            PerformanceMetrics.log("inline_translation", since: translationStartedAt, metadata: "patches=\(patches.count)")
            setStatus("正在覆盖译文...", kind: .info)
            cachedTranslationPatches = patches
            canvasModel.setPatches(patches)
            isTranslationVisible = true
            setStatus(translationVisibleStatus(for: patches), kind: .success)
        } catch {
            guard !Task.isCancelled else { return }
            setStatus(error.localizedDescription, kind: .failure)
        }
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

    private func setStatus(_ message: String, kind: InlineCaptureStatusKind) {
        status = message
        statusKind = kind
        onStateChange?()
    }

    private func setIsTranslating(_ value: Bool) {
        guard isTranslating != value else { return }
        isTranslating = value
        onStateChange?()
    }

    private func translationVisibleStatus(for patches: [InlineTranslationPatch]) -> String {
        patches.isEmpty ? "未发现需要翻译的外语" : "已替换 \(patches.count) 处文字"
    }
}
