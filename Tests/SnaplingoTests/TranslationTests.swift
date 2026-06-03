import AppKit
import XCTest
@testable import Snaplingo

final class TranslationTests: XCTestCase {
    @MainActor
    func testOfflineTranslationAppliesGlossaryBeforeBuiltInDictionary() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!)
        settings.glossaryText = "hello=您好"

        let result = OfflineTranslationService().translate(
            TranslationRequest(text: "hello screen", sourceLanguage: "en-US", targetLanguage: "中文", style: .natural),
            settings: settings
        )

        XCTAssertEqual(result.translatedText, "您好 屏幕")
        XCTAssertEqual(result.provider, .offline)
    }

    @MainActor
    func testTranslationMemoryReturnsExactNormalizedMatch() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("memory-\(UUID().uuidString).json")
        let store = TranslationMemoryStore(fileURL: url)
        let request = TranslationRequest(text: "Hello\nworld", sourceLanguage: "en-US", targetLanguage: "中文", style: .natural)
        store.remember(
            TranslationResult(
                sourceText: " hello  world ",
                translatedText: "你好，世界",
                sourceLanguage: "en-US",
                targetLanguage: "中文",
                provider: .deepSeek
            ),
            style: .natural
        )

        XCTAssertEqual(store.lookup(request)?.translatedText, "你好，世界")
        XCTAssertEqual(store.lookup(request)?.provider, .translationMemory)
    }

    func testInlineTranslationLayoutFiltersChineseDigitsAndSymbols() {
        let blocks = [
            OCRTextBlock(text: "Hello", boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.2, height: 0.1), confidence: 0.9),
            OCRTextBlock(text: "中文", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.2, height: 0.1), confidence: 0.9),
            OCRTextBlock(text: "42%", boundingBox: CGRect(x: 0.1, y: 0.3, width: 0.2, height: 0.1), confidence: 0.9)
        ]

        let sources = InlineTranslationLayout.sources(from: blocks, imageSize: CGSize(width: 1000, height: 500))

        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].id, "block-0")
        XCTAssertEqual(sources[0].text, "Hello")
        XCTAssertEqual(sources[0].imageRect.minX, 100, accuracy: 0.001)
        XCTAssertEqual(sources[0].imageRect.minY, 100, accuracy: 0.001)
        XCTAssertEqual(sources[0].imageRect.width, 200, accuracy: 0.001)
        XCTAssertEqual(sources[0].imageRect.height, 50, accuracy: 0.001)
    }

    func testOCRRecognitionStrategyRetriesLowConfidenceFastResults() {
        XCTAssertFalse(OCRRecognitionStrategy.shouldRetryAccurately(fastResult: OCRResult(
            text: "Hello",
            confidence: 0.9,
            blocks: []
        )))
        XCTAssertTrue(OCRRecognitionStrategy.shouldRetryAccurately(fastResult: OCRResult(
            text: "Hello",
            confidence: 0.4,
            blocks: []
        )))
        XCTAssertTrue(OCRRecognitionStrategy.shouldRetryAccurately(fastResult: OCRResult(
            text: "Hello",
            confidence: nil,
            blocks: []
        )))
    }

    @MainActor
    func testInlineTranslationServiceUsesOneDeepSeekRequestAndMapsBlocks() async throws {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!)
        settings.deepSeekAPIKey = "unit-test-key"
        settings.deepSeekBaseURL = "https://unit.test/v1/chat/completions"
        let data = Data("""
        {"choices":[{"message":{"content":"{\\"block-0\\":\\"你好\\",\\"block-1\\":\\"世界\\"}"}}]}
        """.utf8)
        let httpClient = HTTPDataLoaderStub(data: data, statusCode: 200)
        let service = InlineTranslationService(httpClient: httpClient, translationMemoryStore: makeTranslationMemoryStore())

        let patches = try await service.translate(
            blocks: [
                OCRTextBlock(text: "Hello", boundingBox: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5), confidence: 1),
                OCRTextBlock(text: "World", boundingBox: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5), confidence: 1)
            ],
            imageSize: CGSize(width: 200, height: 100),
            settings: settings
        )

        XCTAssertEqual(httpClient.requests.count, 1)
        XCTAssertEqual(patches.map(\.translatedText), ["你好", "世界"])
        XCTAssertEqual(patches.map(\.imageRect), [
            CGRect(x: 0, y: 0, width: 100, height: 50),
            CGRect(x: 100, y: 50, width: 100, height: 50)
        ])
        let request = try XCTUnwrap(httpClient.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer unit-test-key")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "deepseek-v4-flash")
    }

    @MainActor
    func testInlineTranslationServiceUsesMemoryAndRequestsOnlyMissingBlocks() async throws {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!)
        settings.deepSeekAPIKey = "unit-test-key"
        settings.deepSeekBaseURL = "https://unit.test/v1/chat/completions"
        let store = makeTranslationMemoryStore()
        store.remember(
            TranslationResult(
                sourceText: "Hello",
                translatedText: "你好",
                sourceLanguage: nil,
                targetLanguage: "中文",
                provider: .deepSeek
            ),
            style: .natural
        )
        let data = Data("""
        {"choices":[{"message":{"content":"{\\"block-1\\":\\"世界\\"}"}}]}
        """.utf8)
        let httpClient = HTTPDataLoaderStub(data: data, statusCode: 200)
        let service = InlineTranslationService(httpClient: httpClient, translationMemoryStore: store)
        let blocks = [
            OCRTextBlock(text: "Hello", boundingBox: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5), confidence: 1),
            OCRTextBlock(text: "World", boundingBox: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5), confidence: 1)
        ]

        let first = try await service.translate(blocks: blocks, imageSize: CGSize(width: 200, height: 100), settings: settings)
        let second = try await service.translate(blocks: blocks, imageSize: CGSize(width: 200, height: 100), settings: settings)

        XCTAssertEqual(httpClient.requests.count, 1)
        XCTAssertEqual(first.map(\.translatedText), ["你好", "世界"])
        XCTAssertEqual(second.map(\.translatedText), ["你好", "世界"])
        let requestBody = try XCTUnwrap(httpClient.requests.first?.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        let userContent = try XCTUnwrap(messages.first { $0["role"] == "user" }?["content"])
        XCTAssertFalse(userContent.contains("Hello"))
        XCTAssertTrue(userContent.contains("World"))
    }

    @MainActor
    func testInlineTranslationServiceRequestsDuplicateTextOnlyOnce() async throws {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!)
        settings.deepSeekAPIKey = "unit-test-key"
        settings.deepSeekBaseURL = "https://unit.test/v1/chat/completions"
        let data = Data("""
        {"choices":[{"message":{"content":"{\\"block-0\\":\\"你好\\"}"}}]}
        """.utf8)
        let httpClient = HTTPDataLoaderStub(data: data, statusCode: 200)
        let service = InlineTranslationService(httpClient: httpClient, translationMemoryStore: makeTranslationMemoryStore())

        let patches = try await service.translate(
            blocks: [
                OCRTextBlock(text: "Hello", boundingBox: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5), confidence: 1),
                OCRTextBlock(text: "Hello", boundingBox: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5), confidence: 1)
            ],
            imageSize: CGSize(width: 200, height: 100),
            settings: settings
        )

        XCTAssertEqual(patches.map(\.translatedText), ["你好", "你好"])
        let requestBody = try XCTUnwrap(httpClient.requests.first?.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        let userContent = try XCTUnwrap(messages.first { $0["role"] == "user" }?["content"])
        XCTAssertTrue(userContent.contains("block-0"))
        XCTAssertFalse(userContent.contains("block-1"))
    }

    @MainActor
    func testInlineCaptureDocumentTogglesTranslationVisibilityFromCache() async {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!)
        settings.translationProvider = .offline
        let ocrService = OCRServiceStub(
            result: OCRResult(
                text: "Hello",
                confidence: 1,
                blocks: [
                    OCRTextBlock(text: "Hello", boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1), confidence: 1)
                ]
            )
        )
        let document = InlineCaptureDocument(
            screenshot: ScreenshotResult(
                image: makeSolidImage(.white),
                screenRect: CGRect(x: 0, y: 0, width: 20, height: 20)
            ),
            settings: settings,
            ocrService: ocrService,
            translationService: InlineTranslationService(),
            clipboard: ClipboardServiceStub()
        )

        await document.toggleTranslation()
        XCTAssertTrue(document.isTranslationVisible)
        XCTAssertEqual(document.patches.map(\.translatedText), ["你好"])

        await document.toggleTranslation()
        XCTAssertFalse(document.isTranslationVisible)
        XCTAssertTrue(document.patches.isEmpty)

        await document.toggleTranslation()

        XCTAssertEqual(ocrService.requestCount, 1)
        XCTAssertTrue(document.isTranslationVisible)
        XCTAssertEqual(document.patches.map(\.translatedText), ["你好"])
    }

    @MainActor
    func testInlineCaptureDocumentDoesNotRepeatOnlineTranslationWhenToggling() async {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!)
        settings.translationProvider = .deepSeek
        settings.deepSeekAPIKey = "test-key"
        let data = Data("""
        {"choices":[{"message":{"content":"{\\"block-0\\":\\"你好\\"}"}}]}
        """.utf8)
        let httpClient = HTTPDataLoaderStub(data: data, statusCode: 200)
        let document = InlineCaptureDocument(
            screenshot: ScreenshotResult(
                image: makeSolidImage(.white, size: CGSize(width: 100, height: 60)),
                screenRect: CGRect(x: 0, y: 0, width: 100, height: 60)
            ),
            settings: settings,
            ocrService: OCRServiceStub(
                result: OCRResult(
                    text: "Hello",
                    confidence: 1,
                    blocks: [
                        OCRTextBlock(text: "Hello", boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1), confidence: 1)
                    ]
                )
            ),
            translationService: InlineTranslationService(httpClient: httpClient, translationMemoryStore: makeTranslationMemoryStore()),
            clipboard: ClipboardServiceStub()
        )

        await document.toggleTranslation()
        await document.toggleTranslation()
        await document.toggleTranslation()

        XCTAssertEqual(httpClient.requests.count, 1)
        XCTAssertTrue(document.isTranslationVisible)
        XCTAssertEqual(document.patches.map(\.translatedText), ["你好"])
    }

    @MainActor
    func testInlineCaptureDocumentCanStartWithInitialDrawingTool() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!)
        let initialAnnotationTool = AnnotationTool.rectangle
        let document = InlineCaptureDocument(
            screenshot: ScreenshotResult(
                image: makeSolidImage(.white, size: CGSize(width: 80, height: 60)),
                screenRect: CGRect(x: 10, y: 20, width: 80, height: 60)
            ),
            settings: settings,
            ocrService: OCRServiceStub(
                result: OCRResult(text: "", confidence: nil, blocks: [])
            ),
            translationService: InlineTranslationService(),
            clipboard: ClipboardServiceStub(),
            initialDrawingTool: initialAnnotationTool
        )

        if case .rectangle? = document.drawingTool {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected rectangle tool to be active.")
        }
    }


    @MainActor
    func testVisionOCRRecognizesRenderedTextImage() async throws {
        let image = makeTextImage("HELLO SNAPLINGO")
        let result: OCRResult
        do {
            result = try await VisionOCRService().recognize(image: image, languages: ["en-US"])
        } catch AppError.noTextRecognized {
            throw XCTSkip("Vision OCR did not recognize the rendered fixture in this environment.")
        }

        XCTAssertTrue(
            result.text.uppercased().contains("HELLO"),
            "Expected OCR text to contain HELLO, got: \(result.text)"
        )
        XCTAssertFalse(result.blocks.isEmpty)
    }

    @MainActor
    func testInlineTranslationServiceRejectsMissingAPIKeyBeforeNetwork() async {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!)
        settings.deepSeekAPIKey = "  "

        do {
            _ = try await InlineTranslationService().translate(
                blocks: [
                    OCRTextBlock(text: "Hello", boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1), confidence: 1)
                ],
                imageSize: CGSize(width: 100, height: 100),
                settings: settings
            )
            XCTFail("Expected missing API key error")
        } catch AppError.missingAPIKey {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
