import SwiftUI

struct ScreenshotToolbar: View {
    @ObservedObject var document: InlineCaptureDocument
    let close: () -> Void

    var body: some View {
        ScreenshotToolbarSurface {
            ScreenshotToolbarButton(
                systemImage: "arrow.up.right",
                help: "箭头",
                isActive: document.drawingTool == .arrow
            ) {
                document.toggleDrawingTool(.arrow)
            }
            ScreenshotToolbarButton(
                systemImage: "rectangle",
                help: "矩形",
                isActive: document.drawingTool == .rectangle
            ) {
                document.toggleDrawingTool(.rectangle)
            }
            ScreenshotToolbarButton(
                systemImage: "circle",
                help: "圆形",
                isActive: document.drawingTool == .circle
            ) {
                document.toggleDrawingTool(.circle)
            }
            ScreenshotToolbarButton(
                systemImage: "arrow.uturn.backward",
                help: "撤销",
                isDisabled: !document.canUndo
            ) {
                document.undo()
            }
            ScreenshotToolbarButton(
                systemImage: "character.book.closed",
                help: "翻译",
                showsProgress: document.isTranslating,
                isActive: document.isTranslationVisible,
                isDisabled: document.isTranslating
            ) {
                Task { await document.toggleTranslation() }
            }
            ScreenshotToolbarButton(systemImage: "doc.on.doc", help: "复制") {
                document.copy()
            }
            ScreenshotToolbarButton(systemImage: "square.and.arrow.down", help: "保存图片") {
                document.save()
            }
            ScreenshotToolbarDivider()
            ScreenshotToolbarButton(systemImage: "checkmark", help: "完成") {
                document.copy()
                close()
            }
            ScreenshotToolbarButton(systemImage: "xmark", help: "关闭", action: close)
            if !document.status.isEmpty {
                Image(systemName: statusSystemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(statusColor)
                    .frame(width: 22, height: 34)
                    .help(document.status)
            }
        }
    }

    private var statusSystemImage: String {
        document.status.contains("失败") || document.status.contains("错误")
            ? "exclamationmark.circle.fill"
            : "checkmark.circle.fill"
    }

    private var statusColor: Color {
        document.status.contains("失败") || document.status.contains("错误")
            ? .red
            : .green
    }
}

enum ScreenshotToolbarLayout {
    private static let spacing: CGFloat = 8

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
        let candidates = [
            CGRect(x: centeredX, y: screenshotRect.minY - toolbarSize.height - spacing, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: centeredX, y: screenshotRect.maxY + spacing, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: screenshotRect.maxX + spacing, y: centeredY, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: screenshotRect.minX - toolbarSize.width - spacing, y: centeredY, width: toolbarSize.width, height: toolbarSize.height)
        ]

        if let frame = candidates.first(where: { visibleFrame.contains($0) }) {
            return frame
        }

        let visibleCandidates = [
            CGRect(x: centeredX, y: visibleFrame.minY, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: centeredX, y: visibleFrame.maxY - toolbarSize.height, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: visibleFrame.maxX - toolbarSize.width, y: centeredY, width: toolbarSize.width, height: toolbarSize.height),
            CGRect(x: visibleFrame.minX, y: centeredY, width: toolbarSize.width, height: toolbarSize.height)
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

private struct ScreenshotToolbarSurface<Content: View>: View {
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

private struct ScreenshotToolbarDivider: View {
    var body: some View {
        Divider()
            .frame(height: 20)
            .padding(.horizontal, 2)
    }
}

private struct ScreenshotToolbarButton: View {
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
