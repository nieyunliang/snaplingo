import AppKit
import Foundation

struct ScreenshotResult {
    let image: NSImage
    let screenRect: CGRect
}

struct CaptureRequest {
    let selection: CaptureSelection
    let action: CaptureAction
}

enum CaptureAction {
    case finish
    case annotate(AnnotationTool)
    case translate
    case copy
    case save
}

enum CaptureSelection {
    case region(displayID: CGDirectDisplayID, appKitRect: CGRect)
    case window(WindowCaptureCandidate)
}

struct InlineTranslationPatch {
    let translatedText: String
    let imageRect: CGRect
}

struct OCRResult {
    let text: String
    let confidence: Double?
    let blocks: [OCRTextBlock]
}

struct OCRTextBlock {
    let text: String
    let boundingBox: CGRect
    let confidence: Double?
}

struct TranslationResult {
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String?
    let targetLanguage: String
    let provider: TranslationProvider
}

struct TranslationRequest {
    let text: String
    let sourceLanguage: String?
    let targetLanguage: String
    let style: TranslationStyle
}

enum TranslationStyle: String, Codable, CaseIterable, Identifiable {
    case natural
    case literal
    case professional
    case concise

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .natural:
            return "自然"
        case .literal:
            return "直译"
        case .professional:
            return "专业"
        case .concise:
            return "简洁"
        }
    }

    var instruction: String {
        switch self {
        case .natural:
            return "译文应自然、流畅，并保留原意。"
        case .literal:
            return "尽量保留原文句式和信息顺序。"
        case .professional:
            return "使用适合技术、学术和商务场景的专业表达。"
        case .concise:
            return "压缩表达，只保留核心意思。"
        }
    }
}

enum TranslationProvider: String, CaseIterable, Identifiable {
    case deepSeek
    case offline
    case translationMemory

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepSeek:
            return "DeepSeek"
        case .offline:
            return "离线词典"
        case .translationMemory:
            return "翻译记忆"
        }
    }

    static func settingsValue(for rawValue: String) -> TranslationProvider {
        TranslationProvider(rawValue: rawValue) ?? .deepSeek
    }
}

enum AnnotationTool {
    case rectangle
    case circle
    case arrow
}

struct AnnotationItem {
    static let defaultColorHex = "#FF3B30"

    var tool: AnnotationTool
    var rect: CGRect
    var colorHex: String
    var lineWidth: CGFloat
    var arrowStart: CGPoint?
    var arrowEnd: CGPoint?

    init(
        tool: AnnotationTool,
        rect: CGRect,
        colorHex: String = AnnotationItem.defaultColorHex,
        lineWidth: CGFloat = 3,
        arrowStart: CGPoint? = nil,
        arrowEnd: CGPoint? = nil
    ) {
        self.tool = tool
        self.rect = rect
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.arrowStart = arrowStart
        self.arrowEnd = arrowEnd
    }
}

struct GlossaryTerm {
    let source: String
    let target: String
}

struct TranslationMemoryEntry: Codable {
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String?
    let targetLanguage: String
    let style: TranslationStyle
    let createdAt: Date
}

enum AppError: LocalizedError {
    case screenRecordingDenied
    case captureFailed
    case noWindowFound
    case imageConversionFailed
    case noTextRecognized
    case missingAPIKey
    case invalidTranslationResponse

    var errorDescription: String? {
        switch self {
        case .screenRecordingDenied:
            return "缺少屏幕录制权限。"
        case .captureFailed:
            return "截图失败。"
        case .noWindowFound:
            return "没有找到可截取的前台窗口。"
        case .imageConversionFailed:
            return "图片转换失败。"
        case .noTextRecognized:
            return "未识别到文字。"
        case .missingAPIKey:
            return "请先在设置中配置 DeepSeek API Key。"
        case .invalidTranslationResponse:
            return "翻译服务返回了无法解析的结果。"
        }
    }
}
