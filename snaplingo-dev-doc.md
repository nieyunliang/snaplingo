# Mac Screenshot Translator 开发文档

> 归档说明：本文保留最初的产品规划。截图保存、历史记录、独立结果面板和完整标注编辑器均不属于当前版本；当前行为以 `docs/功能文档.md` 和 `README.md` 为准。

## 1. 项目概述

### 1.1 产品定位

Mac Screenshot Translator 是一款面向 macOS 的截图翻译工具，核心目标是让用户在看到屏幕上的外语内容时，可以通过快捷键快速截图、识别文字、翻译并复制结果。

产品核心链路：

```text
快捷键唤起 -> 框选截图 -> OCR 识别 -> 翻译 -> 展示/复制/保存
```

### 1.2 目标用户

- 开发者：阅读英文文档、报错、GitHub issue、技术博客。
- 学生/研究者：阅读论文、PDF、课程材料。
- 设计/产品人员：阅读海外产品界面、竞品截图、设计说明。
- 办公用户：处理邮件、网页、图片中的外语文本。

### 1.3 MVP 目标

第一版优先完成最短闭环：

- 菜单栏常驻 App。
- 支持全局快捷键唤起区域截图。
- 支持截图后 OCR。
- 支持用户手动触发 OCR 结果翻译为中文。
- 支持浮窗展示原文和译文。
- 支持复制图片、复制原文、复制译文。
- 支持保存截图。
- 支持基础设置：快捷键、目标语言、API Key。

## 2. 功能需求

### 2.1 截图功能

#### 2.1.1 区域截图

用户按下快捷键后进入截图模式，可以拖拽选择屏幕区域。

功能要求：

- 显示半透明遮罩。
- 鼠标拖拽生成选区。
- 选区边缘可调整大小。
- 选区旁显示宽高信息。
- 松开鼠标后确认截图。
- 支持 `Esc` 取消截图。
- 支持 Retina 屏幕高清截图。
- 支持多显示器。

验收标准：

- 用户可以在任意屏幕区域完成截图。
- 截图结果与选区视觉范围一致。
- 截图取消后不产生历史记录或浮窗。

#### 2.1.2 全屏截图

用户可通过菜单或快捷键执行全屏截图。

功能要求：

- 截取当前主屏幕。
- 后续版本支持选择某个显示器。
- 截图后进入与区域截图相同的处理流程。

#### 2.1.3 窗口截图

后续版本支持窗口截图。

功能要求：

- 鼠标悬停窗口时高亮窗口边界。
- 点击后截取窗口区域。
- 可选是否包含窗口阴影。

### 2.2 OCR 功能

#### 2.2.1 图片文字识别

截图完成后，系统对图片进行 OCR 识别。

功能要求：

- 支持英文和中文识别。
- 支持自动检测文字方向。
- 支持保留基本换行。
- OCR 结果可复制。
- OCR 失败时显示错误提示。

推荐实现：

- macOS 原生方案：`Vision` framework。
- 云端扩展方案：第三方 OCR API。

验收标准：

- 常见网页、PDF、应用界面中的英文文本可被识别。
- OCR 过程中 UI 不阻塞。
- 识别失败不影响截图图片保存和复制。

#### 2.2.2 OCR 语言设置

用户可以在设置中配置 OCR 语言。

功能要求：

- 自动检测。
- 中文简体。
- 中文繁体。
- 英文。
- 日文。
- 韩文。

MVP 可先支持：

- 自动检测。
- 中文。
- 英文。

### 2.3 翻译功能

#### 2.3.1 手动翻译

用户点击翻译后，应用识别截图文字并将结果翻译为目标语言。

功能要求：

- 支持源语言自动识别。
- 支持目标语言配置。
- 默认目标语言为中文。
- 翻译结果展示在浮窗中。
- 支持重新翻译。
- 支持复制译文。

验收标准：

- 用户点击翻译后触发 OCR 和翻译。
- 翻译失败时显示可重试状态。

#### 2.3.2 翻译服务

MVP 推荐支持一种服务，后续扩展多服务。

可选服务：

- OpenAI API：适合自然语言翻译、上下文润色和专业风格。
- DeepL：适合高质量通用翻译。
- Google Translate：覆盖语言广。
- 本地模型：适合离线场景。

MVP 建议：

- 先支持 OpenAI API 或系统翻译能力。
- 设置页允许用户填写 API Key。
- API Key 存储到本地应用偏好设置。

#### 2.3.3 翻译风格

后续版本支持翻译风格配置。

选项：

