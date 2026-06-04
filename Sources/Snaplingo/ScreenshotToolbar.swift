import SwiftUI

struct ScreenshotToolbar: View {
    let state: ScreenshotToolbarState

    var body: some View {
        ScreenshotToolbarSurface {
            ScreenshotToolbarButton(
                systemImage: "arrow.up.right",
                help: "箭头",
                isActive: state.selectedTool == .arrow
            ) {
                state.selectTool(.arrow)
            }
            ScreenshotToolbarButton(
                systemImage: "rectangle",
                help: "矩形",
                isActive: state.selectedTool == .rectangle
            ) {
                state.selectTool(.rectangle)
            }
            ScreenshotToolbarButton(
                systemImage: "circle",
                help: "圆形",
                isActive: state.selectedTool == .circle
            ) {
                state.selectTool(.circle)
            }
            ScreenshotToolbarButton(
                systemImage: "arrow.uturn.backward",
                help: "撤销",
                isDisabled: !state.canUndo
            ) {
                state.undo()
            }
            ScreenshotToolbarButton(
                systemImage: "character.book.closed",
                help: "翻译",
                showsProgress: state.isTranslating,
                isActive: state.isTranslationVisible,
                isDisabled: state.isTranslating
            ) {
                state.toggleTranslation()
            }
            ScreenshotToolbarButton(systemImage: "square.and.arrow.down", help: "保存图片") {
                state.save()
            }
            ScreenshotToolbarDivider()
            ScreenshotToolbarButton(systemImage: "checkmark", help: "完成") {
                state.finish()
            }
            ScreenshotToolbarButton(systemImage: "xmark", help: "关闭") {
                state.close()
            }
            if !state.status.isEmpty {
                let icon = statusIcon
                Image(systemName: icon.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(icon.color)
                    .frame(width: 22, height: 34)
                    .help(state.status)
            }
        }
    }

    private var statusIcon: ToolbarStatusIcon {
        switch state.statusKind {
        case .failure:
            ToolbarStatusIcon(systemImage: "exclamationmark.circle.fill", color: .red)
        case .info:
            ToolbarStatusIcon(systemImage: "info.circle.fill", color: .blue)
        case .success, nil:
            ToolbarStatusIcon(systemImage: "checkmark.circle.fill", color: .green)
        }
    }

    private struct ToolbarStatusIcon {
        let systemImage: String
        let color: Color
    }
}

enum ScreenshotToolbarState {
    struct EditingState {
        var selectedTool: AnnotationTool?
        var canUndo = false
        var isTranslating = false
        var isTranslationVisible = false
        var status = ""
        var statusKind: InlineCaptureStatusKind?
        let selectTool: (AnnotationTool) -> Void
        let undo: () -> Void
        let toggleTranslation: () -> Void
        let save: () -> Void
        let finish: () -> Void
        let close: () -> Void
    }

    case selecting(
        onAction: (CaptureAction) -> Void,
        onClose: () -> Void
    )
    case editing(EditingState)

    var selectedTool: AnnotationTool? {
        if case .editing(let state) = self { return state.selectedTool }
        return nil
    }
    var canUndo: Bool {
        if case .editing(let state) = self { return state.canUndo }
        return false
    }
    var isTranslating: Bool {
        if case .editing(let state) = self { return state.isTranslating }
        return false
    }
    var isTranslationVisible: Bool {
        if case .editing(let state) = self { return state.isTranslationVisible }
        return false
    }
    var status: String {
        if case .editing(let state) = self { return state.status }
        return ""
    }
    var statusKind: InlineCaptureStatusKind? {
        if case .editing(let state) = self { return state.statusKind }
        return nil
    }

