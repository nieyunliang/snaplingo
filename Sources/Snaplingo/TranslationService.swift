import Foundation

@MainActor
protocol HTTPDataLoading {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataLoading {}

@MainActor
struct OfflineTranslationService {
    func translate(_ request: TranslationRequest, settings: AppSettings) -> TranslationResult {
        var translated = request.text

        for term in settings.glossaryTerms.sorted(by: { $0.source.count > $1.source.count }) {
            translated = translated.replacingOccurrences(
                of: term.source,
                with: term.target,
                options: [.caseInsensitive]
            )
        }

        let dictionary = Self.dictionary(for: request.targetLanguage)
        for (source, target) in dictionary.sorted(by: { $0.key.count > $1.key.count }) {
            translated = translated.replacingOccurrences(
                of: source,
                with: target,
                options: [.caseInsensitive]
            )
        }

        if translated == request.text {
            translated = "[离线译文] \(request.text)"
        }

        return TranslationResult(
            sourceText: request.text,
            translatedText: translated,
            sourceLanguage: request.sourceLanguage,
            targetLanguage: request.targetLanguage,
            provider: .offline
        )
    }

    private static func dictionary(for targetLanguage: String) -> [String: String] {
        if targetLanguage.localizedCaseInsensitiveContains("中") || targetLanguage.localizedCaseInsensitiveContains("zh") {
            return [
                "hello": "你好",
                "world": "世界",
                "settings": "设置",
                "screen": "屏幕",
                "capture": "截图",
                "window": "窗口",
                "text": "文本",
                "copy": "复制",
                "save": "保存",
                "translate": "翻译",
                "translation": "翻译",
                "error": "错误",
                "permission": "权限",
                "privacy": "隐私"
            ]
        }
        return [:]
    }
}
