import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(settings: AppSettings) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(settings: settings)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 780),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Snaplingo 设置"
        window.contentMinSize = NSSize(width: 680, height: 640)
        window.contentViewController = NSHostingController(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var deepSeekAPIKeyDraft = ""
    @State private var saveMessage = ""

    var body: some View {
        Form {
            Section("快捷键") {
                ForEach(settings.hotkeys) { hotkey in
                    HStack {
                        Text(hotkey.action.displayName)
                        Spacer()
                        Text(hotkey.displayText)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("识别与翻译") {
                Picker("翻译风格", selection: $settings.translationStyle) {
                    ForEach(TranslationStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                TextField("OCR 语言，用逗号分隔", text: Binding(
                    get: { settings.ocrLanguages.joined(separator: ", ") },
                    set: { value in
                        settings.ocrLanguages = value
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    }
                ))
                Toggle("启用翻译记忆", isOn: $settings.translationMemoryEnabled)
                TextEditor(text: $settings.glossaryText)
                    .frame(minHeight: 86)
                    .overlay(alignment: .topLeading) {
                        if settings.glossaryText.isEmpty {
                            Text("术语表：每行 source=target")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                        }
                    }
            }

            Section("DeepSeek") {
                Picker("翻译服务", selection: $settings.translationProvider) {
                    ForEach(TranslationProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                TextField("DeepSeek 模型", text: $settings.deepSeekModel)
                TextField("DeepSeek 接口地址", text: $settings.deepSeekBaseURL)
                TextField("DeepSeek API Key", text: $deepSeekAPIKeyDraft)
                Button("保存 DeepSeek API Key") {
                    settings.deepSeekAPIKey = deepSeekAPIKeyDraft
                    settings.saveDeepSeekAPIKey()
                    saveMessage = "DeepSeek API Key 已保存到本地"
                }
                if !saveMessage.isEmpty {
                    Text(saveMessage)
                        .foregroundStyle(.secondary)
                }
            }

            Section("通用") {
                Toggle("窗口截图包含阴影", isOn: $settings.includeWindowShadow)
                Toggle("开机启动", isOn: $settings.launchAtLogin)
            }

            Section("权限") {
                HStack {
                    Text("屏幕录制权限")
                    Spacer()
                    Text(PermissionGuide.hasScreenRecordingPermission ? "已授权" : "未确认")
                        .foregroundStyle(.secondary)
                }
                Button("请求屏幕录制权限") {
                    _ = PermissionGuide.requestScreenRecordingPermission()
                }
                Button("打开系统权限设置") {
                    PermissionGuide.openScreenRecordingSettings()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            deepSeekAPIKeyDraft = settings.deepSeekAPIKey
        }
    }
}