- 自然：默认模式，译文流畅。
- 直译：尽量保留原句结构。
- 专业：适合技术、学术、商务场景。
- 简洁：压缩表达，只保留核心意思。

### 2.4 结果浮窗

截图处理完成后显示结果浮窗。

#### 2.4.1 浮窗布局

浮窗包含：

- 截图缩略图。
- OCR 原文。
- 翻译结果。
- 操作按钮。

操作按钮：

- 复制图片。
- 复制原文。
- 复制译文。
- 保存图片。
- 重新识别。
- 重新翻译。
- 关闭。

#### 2.4.2 显示模式

MVP 支持：

- 对照模式：上方原文，下方译文。

后续支持：

- 简洁模式：只显示译文。
- 图片模式：左图右文。
- 固定模式：浮窗置顶，方便对照阅读。

验收标准：

- 浮窗不遮挡系统截图流程。
- 浮窗可拖拽移动。
- 复制操作有明确反馈。
- 关闭后可在历史记录中找到结果。

### 2.5 截图编辑

MVP 可先不做完整编辑器，只提供基础能力。

P1 功能：

- 矩形。
- 箭头。
- 文字。
- 高亮。
- 马赛克。
- 撤销/重做。

P2 功能：

- 序号标注。
- 聚光灯。
- 局部放大。
- 自动敏感信息打码。

### 2.6 历史记录

MVP 可做轻量历史，或作为 P1。

功能要求：

- 保存截图时间。
- 保存截图图片路径。
- 保存 OCR 原文。
- 保存翻译结果。
- 支持搜索。
- 支持删除单条记录。
- 支持一键清空。

历史记录字段：

```text
id
createdAt
imagePath
ocrText
translatedText
sourceLanguage
targetLanguage
appName
isFavorite
```

## 3. 非功能需求

### 3.1 性能要求

- 截图模式启动时间小于 200ms。
- 区域截图完成后 1 秒内展示图片预览。
- 常规 OCR 处理时间小于 2 秒。
- 常规翻译时间小于 3 秒。
- OCR 和翻译必须异步执行，不能阻塞主线程。

### 3.2 稳定性要求

- OCR 失败不影响截图保存。
- 翻译失败不影响 OCR 结果展示。
- 网络失败时显示错误和重试按钮。
- API Key 缺失时引导用户到设置页。
- 多显示器切换时不崩溃。

### 3.3 隐私要求

- 首次使用时说明哪些内容会上传。
- 翻译仅在用户主动点击后执行。
- API Key 使用本地应用偏好设置存储。
- 本地截图文件可设置自动清理周期。

### 3.4 可用性要求

- 支持深色模式。
- 支持自定义快捷键。
- 支持菜单栏快速入口。
- 支持开机启动。
- 常用操作不超过两次点击。

## 4. macOS 权限需求

### 4.1 屏幕录制权限

用途：

- 截取屏幕内容。

用户引导：

- 首次截图前检查权限。
- 若未授权，弹窗解释用途。
- 提供跳转系统设置按钮。

### 4.2 辅助功能权限

用途：

- 后续窗口截图。
- 后续滚动截图。
- 获取当前应用信息。

MVP 可选，不应作为启动阻塞项。

### 4.3 文件访问权限

用途：

- 保存截图。
- 读取用户拖入图片。

实现建议：

- 默认保存到 App 沙盒目录或用户选择目录。
- 用户选择保存目录后通过安全书签持久化访问权限。

### 4.4 网络权限

用途：

- 调用翻译服务。

要求：

- 网络失败时提示。
- 支持超时控制。
- 支持取消请求。

## 5. 推荐技术架构

### 5.1 技术选型建议

首选方案：

```text
Swift + SwiftUI + AppKit
```

原因：

- 截图、菜单栏、全局快捷键、权限、浮窗体验更贴近 macOS。
- 可以直接使用 Apple Vision 做 OCR。
- 更容易处理多显示器和窗口层级。

备选方案：

```text
Flutter macOS
```

优点：

- UI 开发效率高。
- 跨平台潜力好。

缺点：

- macOS 原生截图、权限、菜单栏、全局快捷键仍需写 native plugin。

不优先推荐：

```text
Electron
```

原因：

- 体积偏大。
- 原生截图和权限体验不如 Swift 直接。
- 菜单栏工具类 App 用户更在意轻量和响应速度。

### 5.2 模块划分

