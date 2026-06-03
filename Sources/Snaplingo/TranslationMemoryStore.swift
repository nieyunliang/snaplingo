import Foundation

@MainActor
final class TranslationMemoryStore {
    private(set) var entries: [TranslationMemoryEntry] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let folder = (support ?? URL(fileURLWithPath: NSTemporaryDirectory()))
                .appendingPathComponent(Constants.appName)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.fileURL = folder.appendingPathComponent("translation-memory.json")
        }
        load()
    }

    func lookup(_ request: TranslationRequest) -> TranslationResult? {
        let normalized = Self.normalized(request.text)
        guard let entry = entries.first(where: {
            Self.normalized($0.sourceText) == normalized
                && $0.targetLanguage == request.targetLanguage
                && $0.style == request.style
        }) else {
            return nil
        }

        return TranslationResult(
            sourceText: request.text,
            translatedText: entry.translatedText,
            sourceLanguage: entry.sourceLanguage,
            targetLanguage: entry.targetLanguage,
            provider: .translationMemory
        )
    }

    func remember(_ result: TranslationResult, style: TranslationStyle) {
        guard !result.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !result.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              result.provider != .translationMemory
        else {
            return
        }

        let normalized = Self.normalized(result.sourceText)
        entries.removeAll {
            Self.normalized($0.sourceText) == normalized
                && $0.targetLanguage == result.targetLanguage
                && $0.style == style
        }
        entries.insert(
            TranslationMemoryEntry(
                sourceText: result.sourceText,
                translatedText: result.translatedText,
                sourceLanguage: result.sourceLanguage,
                targetLanguage: result.targetLanguage,
                style: style,
                createdAt: Date()
            ),
            at: 0
        )
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([TranslationMemoryEntry].self, from: data)
        else {
            return
        }
        entries = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}
