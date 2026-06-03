import AppKit
import SwiftUI

struct InlineCaptureCanvas: View {
    @ObservedObject var model: InlineCaptureCanvasModel
    let beginDrawing: (CGPoint) -> Void
    let dragDrawing: (CGPoint) -> Void
    let endDrawing: (CGPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            let imageRect = CGRect(origin: .zero, size: proxy.size)
            let borderInset = SelectionOverlayRenderer.selectionChromeLineWidth / 2
            let borderRect = imageRect.insetBy(dx: borderInset, dy: borderInset)
            ZStack(alignment: .topLeading) {
                Image(nsImage: model.renderedImage)
                    .resizable()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                Canvas { context, _ in
                    guard let draft = model.draftAnnotation else { return }
                    context.withCGContext { cgContext in
                        NSGraphicsContext.saveGraphicsState()
                        NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: false)
                        AnnotationRenderer.drawPreview(draft, in: imageRect, imageSize: model.screenshot.image.size)
                        NSGraphicsContext.restoreGraphicsState()
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .allowsHitTesting(model.drawingTool != nil)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let point = imagePoint(from: value.location, viewSize: proxy.size)
                            if model.draftAnnotation == nil {
                                beginDrawing(point)
                            } else {
                                dragDrawing(point)
                            }
                        }
                        .onEnded { value in
                            endDrawing(imagePoint(from: value.location, viewSize: proxy.size))
                        }
                )

                SelectionBorderRepresentable(selection: borderRect)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .allowsHitTesting(false)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
        }
    }

    private func imagePoint(from point: CGPoint, viewSize: CGSize) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0 else {
            return .zero
        }
        return CGPoint(
            x: point.x / viewSize.width * model.screenshot.image.size.width,
            y: point.y / viewSize.height * model.screenshot.image.size.height
        )
    }
}