```text
App
├── AppShell
│   ├── MenuBarController
│   ├── AppSettings
│   └── PermissionGuide
├── Screenshot
│   ├── ScreenshotCoordinator
│   ├── ScreenCaptureService
│   ├── SelectionOverlayWindow
│   └── ScreenshotResult
├── OCR
│   ├── OCRService
│   ├── VisionOCRService
│   └── OCRResult
├── Translation
│   ├── TranslationService
│   ├── OpenAITranslationService
│   ├── TranslationRequest
│   └── TranslationResult
├── ResultPanel
│   ├── ResultPanelWindow
│   ├── ResultPanelView
│   └── ResultPanelViewModel
├── History
│   ├── HistoryStore
│   ├── HistoryItem
│   └── HistoryListView
└── Shared
    ├── ClipboardService
    ├── AppSettings
    ├── HotkeyService
    └── Logger
```

### 5.3 数据流

```text
User Hotkey
    ↓
ScreenshotCoordinator.startSelection()
    ↓
SelectionOverlayWindow returns selectedRect
    ↓
ScreenCaptureService.capture(rect)
    ↓
ScreenshotResult(image)
    ↓
OCRService.recognize(image)
    ↓
OCRResult(text, language)
    ↓
TranslationService.translate(text)
    ↓
TranslationResult(text)
    ↓
ResultPanelViewModel updates UI
    ↓
User copies/saves/history
```

## 6. 数据模型草案

### 6.1 ScreenshotResult

```swift
struct ScreenshotResult {
    let id: UUID
    let image: NSImage
    let screenRect: CGRect
    let scale: CGFloat
    let createdAt: Date
}
```

### 6.2 OCRResult

```swift
struct OCRResult {
    let text: String
    let language: String?
    let confidence: Double?
    let blocks: [OCRTextBlock]
}

struct OCRTextBlock {
    let text: String
    let boundingBox: CGRect
    let confidence: Double?
}
```

### 6.3 TranslationResult

```swift
struct TranslationResult {
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String?
    let targetLanguage: String
    let provider: TranslationProvider
}

enum TranslationProvider {
    case openAI
    case deepL
    case system
}
```

### 6.4 HistoryItem

```swift
struct HistoryItem: Identifiable {
    let id: UUID
    let createdAt: Date
    let imagePath: String
    let ocrText: String
    let translatedText: String
    let sourceLanguage: String?
    let targetLanguage: String
    let appName: String?
    var isFavorite: Bool
}
```

## 7. API 设计草案

### 7.1 OCRService

```swift
protocol OCRService {
    func recognize(image: NSImage, languages: [String]) async throws -> OCRResult
}
```

### 7.2 TranslationService

```swift
protocol TranslationService {
    func translate(_ request: TranslationRequest) async throws -> TranslationResult
}

struct TranslationRequest {
    let text: String
    let sourceLanguage: String?
    let targetLanguage: String
    let style: TranslationStyle
}

enum TranslationStyle {
    case natural
    case literal
    case professional
    case concise
}
```

### 7.3 ClipboardService

```swift
protocol ClipboardService {
    func copyImage(_ image: NSImage)
    func copyText(_ text: String)
}
```

## 8. UI 页面规划

### 8.1 菜单栏

菜单项：

- 截图翻译
- 全屏截图
- 打开历史记录
- 设置
- 退出

### 8.2 截图选择层

元素：

- 全屏遮罩。
- 选区矩形。
- 选区尺寸提示。
- 鼠标附近放大镜，P1。

交互：

- 拖拽创建选区。
- `Esc` 取消。
- `Enter` 确认，P1。
- 拖动边缘调整选区，P1。

### 8.3 结果浮窗

区域：

- 图片预览区。
- 原文区。
- 译文区。
- 操作按钮区。

状态：

- OCR 识别中。
- OCR 成功。
- OCR 失败。
- 翻译中。
- 翻译成功。
- 翻译失败。

### 8.4 设置页

设置项：

- 截图快捷键。
- 默认目标语言。
- 自动 OCR 开关。
- 翻译服务选择。
- API Key 配置。
- 截图保存目录。
- 历史记录开关。
- 开机启动。

## 9. 错误处理

### 9.1 权限错误

场景：

- 没有屏幕录制权限。

处理：

- 显示权限说明。
- 提供跳转系统设置按钮。
- 用户授权后支持重新检测。

### 9.2 OCR 错误

场景：

- 图片无文字。
- 图片过小。
- Vision 识别失败。

处理：

- 展示“未识别到文字”。
- 允许用户复制图片或保存图片。
- 提供重新识别按钮。

### 9.3 翻译错误

场景：

- 未配置 API Key。
- 网络超时。
- API 限流。
- 翻译服务返回错误。

处理：

- 展示明确错误原因。
- 提供设置入口。
- 提供重试按钮。