    var selectTool: (AnnotationTool) -> Void {
        switch self {
        case .selecting(let onAction, _): return { onAction(.annotate($0)) }
        case .editing(let state): return state.selectTool
        }
    }
    var undo: () -> Void {
        if case .editing(let state) = self { return state.undo }
        return {}
    }
    var toggleTranslation: () -> Void {
        switch self {
        case .selecting(let onAction, _): return { onAction(.translate) }
        case .editing(let state): return state.toggleTranslation
        }
    }
    var save: () -> Void {
        switch self {
        case .selecting(let onAction, _): return { onAction(.save) }
        case .editing(let state): return state.save
        }
    }
    var finish: () -> Void {
        switch self {
        case .selecting(let onAction, _): return { onAction(.finish) }
        case .editing(let state): return state.finish
        }
    }
    var close: () -> Void {
        switch self {
        case .selecting(_, let onClose): return onClose
        case .editing(let state): return state.close
        }
    }

    @MainActor
    static func makeEditing(
        document: InlineCaptureDocument,
        close: @escaping () -> Void
    ) -> ScreenshotToolbarState {
        .editing(EditingState(
            selectedTool: document.drawingTool,
            canUndo: document.canUndo,
            isTranslating: document.isTranslating,
            isTranslationVisible: document.isTranslationVisible,
            status: document.status,
            statusKind: document.statusKind,
            selectTool: { document.toggleDrawingTool($0) },
            undo: { document.undo() },
            toggleTranslation: { document.triggerTranslation() },
            save: { document.save() },
            finish: {
                document.copy()
                close()
            },
            close: close
        ))
    }
}

enum ScreenshotToolbarLayout {
    static let toolbarHeight: CGFloat = 50
    static let maxToolbarWidth: CGFloat = 430
    private static let spacing: CGFloat = 8

    static func size(fitting visibleFrame: CGRect) -> CGSize {
        CGSize(width: min(maxToolbarWidth, visibleFrame.width), height: toolbarHeight)
    }

    static func frame(near screenshotRect: CGRect, visibleFrame: CGRect, toolbarSize: CGSize) -> CGRect {
        let centeredX = clamped(
            screenshotRect.midX - toolbarSize.width / 2,
            minimum: visibleFrame.minX,
            maximum: visibleFrame.maxX - toolbarSize.width
        )
        let centeredY = clamped(
            screenshotRect.midY - toolbarSize.height / 2,
            minimum: visibleFrame.minY,
            maximum: visibleFrame.maxY - toolbarSize.height
        )
        let candidates: [CGRect] = [
            CGRect(x: centeredX, y: screenshotRect.minY - toolbarSize.height - spacing, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: centeredX, y: screenshotRect.maxY + spacing, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: screenshotRect.maxX + spacing, y: centeredY, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: screenshotRect.minX - toolbarSize.width - spacing, y: centeredY, width: toolbarSize.width, height: toolbarSize.height),
        ]

        if let match = candidates.first(where: { visibleFrame.contains($0) }) {
            return match
        }

        let visibleCandidates: [CGRect] = [
            CGRect(x: centeredX, y: visibleFrame.minY, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: centeredX, y: visibleFrame.maxY - toolbarSize.height, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: visibleFrame.maxX - toolbarSize.width, y: centeredY, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: visibleFrame.minX, y: centeredY, width: toolbarSize.width, height: toolbarSize.height),
        ]
        return visibleCandidates.min {
            SelectionGeometry.intersectionArea(of: $0, with: screenshotRect)
                < SelectionGeometry.intersectionArea(of: $1, with: screenshotRect)
        } ?? visibleCandidates[0]
    }

    private static func clamped(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(value, minimum), max(minimum, maximum))
    }
}

struct ScreenshotToolbarSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 4) {
            content
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .shadow(radius: 6, y: 2)
    }
}

struct ScreenshotToolbarDivider: View {
    var body: some View {
        Divider()
            .frame(height: 20)
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }
}

struct ScreenshotToolbarButton: View {
    let systemImage: String
    let help: String
    var showsProgress = false
    var isActive = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .medium))
                }
            }
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? Color.red : Color.clear)
        }
        .opacity(isDisabled ? 0.45 : 1)
        .disabled(isDisabled)
        .help(help)
        .accessibilityLabel(help)
    }
}
