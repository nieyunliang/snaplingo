import AppKit
import ScreenCaptureKit
import XCTest
@testable import Snaplingo

final class SettingsTests: XCTestCase {
    func testTranslationStylesExposeUserFacingNamesAndInstructions() {
        XCTAssertEqual(TranslationStyle.allCases.count, 4)
        for style in TranslationStyle.allCases {
            XCTAssertFalse(style.displayName.isEmpty)
            XCTAssertFalse(style.instruction.isEmpty)
        }
    }

    @MainActor
    func testGlossaryParsesMultipleSeparatorStyles() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!)
        settings.glossaryText = """
        Snaplingo=截图翻译
        OCR：文字识别
        token => 令牌
        """

        XCTAssertEqual(settings.glossaryTerms.map(\.source), ["Snaplingo", "OCR", "token"])
        XCTAssertEqual(settings.glossaryTerms.map(\.target), ["截图翻译", "文字识别", "令牌"])
    }

    @MainActor
    func testDefaultHotkeyUsesUnifiedOptionACaptureShortcut() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!)
        let shortcuts = Dictionary(uniqueKeysWithValues: settings.hotkeys.map { ($0.action, $0.displayText) })

        XCTAssertEqual(settings.hotkeys.count, 1)
        XCTAssertEqual(shortcuts[.capture], "Option + A")
    }

    @MainActor
    func testLegacyHotkeyPayloadResetsToUnifiedCaptureShortcut() {
        let defaults = UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!
        defaults.set(Data("""
        [{"action":"captureArea","keyCode":7,"modifiers":1179648,"keyEquivalent":"x"}]
        """.utf8), forKey: "hotkeys")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.hotkeys, [HotkeyAction.capture.defaultShortcut])
    }

    @MainActor
    func testDeepSeekDefaultsUseDocumentedEndpointAndModel() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!)

        XCTAssertEqual(settings.translationProvider, .deepSeek)
        XCTAssertEqual(settings.deepSeekModel, "deepseek-v4-flash")
        XCTAssertEqual(settings.deepSeekBaseURL, "https://api.deepseek.com/chat/completions")
    }

    @MainActor
    func testDeepSeekAPIKeySavesToLocalDefaults() {
        let defaults = UserDefaults(suiteName: "SnaplingoTests-\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults)
        settings.deepSeekAPIKey = "local-test-key"

        settings.saveDeepSeekAPIKey()

        XCTAssertEqual(defaults.string(forKey: "deepSeekAPIKey"), "local-test-key")
        XCTAssertEqual(AppSettings(defaults: defaults).deepSeekAPIKey, "local-test-key")
    }

    @MainActor
    func testApplicationMenuRoutesCommandVToFirstResponderPasteAction() throws {
        let mainMenu = ApplicationMenu.makeMainMenu()
        let editMenu = try XCTUnwrap(mainMenu.items.compactMap(\.submenu).first { $0.title == "编辑" })
        let pasteItem = try XCTUnwrap(editMenu.items.first { $0.keyEquivalent == "v" })

        XCTAssertEqual(pasteItem.action, #selector(NSText.paste(_:)))
        XCTAssertEqual(pasteItem.keyEquivalentModifierMask, [.command])
        XCTAssertNil(pasteItem.target)
    }

    func testPermissionGuideRecognizesScreenCaptureDeniedErrors() {
        let deniedError = NSError(domain: SCStreamErrorDomain, code: SCStreamError.userDeclined.rawValue)
        let wrappedError = NSError(
            domain: NSCocoaErrorDomain,
            code: 1,
            userInfo: [NSUnderlyingErrorKey: deniedError]
        )
        let unrelatedError = NSError(
            domain: NSCocoaErrorDomain,
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Unable to validate display permission state."]
        )

        XCTAssertTrue(PermissionGuide.isScreenCapturePermissionError(deniedError))
        XCTAssertTrue(PermissionGuide.isScreenCapturePermissionError(wrappedError))
        XCTAssertFalse(PermissionGuide.isScreenCapturePermissionError(unrelatedError))
        XCTAssertFalse(PermissionGuide.isScreenCapturePermissionError(AppError.captureFailed))
    }
}