## 10. 开发里程碑

### Milestone 1：基础 App 壳

目标：

- 创建 macOS App。
- 菜单栏常驻。
- 设置页基础结构。
- 全局快捷键注册。

交付物：

- 可以通过快捷键触发空动作。
- 菜单栏菜单可用。

### Milestone 2：截图闭环

目标：

- 区域截图。
- 截图预览浮窗。
- 复制图片。
- 保存图片。

交付物：

- 用户可以完成截图并复制/保存。

### Milestone 3：OCR 闭环

目标：

- 集成 Vision OCR。
- 截图后自动识别文字。
- 展示原文。
- 复制原文。

交付物：

- 用户可以从截图中提取文本。

### Milestone 4：翻译闭环

目标：

- 集成翻译服务。
- 用户点击后执行 OCR 和翻译。
- 展示译文。
- 复制译文。

交付物：

- 完整完成“截图 -> OCR -> 翻译 -> 复制”链路。

### Milestone 5：体验打磨

目标：

- 权限引导。
- 错误状态。
- 加载状态。
- 设置持久化。
- 基础历史记录。

交付物：

- 可作为 Alpha 版本内部使用。

## 11. 测试计划

### 11.1 功能测试

- 区域截图是否准确。
- 全屏截图是否准确。
- 多显示器截图是否准确。
- OCR 是否能识别网页文字。
- OCR 是否能识别 PDF 文字。
- 翻译是否能正确返回结果。
- 复制图片、原文、译文是否成功。
- 保存截图路径是否正确。

### 11.2 权限测试

- 首次启动未授权状态。
- 授权后重新检测。
- 用户拒绝授权。
- 用户在系统设置中撤销授权。

### 11.3 边界测试

- 选区极小。
- 选区跨显示器。
- 图片无文字。
- 网络断开。
- API Key 错误。
- 翻译服务超时。
- 大尺寸截图。

### 11.4 体验测试

- 快捷键冲突。
- 深色模式。
- Retina 屏幕。
- 浮窗置顶。
- 浮窗拖动。
- App 退出和重新启动。

## 12. 后续扩展方向

- 滚动截图。
- 截图标注编辑器。
- 离线 OCR。
- 离线翻译。
- 表格识别。
- 代码识别与解释。
- 术语表。
- 翻译记忆。
- 图片拖拽 OCR。
- 截图结果导出为 Markdown。
- iCloud 同步历史记录。

## 13. MVP 开发任务清单

- [x] 创建 macOS App 工程。
- [x] 实现菜单栏入口。
- [x] 实现全局快捷键。
- [x] 实现屏幕录制权限检测。
- [x] 实现区域截图遮罩。
- [x] 实现截图保存。
- [x] 实现复制图片到剪贴板。
- [x] 集成 Vision OCR。
- [x] 实现 OCR 结果展示。
- [x] 实现复制 OCR 原文。
- [x] 集成翻译服务。
- [x] 实现译文展示。
- [x] 实现复制译文。
- [x] 实现设置页。
- [x] 实现 API Key 安全存储。
- [x] 实现错误提示和重试。
- [x] 实现基础历史记录。

## 14. 当前实现状态

本文前半部分保留最初的产品方案和结构草案。当前实现已经收敛为截图后的原位编辑流程，不再使用独立结果面板或完整标注编辑器。

运行方式：

```bash
./scripts/run-app.sh
```

验证命令：

```bash
swift build
swift test
bash -n scripts/run-app.sh
bash -n scripts/build-dmg.sh
```

当前测试覆盖：

- 覆盖翻译风格、选择框 resize/move 几何逻辑。
- 覆盖 Vision OCR 的渲染文字图片识别。
- 覆盖图内批量翻译请求/响应和缺少 API Key 的错误路径。
- 覆盖术语表解析、离线翻译和翻译记忆。

已完成到 MVP 级别的后续功能：

- 窗口截图悬停高亮和可选阴影。
- 原位截图浮层：箭头、矩形、圆形、撤销、图内翻译、复制和关闭。
- Vision OCR 和离线翻译 MVP。
- 术语表和翻译记忆。

仍未完成的后续功能：

- 完整 iCloud 同步，包括 entitlements、容器冲突处理和跨设备数据合并。
- 生产级滚动截图拼接，包括 Accessibility-aware 容器跟踪。
- 完整标注编辑器、敏感信息自动打码、表格识别和 Markdown 导出。
- 真实屏幕截图 smoke test，需在已授予 Screen Recording 权限的 macOS 环境中执行。
- 权限拒绝 UI 流程自动化测试。
