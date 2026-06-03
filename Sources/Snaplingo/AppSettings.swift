import AppKit
import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginService.setEnabled(launchAtLogin)
        }
    }

    @Published var translationProvider: TranslationProvider {
        didSet { defaults.set(translationProvider.rawValue, forKey: Keys.translationProvider) }
    }

    @Published var translationStyle: TranslationStyle {
        didSet { defaults.set(translationStyle.rawValue, forKey: Keys.translationStyle) }
    }

    @Published var deepSeekModel: String {
        didSet { defaults.set(deepSeekModel, forKey: Keys.deepSeekModel) }
    }

    @Published var deepSeekBaseURL: String {
        didSet { defaults.set(deepSeekBaseURL, forKey: Keys.deepSeekBaseURL) }
    }

    @Published var ocrLanguages: [String] {
        didSet { defaults.set(ocrLanguages, forKey: Keys.ocrLanguages) }
    }

    @Published var includeWindowShadow: Bool {
        didSet { defaults.set(includeWindowShadow, forKey: Keys.includeWindowShadow) }
    }

    @Published var translationMemoryEnabled: Bool {
        didSet { defaults.set(translationMemoryEnabled, forKey: Keys.translationMemoryEnabled) }
    }

    @Published var glossaryText: String {
        didSet { defaults.set(glossaryText, forKey: Keys.glossaryText) }
    }

    @Published var hotkeys: [HotkeyBinding] {
        didSet { saveHotkeys() }
    }

    @Published var deepSeekAPIKey: String = ""

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false

        let providerRaw = defaults.string(forKey: Keys.translationProvider) ?? TranslationProvider.deepSeek.rawValue
        translationProvider = TranslationProvider.settingsValue(for: providerRaw)

        let styleRaw = defaults.string(forKey: Keys.translationStyle) ?? TranslationStyle.natural.rawValue
        translationStyle = TranslationStyle(rawValue: styleRaw) ?? .natural

        deepSeekModel = defaults.string(forKey: Keys.deepSeekModel)
            ?? defaults.string(forKey: Keys.legacyProviderModel)
            ?? "deepseek-v4-flash"
        deepSeekBaseURL = defaults.string(forKey: Keys.deepSeekBaseURL)
            ?? defaults.string(forKey: Keys.legacyProviderBaseURL)
            ?? "https://api.deepseek.com/chat/completions"
        ocrLanguages = defaults.stringArray(forKey: Keys.ocrLanguages) ?? ["en-US", "zh-Hans"]
        includeWindowShadow = defaults.object(forKey: Keys.includeWindowShadow) as? Bool ?? false
        translationMemoryEnabled = defaults.object(forKey: Keys.translationMemoryEnabled) as? Bool ?? true
        glossaryText = defaults.string(forKey: Keys.glossaryText) ?? ""
        hotkeys = Self.loadHotkeys(from: defaults)
        deepSeekAPIKey = defaults.string(forKey: Keys.deepSeekAPIKey) ?? ""
    }

    func saveDeepSeekAPIKey() {
        defaults.set(deepSeekAPIKey, forKey: Keys.deepSeekAPIKey)
    }

    private static func loadHotkeys(from defaults: UserDefaults) -> [HotkeyBinding] {
        if let data = defaults.data(forKey: Keys.hotkeys),
           let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) {
            return HotkeyAction.allCases.map { action in
                decoded.first { $0.action == action } ?? action.defaultShortcut
            }
        }

        let defaultsHotkeys = HotkeyAction.allCases.map(\.defaultShortcut)
        if let data = try? JSONEncoder().encode(defaultsHotkeys) {
            defaults.set(data, forKey: Keys.hotkeys)
        }
        return defaultsHotkeys
    }

    private func saveHotkeys() {
        guard let data = try? JSONEncoder().encode(hotkeys) else {
            return
        }
        defaults.set(data, forKey: Keys.hotkeys)
    }

    var glossaryTerms: [GlossaryTerm] {
        glossaryText
            .components(separatedBy: .newlines)
            .compactMap { line -> GlossaryTerm? in
                let separators = ["=>", "=", ":", "："]
                guard let separator = separators.first(where: { line.contains($0) }) else {
                    return nil
                }
                let parts = line.components(separatedBy: separator)
                guard parts.count >= 2 else {
                    return nil
                }
                let source = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let target = parts.dropFirst().joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !source.isEmpty, !target.isEmpty else {
                    return nil
                }
                return GlossaryTerm(source: source, target: target)
            }
    }
}

private enum Keys {
    static let launchAtLogin = "launchAtLogin"
    static let translationProvider = "translationProvider"
    static let translationStyle = "translationStyle"
    static let deepSeekModel = "deepSeekModel"
    static let deepSeekBaseURL = "deepSeekBaseURL"
    static let deepSeekAPIKey = "deepSeekAPIKey"
    static let legacyProviderModel = "openAIModel"
    static let legacyProviderBaseURL = "openAIBaseURL"
    static let ocrLanguages = "ocrLanguages"
    static let includeWindowShadow = "includeWindowShadow"
    static let translationMemoryEnabled = "translationMemoryEnabled"
    static let glossaryText = "glossaryText"
    static let hotkeys = "hotkeys"
}

enum Constants {
    static let appName = "Snaplingo"
}
