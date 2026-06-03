import AppKit
import Foundation

struct InlineTranslationSource {
    let id: String
    let text: String
    let imageRect: CGRect
}

enum InlineTranslationLayout {
    static func sources(from blocks: [OCRTextBlock], imageSize: CGSize) -> [InlineTranslationSource] {
        blocks.enumerated().compactMap { index, block in
            guard needsTranslation(block.text) else {
                return nil
            }
            return InlineTranslationSource(
                id: "block-\(index)",
                text: block.text,
                imageRect: imageRect(fromVisionBox: block.boundingBox, imageSize: imageSize)
            )
        }
    }

    static func imageRect(fromVisionBox box: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: box.minX * imageSize.width,
            y: (1 - box.maxY) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )
    }

    static func needsTranslation(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            CharacterSet.letters.contains(scalar) && !isHan(scalar)
        }
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400 ... 0x4DBF, 0x4E00 ... 0x9FFF, 0xF900 ... 0xFAFF:
            return true
        default:
            return false
        }
    }
}

@MainActor
struct InlineTranslationService {
    private let httpClient: any HTTPDataLoading
    private let translationMemoryStore: TranslationMemoryStore

    init(
        session: URLSession = .shared,
        translationMemoryStore: TranslationMemoryStore = TranslationMemoryStore()
    ) {
        httpClient = session
        self.translationMemoryStore = translationMemoryStore
    }

    init(
        httpClient: any HTTPDataLoading,
        translationMemoryStore: TranslationMemoryStore = TranslationMemoryStore()
    ) {
        self.httpClient = httpClient
        self.translationMemoryStore = translationMemoryStore
    }

    func translate(blocks: [OCRTextBlock], imageSize: CGSize, settings: AppSettings) async throws -> [InlineTranslationPatch] {
        let sources = InlineTranslationLayout.sources(from: blocks, imageSize: imageSize)
        guard !sources.isEmpty else {
            return []
        }

        let translations: [String: String]
        switch settings.translationProvider {
        case .offline:
            translations = offlineTranslations(for: sources, settings: settings)
        case .deepSeek, .translationMemory:
            translations = try await onlineTranslations(for: sources, settings: settings)
        }

        guard sources.allSatisfy({ translations[$0.id]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }) else {
            throw AppError.invalidTranslationResponse
        }

        return sources.map { source in
            InlineTranslationPatch(
                translatedText: translations[source.id]!.trimmingCharacters(in: .whitespacesAndNewlines),
                imageRect: source.imageRect
            )
        }
    }

    private func offlineTranslations(for sources: [InlineTranslationSource], settings: AppSettings) -> [String: String] {
        var translations: [String: String] = [:]
        let service = OfflineTranslationService()
        for source in sources {
            let result = service.translate(
                TranslationRequest(text: source.text, sourceLanguage: nil, targetLanguage: "中文", style: settings.translationStyle),
                settings: settings
            )
            translations[source.id] = result.translatedText
        }
        return translations
    }

    private func onlineTranslations(for sources: [InlineTranslationSource], settings: AppSettings) async throws -> [String: String] {
        let usesMemory = settings.translationMemoryEnabled || settings.translationProvider == .translationMemory
        guard usesMemory else {
            return try await deepSeekTranslations(for: sources, settings: settings)
        }

        var translations: [String: String] = [:]
        var misses: [InlineTranslationSource] = []
        for source in sources {
            let request = translationRequest(for: source, settings: settings)
            if let remembered = translationMemoryStore.lookup(request) {
                translations[source.id] = remembered.translatedText
            } else {
                misses.append(source)
            }
        }
        PerformanceMetrics.log("inline_translation_memory", metadata: "hits=\(translations.count) misses=\(misses.count)")

        guard !misses.isEmpty else {
            return translations
        }

        let requestSources = uniqueSources(from: misses)
        PerformanceMetrics.log(
            "inline_translation_deduplication",
            metadata: "source_blocks=\(misses.count) request_blocks=\(requestSources.count)"
        )
        let fetched = try await deepSeekTranslations(for: requestSources, settings: settings)
        let representativeIDs = Dictionary(uniqueKeysWithValues: requestSources.map { ($0.text, $0.id) })
        for source in misses {
            guard let representativeID = representativeIDs[source.text],
                  let translatedText = fetched[representativeID]
            else {
                continue
            }
            translations[source.id] = translatedText
        }
        for source in requestSources {
            guard let translatedText = fetched[source.id] else {
                continue
            }
            translationMemoryStore.remember(
                TranslationResult(
                    sourceText: source.text,
                    translatedText: translatedText,
                    sourceLanguage: nil,
                    targetLanguage: "中文",
                    provider: .deepSeek
                ),
                style: settings.translationStyle
            )
        }
        return translations
    }

    private func uniqueSources(from sources: [InlineTranslationSource]) -> [InlineTranslationSource] {
        var seen: Set<String> = []
        return sources.filter { seen.insert($0.text).inserted }
    }

    private func translationRequest(for source: InlineTranslationSource, settings: AppSettings) -> TranslationRequest {
        TranslationRequest(
            text: source.text,
            sourceLanguage: nil,
            targetLanguage: "中文",
            style: settings.translationStyle
        )
    }

    private func deepSeekTranslations(for sources: [InlineTranslationSource], settings: AppSettings) async throws -> [String: String] {
        let apiKey = settings.deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw AppError.missingAPIKey
        }
        guard let url = URL(string: settings.deepSeekBaseURL) else {
            throw URLError(.badURL)
        }

        let sourceMap = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0.text) })
        let sourceJSON = try JSONEncoder().encode(sourceMap)
        let sourceText = String(decoding: sourceJSON, as: UTF8.self)
        let glossary = settings.glossaryTerms.map { "\($0.source) => \($0.target)" }.joined(separator: "\n")

        let payload = InlineChatCompletionRequest(
            model: settings.deepSeekModel,
            messages: [
                .init(
                    role: "system",
                    content: """
                    Translate each JSON value to Simplified Chinese. Preserve every JSON key exactly and return only one JSON object with string values. \(settings.translationStyle.instruction)
                    \(glossary.isEmpty ? "" : "Use this glossary exactly when applicable:\n\(glossary)")
                    """
                ),
                .init(role: "user", content: sourceText)
            ],
            temperature: 0.2
        )

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let requestStartedAt = PerformanceMetrics.start()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await httpClient.data(for: request)
            PerformanceMetrics.log(
                "inline_ai_request",
                since: requestStartedAt,
                metadata: "outcome=success blocks=\(sources.count) request_bytes=\(request.httpBody?.count ?? 0) response_bytes=\(data.count)"
            )
        } catch {
            PerformanceMetrics.log(
                "inline_ai_request",
                since: requestStartedAt,
                metadata: "outcome=error blocks=\(sources.count) request_bytes=\(request.httpBody?.count ?? 0)"
            )
            throw error
        }
        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw NSError(domain: "InlineTranslationService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: message
            ])
        }

        let parsingStartedAt = PerformanceMetrics.start()
        let decoded = try JSONDecoder().decode(InlineChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AppError.invalidTranslationResponse
        }
        let translations = try decodeTranslationMap(content)
        PerformanceMetrics.log("inline_ai_response_parsing", since: parsingStartedAt, metadata: "translations=\(translations.count)")
        return translations
    }

    private func decodeTranslationMap(_ content: String) throws -> [String: String] {
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = cleaned.data(using: .utf8),
              let translations = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            throw AppError.invalidTranslationResponse
        }
        return translations
    }
}

private struct InlineChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct InlineChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}
