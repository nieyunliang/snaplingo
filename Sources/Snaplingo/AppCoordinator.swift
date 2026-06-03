import AppKit

@MainActor
final class AppCoordinator {
    let settings = AppSettings()

    private let captureService = ScreenCaptureService()
    private let ocrService = VisionOCRService()
    private let inlineTranslationService = InlineTranslationService()
    private let clipboard = ClipboardService()
    private let overlayController = SelectionOverlayController()
    private let inlineCaptureEditorController = InlineCaptureEditorController()
    private let settingsWindowController = SettingsWindowController()
    private let hotkeyService = HotkeyService()

    private var menuBarController: MenuBarController?

    func start() {
        menuBarController = MenuBarController(coordinator: self)
        hotkeyService.start(settings: settings) { [weak self] action in
            self?.performHotkeyAction(action)
        }
    }

    func capture() {
        guard PermissionGuide.hasScreenRecordingPermission else {
            presentScreenRecordingPermissionGuide()
            return
        }
        Task { @MainActor in
            do {
                let candidates = try await captureService.listCapturableWindows()
                overlayController.beginSelection(candidates: candidates) { [weak self] request, dismissSelection in
                    guard let self, let request else {
                        dismissSelection()
                        return
                    }
                    self.capture(request: request, dismissSelection: dismissSelection)
                }
            } catch {
                presentError(error)
            }
        }
    }

    private func capture(request: CaptureRequest, dismissSelection: @escaping () -> Void) {
        Task { @MainActor in
            do {
                let screenshot = try await captureService.capture(
                    selection: request.selection,
                    includeWindowShadow: settings.includeWindowShadow
                )
                switch request.action {
                case .finish:
                    clipboard.copyImage(screenshot.image)
                    dismissSelection()
                case .annotate(let tool):
                    inlineCaptureEditorController.show(
                        screenshot: screenshot,
                        settings: settings,
                        ocrService: ocrService,
                        translationService: inlineTranslationService,
                        clipboard: clipboard,
                        initialDrawingTool: tool
                    )
                    dismissSelection()
                case .translate:
                    inlineCaptureEditorController.show(
                        screenshot: screenshot,
                        settings: settings,
                        ocrService: ocrService,
                        translationService: inlineTranslationService,
                        clipboard: clipboard,
                        startsTranslation: true
                    )
                    dismissSelection()
                case .save:
                    dismissSelection()
                    _ = try ImageFileExporter.promptAndWritePNG(screenshot.image)
                }
            } catch {
                dismissSelection()
                presentError(error)
            }
        }
    }

    func openSettings() {
        settingsWindowController.show(settings: settings)
    }

    private func presentScreenRecordingPermissionGuide() {
        let alert = NSAlert()
        alert.messageText = "需要屏幕录制权限"
        alert.informativeText = "Snaplingo 需要读取屏幕内容来完成截图、OCR 和翻译。如果你刚刚授权，请重新打开 Snaplingo 后再试。"
        alert.addButton(withTitle: "请求权限")
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            _ = PermissionGuide.requestScreenRecordingPermission()
        }
        if response == .alertSecondButtonReturn {
            PermissionGuide.openScreenRecordingSettings()
        }
    }

    private func presentError(_ error: Error) {
        if case AppError.screenRecordingDenied = error {
            presentScreenRecordingPermissionGuide()
            return
        }

        let alert = NSAlert(error: error)
        alert.runModal()
    }

    private func performHotkeyAction(_ action: HotkeyAction) {
        switch action {
        case .capture:
            capture()
        }
    }
}
